"""GoblinShare's terminal (4 Nov, the user: "gör ssh funktionen till goblinshare" – a terminal on the other
GOBLINCAKES computer, and Claude Code here can run commands there).

    the computer that lets others in   GoblinShare → Inställningar → "Tillåt terminal på den här datorn"
                                       (root: goblincakes-tweak set share-ssh on – sshd on, keys only, no
                                       root login; off = sshd back as it was and every key below removed)
    pairing (once)                     Terminal on a GOBLINCAKES card → POST /api/goblincakes/v1/ssh with our
                                       public key → a notification there (Tillåt / Neka) → the key goes in
                                       ~/.ssh/authorized_keys, only from the home network (from="…"),
                                       restrict,pty, the comment goblinshare:<fingerprint>; the answer has the
                                       login name and the computer's host key.
    using it                           ~/.ssh/goblinshare.conf (Include at the top of ~/.ssh/config): a Host
                                       per paired computer, named after it ("frugans-laptop"), its current
                                       address (rewritten when GoblinShare sees it at a new one), our key
                                       ~/.ssh/goblinshare_ed25519 and its host key in
                                       ~/.ssh/goblinshare_known_hosts. So `ssh frugans-laptop` works in any
                                       terminal – also for Claude Code.

Only the standard library + ssh-keygen. Paths can be moved for tests with GOBLINCAKES_SSH_DIR (instead of
~/.ssh), GOBLINCAKES_SSHD_DROPIN, GOBLINCAKES_SSH_HOSTKEY and GOBLINCAKES_SSH_NETS.
"""
import base64
import os
import re
import subprocess
from pathlib import Path

SSH_DIR = Path(os.environ.get("GOBLINCAKES_SSH_DIR") or Path.home() / ".ssh")
KEY = SSH_DIR / "goblinshare_ed25519"
CLIENT_CONF = SSH_DIR / "goblinshare.conf"
KNOWN = SSH_DIR / "goblinshare_known_hosts"
AUTH = SSH_DIR / "authorized_keys"
USER_CONF = SSH_DIR / "config"
INCLUDE = "Include goblinshare.conf   # GoblinShare: Terminal (ssh <namn>)"
TAG = "goblinshare:"
# Written by goblincakes-tweak share-ssh – its existence = "Tillåt terminal" is on
DROPIN = Path(os.environ.get("GOBLINCAKES_SSHD_DROPIN") or "/etc/ssh/sshd_config.d/10-goblincakes-share.conf")
HOSTKEY = Path(os.environ.get("GOBLINCAKES_SSH_HOSTKEY") or "/etc/ssh/ssh_host_ed25519_key.pub")
TWEAK = os.environ.get("GOBLINCAKES_TWEAK") or "/usr/libexec/goblincakes-tweak"
# Home networks only: a key that leaks can't be used from the internet even if the router forwards port 22
HOME_NETS = os.environ.get("GOBLINCAKES_SSH_NETS") or "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16"
KEY_RE = re.compile(r"^ssh-ed25519 [A-Za-z0-9+/]{60,100}={0,2}$")


def allowed_here():
    return DROPIN.exists()


def set_allowed(on):
    """Runs the root part (polkit asks for the password) – from the window or a terminal, not the service:
    a user service has no session, so polkit can't ask there. → "" or why not."""
    try:
        r = subprocess.run(["pkexec", TWEAK, "set", "share-ssh", "on" if on else "off"],
                           capture_output=True, text=True, timeout=300)
    except (OSError, subprocess.TimeoutExpired) as e:
        return f"Gick inte: {e}"
    if r.returncode in (126, 127):
        return "Inget lösenord – ingenting ändrades"
    if r.returncode != 0:
        said = (r.stderr or r.stdout).strip()
        return said.splitlines()[-1] if said else "Gick inte"
    if not on:
        revoke()
    return ""


def _private_dir():
    SSH_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        SSH_DIR.chmod(0o700)
    except OSError:
        pass


def _relabel(*paths):
    """SELinux: files we create in ~/.ssh must be ssh_home_t, or sshd can't read authorized_keys."""
    try:
        subprocess.run(["restorecon", "-F", *[str(p) for p in paths if Path(p).exists()]],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        pass


def _write(path, text, mode=0o600):
    tmp = path.with_name(path.name + ".goblinshare-tmp")
    tmp.write_text(text)
    tmp.chmod(mode)
    tmp.replace(path)


# ── The computer that lets others in ─────────────────────────────────────────

def valid_key(key):
    key = str(key or "").strip()
    if not KEY_RE.match(key):
        return ""
    try:
        blob = base64.b64decode(key.split()[1], validate=True)
    except ValueError:
        return ""
    return key if blob[4:15] == b"ssh-ed25519" else ""


def clean_fp(fp):
    return re.sub(r"[^0-9A-Za-z]", "", str(fp or ""))[:128]


def grant(fp, key):
    """Lets the computer with this fingerprint in with its key (an older key of the same computer goes)."""
    key = valid_key(key)
    fp = clean_fp(fp)
    if not key or not fp:
        return False
    _private_dir()
    lines = [l for l in _auth_lines() if not l.rstrip().endswith(" " + TAG + fp)]
    lines.append(f'from="{HOME_NETS}",restrict,pty {key} {TAG}{fp}')
    _write(AUTH, "\n".join(lines) + "\n")
    _relabel(SSH_DIR, AUTH)
    return True


def _auth_lines():
    try:
        return AUTH.read_text().splitlines()
    except OSError:
        return []


def granted():
    """The fingerprints that are let in here now (read from authorized_keys itself)."""
    out = []
    for line in _auth_lines():
        word = line.rstrip().rsplit(" ", 1)[-1]
        if word.startswith(TAG):
            out.append(word[len(TAG):])
    return out


def revoke(fp=None):
    """Removes one computer's key (or all of GoblinShare's). The user's own keys are left alone."""
    fp = None if fp is None else clean_fp(fp)
    lines = _auth_lines()
    keep = [l for l in lines if not (l.rstrip().rsplit(" ", 1)[-1].startswith(TAG)
                                    and (fp is None or l.rstrip().endswith(" " + TAG + fp)))]
    if keep != lines:
        _write(AUTH, "\n".join(keep) + ("\n" if keep else ""))
        return True
    return False


def host_key():
    try:
        parts = HOSTKEY.read_text().split()
        return f"{parts[0]} {parts[1]}" if len(parts) >= 2 and parts[0] == "ssh-ed25519" else ""
    except OSError:
        return ""


# ── The computer that opens the terminal ─────────────────────────────────────

def own_key(comment="GoblinShare"):
    """Our public key (made once, no passphrase – it only works from the home network, and only on the
    computers that said Tillåt)."""
    pub = KEY.with_suffix(".pub")
    if not KEY.exists() or not pub.exists():
        _private_dir()
        KEY.unlink(missing_ok=True)
        pub.unlink(missing_ok=True)
        r = subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", comment, "-f", str(KEY)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=30)
        if r.returncode != 0:
            raise OSError(r.stderr.strip() or "ssh-keygen gick inte")
        _relabel(KEY, pub)
    parts = pub.read_text().split()
    return f"{parts[0]} {parts[1]}"


def host_name(alias, taken=()):
    """The name for `ssh <namn>`: "Frugans laptop" → frugans-laptop."""
    s = alias.lower()
    for a, b in (("å", "a"), ("ä", "a"), ("ö", "o"), ("é", "e"), ("ü", "u")):
        s = s.replace(a, b)
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")[:40] or "goblincakes"
    name, n = s, 2
    while name in taken:
        name, n = f"{s}-{n}", n + 1
    return name


def write_client(paired):
    """~/.ssh/goblinshare.conf + known hosts from share.json's sshPaired {fp: {host, ip, user, hostKey}};
    the Include at the top of ~/.ssh/config (Include must come before any Host)."""
    _private_dir()
    blocks, known = ["# Written by GoblinShare (Terminal) – changed when the computers change address\n"], []
    for fp, p in sorted(paired.items(), key=lambda kv: kv[1].get("host", "")):
        if not (p.get("host") and p.get("ip") and p.get("user")):
            continue
        alias = "goblinshare-" + fp[:16]
        blocks.append(f"Host {p['host']}\n    HostName {p['ip']}\n    User {p['user']}\n"
                      f"    IdentityFile {KEY}\n    IdentitiesOnly yes\n    HostKeyAlias {alias}\n"
                      f"    UserKnownHostsFile {KNOWN}\n"
                      f"    StrictHostKeyChecking {'yes' if p.get('hostKey') else 'accept-new'}\n"
                      f"    ConnectTimeout 8\n    ServerAliveInterval 30\n")
        if p.get("hostKey"):
            known.append(f"{alias} {p['hostKey']}")
    _write(CLIENT_CONF, "\n".join(blocks))
    _write(KNOWN, "\n".join(known) + ("\n" if known else ""), 0o644)
    try:
        text = USER_CONF.read_text()
    except OSError:
        text = ""
    if not any(l.strip().startswith("Include goblinshare.conf") for l in text.splitlines()):
        _write(USER_CONF, INCLUDE + "\n" + ("\n" + text if text else ""))
    _relabel(SSH_DIR, CLIENT_CONF, KNOWN, USER_CONF)


def remove_include():
    try:
        text = USER_CONF.read_text()
    except OSError:
        return
    lines = [l for l in text.splitlines() if not l.strip().startswith("Include goblinshare.conf")]
    while lines and not lines[0].strip():
        lines.pop(0)
    if lines:
        _write(USER_CONF, "\n".join(lines) + "\n")
    else:
        USER_CONF.unlink(missing_ok=True)


def valid_hostkey(key):
    """The host key the other computer sent (ed25519 only) – kept, so a computer that pretends to be it
    later is stopped by ssh."""
    return valid_key(" ".join(str(key or "").split()[:2]))


def check(host):
    """Does `ssh <host>` get in? → "ok", "denied" (our key is gone there, or Tillåt terminal is off – pair
    again), "hostkey" (the computer has new host keys: reinstalled, or not the same computer) or "unreachable"."""
    try:
        r = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=6", host, "true"],
                           capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        return "unreachable"
    if r.returncode == 0:
        return "ok"
    err = r.stderr
    if "Permission denied" in err:
        return "denied"
    if "IDENTIFICATION HAS CHANGED" in err or "Host key verification failed" in err:
        return "hostkey"
    return "unreachable"
