#!/usr/bin/env python3
"""GOBLINCAKES lärläge: the practice computer's stand-in for podman, `systemctl --user` (quadlets)
and curl – see podrun.py. Answers like the real commands for what the lessons use. The state
(images, containers, volumes, pods, units) lives in $GOBLINCAKES_PODMAN_STATE/state.json; each
container's files are a folder of their own, and commands "inside" a container run for real
with the container's paths moved into that folder."""
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

STATE = Path(os.environ.get("GOBLINCAKES_PODMAN_STATE", "/tmp/goblincakes-podman"))
HOME = Path(os.environ.get("HOME", "/tmp"))
VERSION = "5.6.2"

# The practice registry: what can be pulled (the practice computer has no network)
REGISTRY = {
    "alpine": {"repo": "docker.io/library/alpine", "tag": "latest", "size": "8.6 MB", "cmd": ["/bin/sh"],
               "files": {"/etc/os-release": 'NAME="Alpine Linux"\nID=alpine\nVERSION_ID=3.22.2\nPRETTY_NAME="Alpine Linux v3.22"\n'}},
    "fedora": {"repo": "registry.fedoraproject.org/fedora", "tag": "44", "size": "180 MB", "cmd": ["/bin/bash"],
               "files": {"/etc/os-release": 'NAME="Fedora Linux"\nVERSION="44 (Container Image)"\nID=fedora\nVERSION_ID=44\nPRETTY_NAME="Fedora Linux 44 (Container Image)"\n'}},
    "nginx": {"repo": "docker.io/library/nginx", "tag": "latest", "size": "196 MB", "cmd": ["nginx", "-g", "daemon off;"],
              "server": "web", "html": "/usr/share/nginx/html", "expose": ["80/tcp"],
              "files": {"/usr/share/nginx/html/index.html": "<h1>Welcome to nginx!</h1>\n"},
              "logs": ["/docker-entrypoint.sh: Configuration complete; ready for start up",
                       "nginx/1.29.2: start worker processes"]},
    "mariadb": {"repo": "docker.io/library/mariadb", "tag": "11", "size": "336 MB", "cmd": ["mariadbd"],
                "server": "db", "expose": ["3306/tcp"], "files": {}},
    "python": {"repo": "docker.io/library/python", "tag": "3.13-slim", "size": "128 MB", "cmd": ["python3"], "files": {}},
    "php": {"repo": "docker.io/library/php", "tag": "8.3-apache", "size": "512 MB", "cmd": ["apache2-foreground"],
            "server": "web", "html": "/var/www/html", "expose": ["80/tcp"],
            "files": {"/var/www/html/.keep": ""},
            "logs": ["AH00558: apache2: Could not reliably determine the server's fully qualified domain name",
                     "[mpm_prefork:notice] Apache/2.4.65 (Debian) PHP/8.3.26 configured -- resuming normal operations"]},
}
KNOWN = ", ".join(REGISTRY)


def out(text=""):
    print(text, flush=True)


def fail(text, code=125):
    print(text, file=sys.stderr, flush=True)
    sys.exit(code)


def hexid(*parts):
    return hashlib.sha256("|".join(map(str, parts)).encode()).hexdigest()


def load():
    try:
        return json.loads((STATE / "state.json").read_text())
    except (OSError, ValueError):
        return {"images": {}, "containers": {}, "volumes": {}, "pods": {}, "units": {}, "loaded": [], "n": 0}


def save(s):
    STATE.mkdir(parents=True, exist_ok=True)
    (STATE / "state.json").write_text(json.dumps(s))


# ── Images ────────────────────────────────────────────────────────

def parse_ref(ref):
    """'nginx', 'docker.io/library/nginx:latest', 'localhost/app' → (short name, full reference)."""
    name, tag = ref, None
    if ":" in ref.rsplit("/", 1)[-1]:
        name, tag = ref.rsplit(":", 1)
    short = name.rsplit("/", 1)[-1]
    if name.startswith("localhost/") or ("/" not in name and short not in REGISTRY):
        return short, f"localhost/{short}:{tag or 'latest'}"
    if short in REGISTRY:
        reg = REGISTRY[short]
        return short, f"{reg['repo']}:{tag or reg['tag']}"
    return short, f"{name if '.' in name.split('/')[0] else 'docker.io/' + name}:{tag or 'latest'}"


def find_image(s, ref):
    short, full = parse_ref(ref)
    if full in s["images"]:
        return full
    for key in s["images"]:
        if key.startswith(f"localhost/{short}:") and full.startswith("localhost/"):
            return key
    return None


def pull(s, ref, quiet=False, show_id=True):
    short, full = parse_ref(ref)
    if full in s["images"]:
        if show_id:
            out(s["images"][full]["id"])
        return full
    if short not in REGISTRY or full.startswith("localhost/"):
        where = full.rsplit(":", 1)[0]
        fail(f"Error: initializing source docker://{full}: reading manifest {full.rsplit(':', 1)[1]} in {where}: "
             f"requested access to the resource is denied\n(Övningsdatorn har bara de här imagerna: {KNOWN}.)")
    reg = REGISTRY[short]
    if not quiet:
        print(f"Trying to pull {full}...", file=sys.stderr, flush=True)
        print("Writing manifest to image destination", file=sys.stderr, flush=True)
    root = STATE / "images" / hexid(full)[:12]
    root.mkdir(parents=True, exist_ok=True)
    for path, text in reg["files"].items():
        f = root / path.lstrip("/")
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(text)
    s["images"][full] = {"id": hexid(full), "short": short, "root": str(root), "cmd": reg["cmd"], "entry": [],
                         "env": {}, "workdir": "/", "size": reg["size"], "base": short}
    if show_id:
        out(hexid(full))
    return full


def image_for_run(s, ref):
    return find_image(s, ref) or pull(s, ref, show_id=False)


# ── Containers ────────────────────────────────────────────────────

def container(s, name, required=True):
    for c in s["containers"].values():
        if c["name"] == name or c["id"].startswith(name) and len(name) >= 3:
            return c
    if required:
        fail(f"Error: no container with name or ID \"{name}\" found: no such container")
    return None


def map_path(c, p, create=False):
    """A path inside the container → the folder that holds it (mounts first, then the container's own files)."""
    if not p.startswith("/"):
        return p
    for src, dest in sorted(c["mounts"], key=lambda m: -len(m[1])):
        if p == dest or p.startswith(dest.rstrip("/") + "/"):
            return src + p[len(dest.rstrip("/")):] if p != dest else src
    root = Path(c["root"])
    if p == "/":
        return str(root)
    inside = root / p.lstrip("/")
    if inside.exists() or create or (inside.parent != root and inside.parent.exists()):
        return str(inside)
    return p


PATH_RE = re.compile(r"(?<![\w$.\-/])(/[A-Za-z0-9_.\-/]+)")


def map_text(c, text):
    return PATH_RE.sub(lambda m: map_path(c, m.group(1)), text)


def run_inside(c, argv, workdir=None, env=None, timeout=5):
    """Runs a command 'inside' the container: for real, with its paths moved into its folder."""
    if not argv:
        return 0, ""
    first = argv[0]
    if first in ("mariadb", "mysql"):
        return mariadb_client(c, argv[1:])
    if first in ("sh", "/bin/sh", "bash", "/bin/bash") and "-c" in argv:
        i = argv.index("-c")
        cmd = ["bash", "-c", map_text(c, argv[i + 1])] + argv[i + 2:]
    else:
        mapped = map_path(c, first)
        if mapped != first and os.path.isfile(mapped):
            cmd = (["python3"] if mapped.endswith(".py") else ["sh"] if mapped.endswith(".sh") else []) + [mapped]
        else:
            cmd = [{"python": "python3", "/usr/local/bin/python3": "python3", "/bin/sh": "sh"}.get(first, os.path.basename(first))]
        cmd += [map_path(c, a) if a.startswith("/") else a for a in argv[1:]]
    wd = map_path(c, workdir or c["workdir"] or "/", create=True)
    os.makedirs(wd, exist_ok=True)
    e = dict(os.environ, **c["env"], **(env or {}))
    try:
        r = subprocess.run(cmd, cwd=wd, env=e, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
        return r.returncode, r.stdout
    except FileNotFoundError:
        return 127, (f"Error: crun: executable file `{first}` not found in $PATH: No such file or directory: "
                     "OCI runtime attempted to invoke a command that was not found\n")
    except subprocess.TimeoutExpired:
        return 124, "(övningsdatorn: kommandot tog för lång tid och stoppades)\n"


def server_start(s, c):
    """nginx/php/mariadb: starts as a service (nothing runs for real) – or stops with an error like the real one."""
    kind = REGISTRY.get(c["base"], {}).get("server")
    if kind == "db":
        env = c["env"]
        ok = any(env.get(f"{p}_{k}") for p in ("MARIADB", "MYSQL") for k in
                 ("ROOT_PASSWORD", "ALLOW_EMPTY_ROOT_PASSWORD", "RANDOM_ROOT_PASSWORD", "ROOT_PASSWORD_HASH"))
        data = Path(map_path(c, "/var/lib/mysql", create=True))
        data.mkdir(parents=True, exist_ok=True)
        if (data / "mysql").is_dir():
            c["logs"] += ["[Note] [Entrypoint]: Database files already exist – skipping initialization",
                          "[Note] mariadbd: ready for connections."]
            c["status"] = "running"
            return
        if not ok:
            c["logs"] += ["[ERROR] [Entrypoint]: Database is uninitialized and password option is not specified",
                          "\tYou need to specify one of MARIADB_ROOT_PASSWORD, MARIADB_ROOT_PASSWORD_HASH, "
                          "MARIADB_ALLOW_EMPTY_ROOT_PASSWORD and MARIADB_RANDOM_ROOT_PASSWORD"]
            c["status"], c["exit"] = "exited", 1
            return
        (data / "mysql").mkdir()
        pw = env.get("MARIADB_ROOT_PASSWORD") or env.get("MYSQL_ROOT_PASSWORD") or ""
        (data / ".goblincakes-root").write_text(pw)
        c["logs"].append("[Note] [Entrypoint]: Initializing database files")
        db = env.get("MARIADB_DATABASE") or env.get("MYSQL_DATABASE")
        if db:
            (data / db).mkdir(exist_ok=True)
            c["logs"].append(f"[Note] [Entrypoint]: Creating database {db}")
        user = env.get("MARIADB_USER") or env.get("MYSQL_USER")
        if user:
            c["logs"].append(f"[Note] [Entrypoint]: Creating user {user}")
        c["logs"].append("[Note] mariadbd: ready for connections.")
    else:
        c["logs"] += REGISTRY.get(c["base"], {}).get("logs", [])
    c["status"] = "running"


def mariadb_client(c, args):
    data = Path(map_path(c, "/var/lib/mysql", create=True))
    if not (data / "mysql").is_dir() or c["status"] != "running":
        return 1, "ERROR 2002 (HY000): Can't connect to local server through socket '/run/mysqld/mysqld.sock' (2)\n"
    pw, sql, i = None, "", 0
    while i < len(args):
        a = args[i]
        if a.startswith("-p") and len(a) > 2:
            pw = a[2:]
        elif a.startswith("--password="):
            pw = a.split("=", 1)[1]
        elif a in ("-e", "--execute"):
            i += 1
            sql = args[i]
        elif a.startswith("--execute="):
            sql = a.split("=", 1)[1]
        i += 1
    real = (data / ".goblincakes-root").read_text() if (data / ".goblincakes-root").exists() else ""
    if (pw or "") != real:
        return 1, f"ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: {'YES' if pw else 'NO'})\n"
    lines = []
    for stmt in [x.strip() for x in sql.split(";") if x.strip()]:
        m = re.match(r"create\s+database\s+(?:if\s+not\s+exists\s+)?`?(\w+)`?$", stmt, re.I)
        if re.match(r"show\s+databases$", stmt, re.I):
            names = sorted({"information_schema", "mysql", "performance_schema", "sys"} |
                           {p.name for p in data.iterdir() if p.is_dir()})
            lines += ["Database"] + names
        elif m:
            (data / m.group(1)).mkdir(exist_ok=True)
        else:
            return 1, "ERROR 1064 (42000): (övningsdatorn kan bara SHOW DATABASES och CREATE DATABASE)\n"
    return 0, "\n".join(lines) + ("\n" if lines else "")


def ports_text(ports):
    return ", ".join(f"{ip or '0.0.0.0'}:{hp}->{cp}/tcp" for ip, hp, cp in ports)


def parse_port(spec):
    parts = spec.split(":")
    if len(parts) == 3:
        ip, hp, cp = parts
    elif len(parts) == 2:
        ip, (hp, cp) = "", parts
    else:
        fail(f"Error: invalid port format \"{spec}\" – skriv värdport:containerport, t.ex. 8080:80")
    cp = cp.split("/")[0]
    if not hp.isdigit() or not cp.isdigit():
        fail(f"Error: invalid port number \"{spec}\"")
    return [ip, int(hp), int(cp)]


def check_ports(s, ports, skip=None):
    for ip, hp, cp in ports:
        if hp < 1024:
            fail(f"Error: rootlessport cannot expose privileged port {hp}, you can add "
                 f"'net.ipv4.ip_unprivileged_port_start={hp}' to /etc/sysctl.conf (currently 1024), or choose a "
                 f"larger port number (>= 1024): listen tcp {ip or '0.0.0.0'}:{hp}: bind: permission denied")
        for owner in list(s["containers"].values()) + list(s["pods"].values()):
            if owner is skip or owner.get("status") != "running":
                continue
            if any(p[1] == hp for p in owner.get("ports", [])):
                fail(f"Error: rootlessport listen tcp {ip or '0.0.0.0'}:{hp}: bind: address already in use")


def parse_env_line(text):
    k, _, v = text.partition("=")
    return k.strip(), v


def new_container(s, image, name, cmd, opts):
    img = s["images"][image]
    s["n"] += 1
    cid = hexid(name, s["n"])
    if not name:
        name = ["glad_goblin", "snabb_orc", "modig_troll", "klok_gnome", "listig_kobold"][s["n"] % 5] + str(s["n"])
    if container(s, name, required=False):
        other = container(s, name)
        if opts.get("replace"):
            remove(s, other, force=True)
        else:
            fail(f"Error: creating container storage: the container name \"{name}\" is already in use by {other['id']}. "
                 "You have to remove that container to be able to reuse that name: that name is already in use, "
                 "or use --replace to instruct Podman to do so.")
    root = STATE / "containers" / cid[:12]
    if root.exists():
        shutil.rmtree(root)
    shutil.copytree(img["root"], root)
    for d in ("tmp", "root", "etc"):
        (root / d).mkdir(exist_ok=True)
    mounts, blocked = [], []
    for spec in opts.get("volumes", []):
        parts = spec.split(":")
        if len(parts) < 2:
            fail(f"Error: invalid volume \"{spec}\" – skriv källa:mål, t.ex. data:/data eller ./sida:/usr/share/nginx/html:Z")
        src, dest = parts[0], parts[1]
        labeled = len(parts) > 2 and any(f in ("z", "Z") for f in parts[2].split(","))
        if src.startswith(("/", "./", "../", "~")) or src in (".", ".."):
            host = os.path.abspath(os.path.expanduser(src))
            if not os.path.isdir(host) and not os.path.isfile(host):
                fail(f"Error: statfs {host}: no such file or directory")
            if not labeled:  # SELinux on Fedora/GOBLINCAKES: a folder without :Z can't be read inside
                blocked.append(dest)
        else:
            host = volume(s, src, create=True)
        mounts.append([host, dest])
    command = img.get("entry", []) + (cmd or img["cmd"])
    c = {"id": cid, "name": name, "image": image, "base": img["base"], "cmd": command, "status": "created", "exit": 0,
         "ports": opts.get("ports", []), "mounts": mounts, "env": {**img["env"], **opts.get("env", {})},
         "workdir": opts.get("workdir") or img["workdir"], "logs": [], "pod": opts.get("pod"), "root": str(root),
         "rm": opts.get("rm", False), "blocked": blocked}
    s["containers"][cid] = c
    return c


def volume(s, name, create=False):
    if name not in s["volumes"]:
        if not create:
            fail(f"Error: no volume with name \"{name}\" found: no such volume")
        d = STATE / "volumes" / name / "_data"
        d.mkdir(parents=True, exist_ok=True)
        s["volumes"][name] = str(d)
    return s["volumes"][name]


def is_sleeper(cmd):
    text = " ".join(cmd)
    return bool(re.search(r"sleep (infinity|\d{3,})|tail -f /dev/null", text))


def start(s, c, attach=False):
    if c["pod"]:
        pod = s["pods"][c["pod"]]
        pod["status"] = "running"
    else:
        check_ports(s, c["ports"], skip=c)
    if REGISTRY.get(c["base"], {}).get("server") and c["cmd"] == s["images"][c["image"]]["cmd"]:
        server_start(s, c)
        if attach:
            for line in c["logs"]:
                out(line)
            if c["status"] == "running":
                out(f"(övningsdatorn: {c['base']} körs nu i förgrunden och skulle fortsätta tills du trycker Ctrl+C – "
                    "här stoppas den direkt. Använd -d för att köra den i bakgrunden.)")
                c["status"] = "exited"
        return
    if is_sleeper(c["cmd"]) and not attach:
        c["status"] = "running"
        return
    c["status"] = "running"
    code, text = run_inside(c, c["cmd"])
    c["logs"] += text.splitlines()
    c["status"], c["exit"] = "exited", code
    if attach and text:
        sys.stdout.write(text)
        sys.stdout.flush()


def remove(s, c, force=False):
    if c["status"] == "running" and not force:
        fail(f"Error: cannot remove container {c['id']} as it is running - running or paused containers cannot be "
             "removed without force: container state improper")
    shutil.rmtree(c["root"], ignore_errors=True)
    del s["containers"][c["id"]]


def status_text(c):
    if c["status"] == "running":
        return "Up 2 seconds"
    if c["status"] == "exited":
        return f"Exited ({c['exit']}) 1 second ago"
    return "Created"


def short_image(ref):
    return ref


def fmt(template, fields):
    template = template.replace("\\t", "\t").replace("\\n", "\n")
    table = template.startswith("table ")
    if table:
        template = template[6:]

    def val(m):
        key = m.group(1).strip().lstrip(".")
        return str(fields.get(key, f"<no value>"))
    return table, re.sub(r"\{\{\s*([^}]+?)\s*\}\}", val, template)


def table(rows, headers):
    widths = [max(len(h), *(len(str(r[i])) for r in rows)) if rows else len(h) for i, h in enumerate(headers)]
    lines = ["  ".join(h.ljust(widths[i]) for i, h in enumerate(headers)).rstrip()]
    for r in rows:
        lines.append("  ".join(str(v).ljust(widths[i]) for i, v in enumerate(r)).rstrip())
    return "\n".join(lines)


# ── podman subcommands ────────────────────────────────────────────

def take_flags(args, spec):
    """spec: {flag: takes_value}; returns (options, rest). Stops at the first non-flag (the image)."""
    opts, i = {}, 0
    while i < len(args):
        a = args[i]
        if not a.startswith("-") or a == "-":
            break
        name, eq, val = a.partition("=")
        if name not in spec:
            if len(name) > 2 and not name.startswith("--") and all(f"-{ch}" in spec and not spec[f"-{ch}"] for ch in name[1:]):
                for ch in name[1:]:
                    opts.setdefault(f"-{ch}", []).append(True)
                i += 1
                continue
            fail(f"Error: unknown flag: {name}\nSee 'podman --help'")
        if spec[name]:
            if not eq:
                i += 1
                if i >= len(args):
                    fail(f"Error: flag needs an argument: {name}")
                val = args[i]
            opts.setdefault(name, []).append(val)
        else:
            opts.setdefault(name, []).append(True)
        i += 1
    return opts, args[i:]


RUN_FLAGS = {"-d": False, "--detach": False, "--rm": False, "-i": False, "-t": False, "-it": False, "--interactive": False,
             "--tty": False, "--name": True, "-p": True, "--publish": True, "-v": True, "--volume": True, "-e": True,
             "--env": True, "--env-file": True, "--pod": True, "-w": True, "--workdir": True, "--replace": False,
             "--restart": True, "--security-opt": True, "--userns": True, "--network": True, "--label": True}


def cmd_run(s, args, create_only=False):
    o, rest = take_flags(args, RUN_FLAGS)
    if not rest:
        fail("Error: requires at least 1 arg(s), only received 0")
    image, cmd = rest[0], rest[1:]
    env = {}
    for path in o.get("--env-file", []):
        try:
            for line in Path(path).read_text().splitlines():
                if line.strip() and not line.startswith("#"):
                    k, v = parse_env_line(line)
                    env[k] = v
        except OSError:
            fail(f"Error: open {path}: no such file or directory")
    for e in o.get("-e", []) + o.get("--env", []):
        k, v = parse_env_line(e)
        env[k] = v if "=" in e else os.environ.get(k, "")
    ports = [parse_port(p) for p in o.get("-p", []) + o.get("--publish", [])]
    pod = (o.get("--pod") or [None])[0]
    if pod:
        if pod not in s["pods"]:
            fail(f"Error: no pod with name or ID {pod} found: no such pod")
        if ports:
            fail("Error: invalid config provided: published or exposed ports must be defined when the pod is created: "
                 "network cannot be configured when it is shared with a pod")
    full = image_for_run(s, image)
    c = new_container(s, full, (o.get("--name") or [None])[0], cmd, {
        "ports": ports, "volumes": o.get("-v", []) + o.get("--volume", []), "env": env, "pod": pod,
        "workdir": (o.get("-w") or o.get("--workdir") or [None])[0], "rm": bool(o.get("--rm")),
        "replace": bool(o.get("--replace"))})
    if create_only:
        save(s)
        out(c["id"])
        return 0
    detach = bool(o.get("-d") or o.get("--detach"))
    start(s, c, attach=not detach)
    code = c["exit"] if c["status"] == "exited" else 0
    if detach:
        out(c["id"])
    if c["rm"] and c["status"] != "running":
        remove(s, c, force=True)
    save(s)
    return code if not detach else 0


def cmd_ps(s, args):
    o, rest = take_flags(args, {"-a": False, "--all": False, "-q": False, "--quiet": False, "--format": True, "--pod": False})
    rows = [c for c in s["containers"].values() if c["status"] == "running" or o.get("-a") or o.get("--all")]
    if o.get("-q") or o.get("--quiet"):
        for c in rows:
            out(c["id"][:12])
        return 0

    def fields(c):
        ports = c["ports"] or (s["pods"][c["pod"]]["ports"] if c["pod"] else [])
        return {"ID": c["id"][:12], "Names": c["name"], "Image": c["image"], "Status": status_text(c),
                "Ports": ports_text(ports), "Command": " ".join(c["cmd"])[:20], "State": c["status"],
                "PodName": c["pod"] or "", "Pod": c["pod"] or "", "Created": "2 seconds ago"}
    if o.get("--format"):
        is_table, _ = fmt(o["--format"][0], {})
        lines = []
        for c in rows:
            lines.append(fmt(o["--format"][0], fields(c))[1])
        if is_table:
            lines.insert(0, re.sub(r"\{\{\s*\.?([^}]+?)\s*\}\}", lambda m: m.group(1).upper(),
                                   o["--format"][0][6:].replace("\\t", "\t")))
        for line in lines:
            out(line)
        return 0
    out(table([[f["ID"], f["Image"], f["Command"], "2 seconds ago", f["Status"], f["Ports"], f["Names"]]
               for f in map(fields, rows)], ["CONTAINER ID", "IMAGE", "COMMAND", "CREATED", "STATUS", "PORTS", "NAMES"]))
    return 0


def cmd_images(s, args):
    o, rest = take_flags(args, {"--format": True, "-q": False, "-a": False})
    rows = []
    for ref, img in s["images"].items():
        repo, tag = ref.rsplit(":", 1)
        rows.append({"Repository": repo, "Tag": tag, "ID": img["id"][:12], "Size": img["size"], "Created": "2 weeks ago"})
    if o.get("-q"):
        for r in rows:
            out(r["ID"])
    elif o.get("--format"):
        for r in rows:
            out(fmt(o["--format"][0], r)[1])
    else:
        out(table([[r["Repository"], r["Tag"], r["ID"], r["Created"], r["Size"]] for r in rows],
                  ["REPOSITORY", "TAG", "IMAGE ID", "CREATED", "SIZE"]))
    return 0


def cmd_logs(s, args):
    o, rest = take_flags(args, {"-f": False, "--follow": False, "--tail": True, "-t": False})
    if not rest:
        fail("Error: requires at least 1 arg(s), only received 0")
    c = container(s, rest[0])
    lines = c["logs"]
    if o.get("--tail"):
        lines = lines[-int(o["--tail"][0]):]
    for line in lines:
        out(line)
    return 0


def cmd_exec(s, args):
    o, rest = take_flags(args, {"-i": False, "-t": False, "-it": False, "--interactive": False, "--tty": False,
                                "-w": True, "--workdir": True, "-e": True, "--env": True})
    if len(rest) < 2:
        fail("Error: must provide a non-empty command to start an exec session: invalid argument")
    c = container(s, rest[0])
    if c["status"] != "running":
        fail("Error: can only create exec sessions on running containers: container state improper")
    env = dict(parse_env_line(e) for e in o.get("-e", []) + o.get("--env", []))
    code, text = run_inside(c, rest[1:], workdir=(o.get("-w") or o.get("--workdir") or [None])[0], env=env)
    sys.stdout.write(text)
    save(s)
    return code


def cmd_simple(s, verb, args):
    o, rest = take_flags(args, {"-f": False, "--force": False, "-a": False, "--all": False, "-t": True, "--time": True})
    if o.get("-a") or o.get("--all"):
        rest = [c["name"] for c in list(s["containers"].values())]
    if not rest:
        fail("Error: you must provide at least one name or id")
    for name in rest:
        c = container(s, name)
        if verb == "stop":
            if c["status"] == "running":
                c["status"], c["exit"] = "exited", 0
                c["logs"].append("(stoppad)") if REGISTRY.get(c["base"], {}).get("server") == "web" else None
            if c["rm"]:
                remove(s, c, force=True)
        elif verb == "start":
            if c["status"] != "running":
                start(s, c)
        elif verb == "restart":
            c["status"] = "exited"
            start(s, c)
        elif verb == "rm":
            remove(s, c, force=bool(o.get("-f") or o.get("--force")))
        out(name)
    save(s)
    return 0


def cmd_port(s, args):
    if not args:
        fail("Error: you must supply a running container name or id")
    c = container(s, args[0])
    ports = c["ports"] or (s["pods"][c["pod"]]["ports"] if c["pod"] else [])
    for ip, hp, cp in ports:
        out(f"{cp}/tcp -> {ip or '0.0.0.0'}:{hp}")
    return 0


def cmd_inspect(s, args):
    o, rest = take_flags(args, {"--format": True, "-f": True, "--type": True})
    template = (o.get("--format") or o.get("-f") or [None])[0]
    for name in rest:
        c = container(s, name, required=False)
        if c:
            fields = {"State.Status": c["status"], "State.ExitCode": c["exit"], "State.Running": str(c["status"] == "running").lower(),
                      "Name": c["name"], "Id": c["id"], "Config.Image": c["image"], "ImageName": c["image"],
                      "Config.Env": "[" + " ".join(f"{k}={v}" for k, v in c["env"].items()) + "]",
                      "Config.WorkingDir": c["workdir"], "Pod": c["pod"] or ""}
            data = {"Id": c["id"], "Name": c["name"], "State": {"Status": c["status"], "ExitCode": c["exit"]},
                    "Config": {"Image": c["image"], "Env": [f"{k}={v}" for k, v in c["env"].items()], "Cmd": c["cmd"]},
                    "Mounts": [{"Source": m[0], "Destination": m[1]} for m in c["mounts"]]}
        else:
            ref = find_image(s, name)
            if not ref:
                fail(f"Error: no such object: \"{name}\"")
            img = s["images"][ref]
            fields = {"Id": img["id"], "Config.Cmd": "[" + " ".join(img["cmd"]) + "]", "Config.WorkingDir": img["workdir"],
                      "Config.Env": "[" + " ".join(f"{k}={v}" for k, v in img["env"].items()) + "]"}
            data = {"Id": img["id"], "RepoTags": [ref], "Config": {"Cmd": img["cmd"], "Env": [f"{k}={v}" for k, v in img["env"].items()],
                                                                     "WorkingDir": img["workdir"]}}
        out(fmt(template, fields)[1] if template else json.dumps([data], indent=4))
    return 0


def cmd_volume(s, args):
    if not args:
        fail("Error: missing command 'podman volume COMMAND'")
    verb, rest = args[0], args[1:]
    o, rest = take_flags(rest, {"--format": True, "-f": False, "--force": False, "-q": False})
    if verb == "create":
        name = rest[0] if rest else hexid("vol", s["n"])
        if name in s["volumes"]:
            fail(f"Error: volume with name {name} already exists: volume already exists")
        volume(s, name, create=True)
        out(name)
    elif verb in ("ls", "list"):
        if o.get("-q"):
            for n in s["volumes"]:
                out(n)
        else:
            out(table([["local", n] for n in s["volumes"]], ["DRIVER", "VOLUME NAME"]))
    elif verb == "rm":
        for n in rest:
            volume(s, n)
            used = [c["name"] for c in s["containers"].values() if any(m[0] == s["volumes"][n] for m in c["mounts"])]
            if used and not (o.get("-f") or o.get("--force")):
                fail(f"Error: volume {n} is being used by the following container(s): {', '.join(used)}: volume is being used")
            shutil.rmtree(Path(s["volumes"][n]).parent, ignore_errors=True)
            del s["volumes"][n]
            out(n)
    elif verb == "inspect":
        for n in rest:
            volume(s, n)
            mp = f"/home/goblin/.local/share/containers/storage/volumes/{n}/_data"
            fields = {"Name": n, "Mountpoint": mp, "Driver": "local"}
            tmpl = (o.get("--format") or [None])[0]
            out(fmt(tmpl, fields)[1] if tmpl else json.dumps([fields], indent=4))
    else:
        fail(f"Error: unrecognized command `podman volume {verb}`")
    save(s)
    return 0


def cmd_pod(s, args):
    if not args:
        fail("Error: missing command 'podman pod COMMAND'")
    verb, rest = args[0], args[1:]
    if verb == "create":
        o, rest = take_flags(rest, {"--name": True, "-p": True, "--publish": True, "--replace": False})
        name = (o.get("--name") or rest or [None])[0]
        if not name:
            fail("Error: ange ett namn med --name")
        if name in s["pods"]:
            fail(f"Error: adding pod to state: name \"{name}\" is in use: pod already exists")
        ports = [parse_port(p) for p in o.get("-p", []) + o.get("--publish", [])]
        check_ports(s, ports)
        s["pods"][name] = {"id": hexid("pod", name), "ports": ports, "status": "created"}
        out(hexid("pod", name))
    elif verb in ("ps", "ls", "list"):
        rows = []
        for n, p in s["pods"].items():
            members = [c for c in s["containers"].values() if c["pod"] == n]
            st = "Running" if any(c["status"] == "running" for c in members) else ("Exited" if members else "Created")
            rows.append([p["id"][:12], n, st, "2 seconds ago", str(len(members) + 1)])
        out(table(rows, ["POD ID", "NAME", "STATUS", "CREATED", "# OF CONTAINERS"]))
    elif verb in ("rm", "stop", "start"):
        o, rest = take_flags(rest, {"-f": False, "--force": False})
        for n in rest:
            if n not in s["pods"]:
                fail(f"Error: no pod with name or ID {n} found: no such pod")
            members = [c for c in s["containers"].values() if c["pod"] == n]
            for c in members:
                if verb == "start":
                    if c["status"] != "running":
                        start(s, c)
                elif c["status"] == "running":
                    if verb == "rm" and not (o.get("-f") or o.get("--force")):
                        fail(f"Error: pod {n} has running containers – stoppa den först eller använd -f")
                    c["status"] = "exited"
                if verb == "rm":
                    remove(s, c, force=True)
            if verb == "rm":
                del s["pods"][n]
            out(s["pods"][n]["id"] if n in s["pods"] else hexid("pod", n))
    else:
        fail(f"Error: unrecognized command `podman pod {verb}`")
    save(s)
    return 0


def containerfile_lines(text):
    lines, buf = [], ""
    for raw in text.splitlines():
        line = raw.strip()
        if not buf and (not line or line.startswith("#")):
            continue
        if line.endswith("\\"):
            buf += line[:-1] + " "
            continue
        lines.append(buf + line)
        buf = ""
    if buf:
        lines.append(buf)
    return lines


def exec_form(text):
    text = text.strip()
    if text.startswith("["):
        try:
            return json.loads(text)
        except ValueError:
            fail(f"Error: kunde inte läsa {text} – skriv JSON med dubbla citattecken: [\"python3\", \"app.py\"]")
    return ["/bin/sh", "-c", text]


def cmd_build(s, args):
    o, rest = take_flags(args, {"-t": True, "--tag": True, "-f": True, "--file": True, "--no-cache": False, "-q": False})
    context = Path(rest[0] if rest else ".")
    cfile = Path((o.get("-f") or o.get("--file") or [None])[0] or (context / "Containerfile"))
    if not cfile.exists() and not (o.get("-f") or o.get("--file")) and (context / "Dockerfile").exists():
        cfile = context / "Dockerfile"
    if not cfile.exists():
        fail(f"Error: no Containerfile or Dockerfile specified or found in context directory, {context.resolve()}: "
             "no such file or directory")
    lines = containerfile_lines(cfile.read_text())
    if not lines or not lines[0].upper().startswith("FROM "):
        fail("Error: Containerfile måste börja med FROM <image>")
    tag = (o.get("-t") or o.get("--tag") or [None])[0]
    total = len(lines)
    work = None
    for n, line in enumerate(lines, 1):
        instr, _, arg = line.partition(" ")
        instr, arg = instr.upper(), arg.strip()
        out(f"STEP {n}/{total}: {instr} {arg}")
        if instr == "FROM":
            base = image_for_run(s, arg.split(" AS ")[0].split(" as ")[0].strip())
            src = s["images"][base]
            s["n"] += 1
            root = STATE / "images" / hexid("build", s["n"])[:12]
            if root.exists():
                shutil.rmtree(root)
            shutil.copytree(src["root"], root)
            work = {"root": str(root), "cmd": list(src["cmd"]), "entry": list(src.get("entry", [])), "env": dict(src["env"]),
                    "workdir": src["workdir"], "base": src["base"], "mounts": [], "status": "running", "id": "build"}
            continue
        if instr == "WORKDIR":
            work["workdir"] = arg if arg.startswith("/") else os.path.join(work["workdir"], arg)
            Path(work["root"], work["workdir"].lstrip("/")).mkdir(parents=True, exist_ok=True)
        elif instr in ("COPY", "ADD"):
            parts = [p for p in shlex.split(arg) if not p.startswith("--")]
            if len(parts) < 2:
                fail(f"Error: building at STEP \"{instr} {arg}\": COPY behöver källa och mål")
            *srcs, dest = parts
            dest_abs = dest if dest.startswith("/") else os.path.join(work["workdir"], dest)
            target = Path(work["root"], dest_abs.lstrip("/"))
            for src_name in srcs:
                matches = sorted(context.glob(src_name)) if any(ch in src_name for ch in "*?[") else [context / src_name]
                for src_path in matches:
                    if not src_path.exists():
                        fail(f"Error: building at STEP \"{instr} {arg}\": checking on sources under \"{context.resolve()}\": "
                             f"copier: stat: \"/{src_name}\": no such file or directory")
                    if src_path.is_dir():  # a folder: its contents go into the target, as in Docker/Podman
                        shutil.copytree(src_path, target, dirs_exist_ok=True)
                    else:
                        if dest.endswith("/") or target.is_dir() or len(srcs) > 1 or len(matches) > 1 or dest in (".", "./"):
                            target.mkdir(parents=True, exist_ok=True)
                            shutil.copy(src_path, target / src_path.name)
                        else:
                            target.parent.mkdir(parents=True, exist_ok=True)
                            shutil.copy(src_path, target)
        elif instr == "ENV":
            if "=" in arg.split(" ")[0]:
                for part in shlex.split(arg):
                    k, v = parse_env_line(part)
                    work["env"][k] = v
            else:
                k, _, v = arg.partition(" ")
                work["env"][k] = v.strip()
        elif instr == "RUN":
            first = shlex.split(arg)[0] if arg else ""
            if first in ("dnf", "microdnf", "yum", "apt-get", "apt", "apk", "pip", "pip3") or " install " in f" {arg} " and first in ("python3", "python"):
                out("(övningsdatorn har inget nätverk: paketen räknas som installerade, inget hämtas)")
            else:
                code, text = run_inside(work, ["sh", "-c", arg])
                if text:
                    sys.stdout.write(text)
                if code:
                    fail(f"Error: building at STEP \"RUN {arg}\": while running runtime: exit status {code}", 1)
        elif instr == "CMD":
            work["cmd"] = exec_form(arg)
        elif instr == "ENTRYPOINT":
            work["entry"] = exec_form(arg)
            work["cmd"] = [] if work["cmd"] == s["images"].get(base, {}).get("cmd") else work["cmd"]
        elif instr in ("EXPOSE", "LABEL", "ARG", "USER", "VOLUME", "HEALTHCHECK", "STOPSIGNAL", "SHELL", "MAINTAINER"):
            pass
        else:
            fail(f"Error: building at STEP \"{instr} {arg}\": unknown instruction: {instr}", 1)
        if instr != "FROM":
            out(f"--> {hexid(line, n)[:12]}")
    full = parse_ref(tag)[1] if tag else f"localhost/none-{s['n']}:latest"
    if not tag:
        full = f"<none>-{s['n']}:latest"
    image_id = hexid(full, s["n"])
    if tag:
        out(f"COMMIT {tag}")
    out(f"--> {image_id[:12]}")
    if tag:
        out(f"Successfully tagged {full}")
    out(image_id)
    s["images"][full] = {"id": image_id, "short": full, "root": work["root"], "cmd": work["cmd"], "entry": work["entry"],
                         "env": work["env"], "workdir": work["workdir"], "size": "1 KB", "base": work["base"]}
    save(s)
    return 0


def podman(args):
    s = load()
    if not args or args[0] in ("-h", "--help", "help"):
        out("Övningsdatorns podman: run, ps, logs, stop, start, restart, rm, exec, port, inspect, pull, images, rmi, "
            "build, volume, pod. Image-namn som finns: " + KNOWN)
        return 0
    verb, rest = args[0], args[1:]
    if verb in ("--version", "-v"):
        out(f"podman version {VERSION}")
        return 0
    if verb == "version":
        out(f"Client:       Podman Engine\nVersion:      {VERSION}")
        return 0
    if verb == "pull":
        o, rest = take_flags(rest, {"-q": False, "--quiet": False})
        if not rest:
            fail("Error: requires exactly 1 arg(s), only received 0")
        pull(s, rest[0], quiet=bool(o.get("-q") or o.get("--quiet")))
        save(s)
        return 0
    if verb == "run":
        return cmd_run(s, rest)
    if verb == "create":
        return cmd_run(s, rest, create_only=True)
    if verb in ("ps", "container") and (verb == "ps" or rest[:1] in (["ls"], ["list"])):
        return cmd_ps(s, rest if verb == "ps" else rest[1:])
    if verb == "images":
        return cmd_images(s, rest)
    if verb == "rmi":
        for ref in rest:
            full = find_image(s, ref)
            if not full:
                fail(f"Error: {ref}: image not known")
            users = [c["name"] for c in s["containers"].values() if c["image"] == full]
            if users:
                fail(f"Error: image used by {hexid(users[0])}: image is in use by a container: consider listing external "
                     f"containers and force-removing image")
            out(f"Untagged: {full}\nDeleted: {s['images'][full]['id']}")
            del s["images"][full]
        save(s)
        return 0
    if verb == "logs":
        return cmd_logs(s, rest)
    if verb == "exec":
        return cmd_exec(s, rest)
    if verb in ("stop", "start", "restart", "rm"):
        return cmd_simple(s, verb, rest)
    if verb == "port":
        return cmd_port(s, rest)
    if verb == "inspect":
        return cmd_inspect(s, rest)
    if verb == "volume":
        return cmd_volume(s, rest)
    if verb == "pod":
        return cmd_pod(s, rest)
    if verb == "build":
        return cmd_build(s, rest)
    if verb == "generate" and rest[:1] == ["systemd"]:
        fail("DEPRECATED command:\nIt is recommended to use Quadlets for running containers and pods under systemd.\n\n"
             "Please refer to podman-systemd.unit(5) for details.", 0)
    fail(f"Error: unrecognized command `podman {verb}`\nTry 'podman --help' for more information")


# ── systemctl --user (quadlets) ───────────────────────────────────

QUADLET = HOME / ".config/containers/systemd"
CONTAINER_KEYS = {"Image", "ContainerName", "PublishPort", "Volume", "Environment", "EnvironmentFile", "Exec", "Pod",
                  "AutoUpdate", "Network", "Label", "WorkingDir", "Entrypoint", "PodmanArgs", "Notify", "User"}


def parse_unit(path):
    groups, group = {}, None
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if line.startswith("[") and line.endswith("]"):
            group = line[1:-1]
            groups.setdefault(group, {})
            continue
        if group is None or "=" not in line:
            return None, f"quadlet-generator[1]: {path.name}: kunde inte läsa raden \"{line}\""
        k, v = line.split("=", 1)
        groups[group].setdefault(k.strip(), []).append(v.strip())
    return groups, None


def daemon_reload(s):
    s["units"], s["loaded"] = {}, True
    if not QUADLET.is_dir():
        return
    for f in sorted(QUADLET.iterdir()):
        if f.suffix not in (".container", ".volume", ".pod"):
            continue
        groups, err = parse_unit(f)
        if err:
            print(err, file=sys.stderr)
            continue
        kind = f.suffix[1:].capitalize()
        body = groups.get(kind)
        if body is None:
            print(f"quadlet-generator[1]: {f.name}: saknar gruppen [{kind}] – filen hoppades över", file=sys.stderr)
            continue
        if kind == "Container":
            bad = [k for k in body if k not in CONTAINER_KEYS]
            if bad:
                print(f"quadlet-generator[1]: converting \"{f.name}\": unsupported key '{bad[0]}' in group 'Container'",
                      file=sys.stderr)
                continue
            if "Image" not in body:
                print(f"quadlet-generator[1]: converting \"{f.name}\": no Image or Rootfs key specified", file=sys.stderr)
                continue
        name = f.stem if kind == "Container" else f"{f.stem}-{kind.lower()}"
        s["units"][name] = {"file": f.name, "kind": kind, "groups": groups, "active": False}


def unit_name(arg):
    return arg[:-len(".service")] if arg.endswith(".service") else arg


def start_unit(s, name):
    u = s["units"][name]
    g = u["groups"]
    if u["kind"] == "Volume":
        volume(s, g["Volume"].get("VolumeName", [f"systemd-{u['file'][:-7]}"])[0], create=True)
        u["active"] = True
        return
    if u["kind"] == "Pod":
        pname = g["Pod"].get("PodName", [f"systemd-{u['file'][:-4]}"])[0]
        if pname not in s["pods"]:
            ports = [parse_port(p) for p in g["Pod"].get("PublishPort", [])]
            check_ports(s, ports)
            s["pods"][pname] = {"id": hexid("pod", pname), "ports": ports, "status": "running"}
        u["active"] = True
        return
    c = g["Container"]
    env = {}
    for line in c.get("Environment", []):
        for part in shlex.split(line):
            k, v = parse_env_line(part)
            env[k] = v
    for path in c.get("EnvironmentFile", []):
        p = Path(os.path.expanduser(path.replace("%h", str(HOME))))
        if p.exists():
            for line in p.read_text().splitlines():
                if line.strip() and not line.startswith("#"):
                    k, v = parse_env_line(line)
                    env[k] = v
    vols = []
    for v in c.get("Volume", []):
        src, _, rest = v.partition(":")
        if src.endswith(".volume"):
            vu = s["units"].get(src[:-7] + "-volume")
            vname = (vu["groups"]["Volume"].get("VolumeName", [f"systemd-{src[:-7]}"])[0] if vu else f"systemd-{src[:-7]}")
            volume(s, vname, create=True)
            src = vname
        vols.append(src.replace("%h", str(HOME)) + ":" + rest)
    pod = None
    if c.get("Pod"):
        pfile = c["Pod"][0]
        pu = s["units"].get(pfile[:-4] + "-pod")
        if not pu:
            fail(f"Job for {name}.service failed because a configured resource limit was exceeded.\n"
                 f"({pfile} finns inte – skapa podfilen och kör systemctl --user daemon-reload)", 1)
        start_unit(s, pfile[:-4] + "-pod")
        pod = pu["groups"]["Pod"].get("PodName", [f"systemd-{pfile[:-4]}"])[0]
    ports = [parse_port(p) for p in c.get("PublishPort", [])]
    full = image_for_run(s, c["Image"][0])
    cname = c.get("ContainerName", [f"systemd-{name}"])[0]
    old = container(s, cname, required=False)
    if old:
        remove(s, old, force=True)
    cmd = shlex.split(c["Exec"][0]) if c.get("Exec") else []
    cont = new_container(s, full, cname, cmd, {"ports": ports, "volumes": vols, "env": env, "pod": pod,
                                                "workdir": (c.get("WorkingDir") or [None])[0]})
    start(s, cont)
    u["active"] = cont["status"] == "running"
    u["container"] = cname


def systemctl(args):
    s = load()
    if "--user" not in args:
        fail("Failed to start unit: Access denied\n(Dina egna containrar styrs med systemctl --user.)", 1)
    args = [a for a in args if a != "--user"]
    if not args:
        fail("Too few arguments.", 1)
    verb, names = args[0], [unit_name(a) for a in args[1:]]
    if verb == "daemon-reload":
        daemon_reload(s)
        save(s)
        return 0
    for name in names:
        u = s["units"].get(name)
        if verb in ("enable", "disable"):
            fail(f"Failed to {verb} unit: Unit {name}.service is transient or generated.\n"
                 "(Quadlets startas vid inloggning med [Install] WantedBy=default.target i filen.)", 1)
        if not u:
            if verb == "status" or verb == "is-active":
                if verb == "is-active":
                    out("inactive")
                    return 3
                fail(f"Unit {name}.service could not be found.", 4)
            fail(f"Failed to {verb} {name}.service: Unit {name}.service not found.", 5)
        if verb in ("start", "restart"):
            start_unit(s, name)
            if not u["active"]:
                save(s)
                fail(f"Job for {name}.service failed because the control process exited with error code.\n"
                     f"See \"systemctl --user status {name}.service\" and \"journalctl --user -xeu {name}.service\" for details.", 1)
        elif verb == "stop":
            cname = u.get("container")
            c = container(s, cname, required=False) if cname else None
            if c:
                remove(s, c, force=True)
            u["active"] = False
        elif verb == "is-active":
            out("active" if u["active"] else "inactive")
            if not u["active"]:
                return 3
        elif verb == "status":
            desc = u["groups"].get("Unit", {}).get("Description", [u["file"]])[0]
            out(f"● {name}.service - {desc}")
            out(f"     Loaded: loaded (/home/goblin/.config/containers/systemd/{u['file']}; generated)")
            out(f"     Active: {'active (running)' if u['active'] else 'inactive (dead)'}")
            c = container(s, u.get("container"), required=False) if u.get("container") else None
            for line in (c["logs"][-3:] if c else []):
                out(f"{name}[1]: {line}")
            if not u["active"]:
                save(s)
                return 3
        else:
            fail(f"Unknown command verb '{verb}'.", 1)
    save(s)
    return 0


# ── curl ──────────────────────────────────────────────────────────

def curl(args):
    s = load()
    urls = [a for a in args if not a.startswith("-")]
    if not urls:
        fail("curl: try 'curl --help' for more information", 2)
    m = re.match(r"(?:https?://)?([^/:]+)(?::(\d+))?(/.*)?$", urls[-1])
    host, port, path = m.group(1), int(m.group(2) or 80), m.group(3) or "/"
    if host not in ("localhost", "127.0.0.1"):
        fail(f"curl: (6) Could not resolve host: {host}\n(Övningsdatorn har inget nätverk – bara localhost.)", 6)
    owner = None
    for c in s["containers"].values():
        ports = c["ports"] or (s["pods"][c["pod"]]["ports"] if c["pod"] else [])
        for ip, hp, cp in ports:
            if hp == port and c["status"] == "running" and REGISTRY.get(c["base"], {}).get("server"):
                owner = (c, cp)
    if not owner:
        fail(f"curl: (7) Failed to connect to {host} port {port} after 0 ms: Couldn't connect to server", 7)
    c, cp = owner
    reg = REGISTRY[c["base"]]
    if reg["server"] == "db":
        fail("curl: (1) Received HTTP/0.9 when not allowed\n(Det där är databasen – den pratar inte webb.)", 1)
    rel = path.split("?")[0]
    if any((reg["html"] + rel).startswith(b.rstrip("/")) for b in c.get("blocked", [])):
        out("<html><head><title>403 Forbidden</title></head><body><h1>403 Forbidden</h1></body></html>")
        c["logs"].append(f"[error] open() \"{reg['html']}{rel}index.html\" failed (13: Permission denied)")
        save(s)
        return 0
    if rel.endswith("/"):
        rel += "index.php" if os.path.exists(map_path(c, reg["html"] + rel + "index.php")) else "index.html"
    f = map_path(c, reg["html"] + rel)
    if not os.path.isfile(f):
        if "-I" in args:
            out("HTTP/1.1 404 Not Found")
            return 0
        out("<html><head><title>404 Not Found</title></head><body><h1>404 Not Found</h1></body></html>")
        return 0
    if "-I" in args:
        out("HTTP/1.1 200 OK")
        return 0
    if f.endswith(".php") and reg["server"] == "web" and c["base"] == "php":
        r = subprocess.run(["php", f], cwd=os.path.dirname(f), capture_output=True, text=True, timeout=5)
        sys.stdout.write(r.stdout + r.stderr)
    else:
        sys.stdout.write(Path(f).read_text())
    return 0


def main():
    tool, args = sys.argv[1], sys.argv[2:]
    if tool == "docker":
        fail("GOBLINCAKES använder podman – samma kommandon fungerar: skriv podman i stället för docker.", 127)
    return {"podman": podman, "systemctl": systemctl, "curl": curl}[tool](args) or 0


if __name__ == "__main__":
    sys.exit(main())
