"""Containrar (Podman): the user's main.sh runs with the practice podman (sandbox/podrun.py +
fakepodman.py – images alpine, fedora, nginx, mariadb, python, php; systemctl --user for
quadlets; curl against localhost). Checks look for things only the containers can produce
(files inside the image, nginx's page, MariaDB's databases …)."""
from lib import write_track, T

NO_ERROR = r"\A(?![\s\S]*Error)"

M = []
M.append({"id": "cont-forsta", "title": "Vad är en container?", "requires": ["bash-kommandon"],
 "summary": "Image = färdig mall (filer + vad som ska köras), container = en körning av en image. `podman run --rm alpine echo hej`, `podman pull`, `podman images`; rootless = körs som du, inte root.",
 "lesson_md": """
# Vad är en container?

En **container** är ett program som körs i en egen liten låda: egna filer, egen nätverksadress,
men samma Linux-kärna som datorn. Den kan inte röra resten av systemet om du inte ger den lov.
GOBLINCAKES kör Ianseo så – webbservern och databasen i varsin container.

- **Image** = mallen: alla filer som behövs + vad som ska startas. Hämtas från ett register
  (Docker Hub, Quay, Fedoras register …).
- **Container** = en körning av en image. Du kan starta många från samma image.

```bash
podman pull alpine                         # hämta en image
podman images                              # visa hämtade images
podman run --rm alpine echo "Hej"          # starta, kör echo, ta bort efteråt (--rm)
podman run --rm alpine cat /etc/os-release # filen INNE i containern – Alpine, inte Fedora!
```

GOBLINCAKES använder **Podman** (Docker gör samma sak och kommandona är nästan likadana).
Podman körs **rootless** – som ditt eget konto, utan lösenord och utan root.

> Övningsdatorn har inget nätverk, så här finns en övnings-podman med de här imagerna:
> alpine, fedora, nginx, mariadb, python och php. Kommandona och svaren är som de riktiga.
""", "tasks": [
 T("cont-forsta-1", 1, "Första containern", "Kör en container från alpine som skriver Hej från containern och tas bort efteråt. Skriv sedan ut raden PRETTY_NAME ur /etc/os-release inne i en alpine-container (använd grep).",
   'podman run --rm alpine echo "Hej från containern"\npodman run --rm alpine cat /etc/os-release | grep PRETTY_NAME',
   {"regex": r"Hej från containern[\s\S]*PRETTY_NAME=\"Alpine Linux"},
   ["podman run --rm alpine echo \"…\"", "podman run --rm alpine cat /etc/os-release | grep PRETTY_NAME – grep körs utanför, på containerns utskrift."]),
 T("cont-forsta-2", 2, "Två system", "Hämta både alpine och fedora med podman pull, och skriv sedan bara namnen och taggarna med podman images --format \"{{.Repository}}:{{.Tag}}\". Kolla sist vilken Fedora-version containern har (PRETTY_NAME).",
   'podman pull alpine\npodman pull fedora\npodman images --format "{{.Repository}}:{{.Tag}}"\npodman run --rm fedora grep PRETTY_NAME /etc/os-release',
   {"regex": r"^docker\.io/library/alpine:latest$[\s\S]*^registry\.fedoraproject\.org/fedora:44$[\s\S]*Fedora Linux 44"},
   ["podman pull alpine och podman pull fedora.", 'podman images --format "{{.Repository}}:{{.Tag}}"']),
]})

M.append({"id": "cont-bakgrund", "title": "Containrar i bakgrunden", "requires": ["cont-forsta"],
 "summary": "`podman run -d --name web nginx` (bakgrund), `podman ps` / `ps -a` (även stoppade), `podman logs web`, `stop`, `start`, `rm` (`-f` om den kör); samma namn går inte två gånger (`--replace`).",
 "lesson_md": """
# Containrar i bakgrunden

En webbserver eller databas ska köra hela tiden – i bakgrunden:

```bash
podman run -d --name web nginx     # -d = i bakgrunden, --name = ett eget namn
podman ps                          # körande containrar
podman ps -a                       # även stoppade
podman logs web                    # vad containern har skrivit
podman stop web                    # stoppa
podman start web                   # starta igen (samma container, samma filer)
podman rm web                      # ta bort (måste vara stoppad, eller rm -f)
```

`--format` väljer vad ps visar: `podman ps --format "{{.Names}} {{.State}}"`.

Två containrar kan inte heta samma sak. Ta bort den gamla först, eller låt Podman göra det med
`--replace`.
""", "tasks": [
 T("cont-bakgrund-1", 1, "Webbservern i bakgrunden", "Starta nginx i bakgrunden med namnet web, och visa sedan körande containrar med podman ps --format \"{{.Names}} {{.State}}\".",
   'podman run -d --name web nginx\npodman ps --format "{{.Names}} {{.State}}"',
   {"regex": r"^web running$"},
   ["-d och --name web före imagens namn.", 'podman ps --format "{{.Names}} {{.State}}"']),
 T("cont-bakgrund-2", 2, "Loggar och städning", "Starta nginx som web i bakgrunden, visa dess loggar, stoppa den, ta bort den och visa till sist alla containrar (även stoppade) med podman ps -a --format \"{{.Names}}\" – listan ska vara tom. Skriv sist ordet klart.",
   'podman run -d --name web nginx\npodman logs web\npodman stop web\npodman rm web\npodman ps -a --format "{{.Names}}"\necho klart',
   {"regex": r"start worker processes\s+web\s+web\s+klart\s*$"},
   ["podman logs web, podman stop web, podman rm web.", "ps -a visar även stoppade – efter rm ska web vara borta."]),
 T("cont-bakgrund-3", 3, "Namnet är upptaget", "Skriptet startar web två gånger och får ett fel. Rätta det så att den andra raden ersätter den första containern, utan fel, och visa namnen och läget.",
   'podman run -d --name web nginx\npodman run -d --replace --name web nginx\npodman ps -a --format "{{.Names}} {{.State}}"',
   {"regex": NO_ERROR + r"[\s\S]*^web running$"},
   ["Felet säger vad som gäller: ta bort den gamla eller använd --replace.", "podman run -d --replace --name web nginx"],
   'podman run -d --name web nginx\npodman run -d --name web nginx\npodman ps -a --format "{{.Names}} {{.State}}"\n'),
]})

M.append({"id": "cont-portar", "title": "Portar – nå tjänsten", "requires": ["cont-bakgrund"],
 "summary": "`-p 8080:80` = datorns port 8080 → containerns 80; `-p 127.0.0.1:8180:80` = bara den här datorn (Ianseo); rootless får inte portar under 1024; `podman port web`; prova med `curl localhost:8080`.",
 "lesson_md": """
# Portar – nå tjänsten

En container har sitt eget nätverk. För att nå nginx inifrån datorn **publicerar** du en port:

```bash
podman run -d --name web -p 8080:80 nginx     # datorns 8080 → containerns 80
curl localhost:8080                            # hämtar sidan
podman port web                                # 80/tcp -> 0.0.0.0:8080
```

- Första talet är **datorns** port, andra är **containerns**.
- `0.0.0.0` = alla nätverk: andra datorer i nätverket når den också (om brandväggen släpper
  igenom). `-p 127.0.0.1:8180:80` = **bara den här datorn** – så kör GOBLINCAKES Ianseo tills du
  slår på nätverksläget.
- Rootless Podman får inte använda portar under 1024 (t.ex. 80). Ta 8080, 8180 …
- Två containrar kan inte dela samma port på datorn.
""", "tasks": [
 T("cont-portar-1", 1, "Hämta sidan", "Starta nginx som web i bakgrunden med datorns port 8080 kopplad till containerns port 80, och hämta sidan med curl -s localhost:8080.",
   'podman run -d --name web -p 8080:80 nginx\ncurl -s localhost:8080',
   {"contains": ["Welcome to nginx!"]},
   ["-p 8080:80 före imagens namn.", "curl -s localhost:8080"]),
 T("cont-portar-2", 2, "Bara den här datorn", "Starta nginx som web så att port 8180 bara går att nå från den här datorn (som Ianseo), och visa portarna med podman port web.",
   'podman run -d --name web -p 127.0.0.1:8180:80 nginx\npodman port web',
   {"contains": ["80/tcp -> 127.0.0.1:8180"]},
   ["Lägg till adressen först: -p 127.0.0.1:8180:80", "podman port web visar kopplingen."]),
 T("cont-portar-3", 2, "Port 80 går inte", "Skriptet försöker använda port 80 och får ett fel. Rätta det (välj 8080) så att curl visar sidan.",
   'podman run -d --name web -p 8080:80 nginx\ncurl -s localhost:8080',
   {"regex": NO_ERROR + r"[\s\S]*Welcome to nginx!"},
   ["Rootless får inte portar under 1024 – byt datorns port, inte containerns.", "-p 8080:80 och curl localhost:8080"],
   'podman run -d --name web -p 80:80 nginx\ncurl -s localhost\n'),
]})

M.append({"id": "cont-volymer", "title": "Volymer – data som blir kvar", "requires": ["cont-portar"],
 "summary": "Containerns egna filer försvinner med `rm`. Volym: `podman volume create data` + `-v data:/data`; egen mapp: `-v ./sida:/usr/share/nginx/html:Z` (`:Z` = SELinux-etikett på Fedora); databaser alltid på en volym.",
 "lesson_md": """
# Volymer – data som blir kvar

Allt en container skriver i sina egna filer **försvinner när den tas bort**. Det som ska finnas
kvar (databaser, uppladdningar, inställningar) läggs på en **volym**:

```bash
podman volume create data
podman run --rm -v data:/data alpine sh -c "echo hej > /data/fil.txt"
podman run --rm -v data:/data alpine cat /data/fil.txt     # hej – fast det är en ny container
podman volume ls
```

Eller en **mapp på datorn** (bind mount) – bra för en webbsida du redigerar:

```bash
podman run -d -p 8080:80 -v ./sida:/usr/share/nginx/html:Z nginx
```

`:Z` behövs på Fedora/GOBLINCAKES: SELinux märker mappen så att containern får läsa den.
Utan `:Z` blir det "Permission denied" inne i containern.

Ianseo i GOBLINCAKES har databasen på en volym – därför finns tävlingarna kvar när Ianseo
uppdateras.
""", "tasks": [
 T("cont-volymer-1", 1, "Anteckningen överlever", "Skapa volymen spara. Skriv texten Raid kl 20 till /data/anteckning.txt i en alpine-container som har volymen på /data (och tas bort efteråt). Läs sedan filen i en ny container.",
   'podman volume create spara\npodman run --rm -v spara:/data alpine sh -c "echo \'Raid kl 20\' > /data/anteckning.txt"\npodman run --rm -v spara:/data alpine cat /data/anteckning.txt',
   {"regex": r"^Raid kl 20$"},
   ["-v spara:/data i båda containrarna.", "sh -c \"echo 'Raid kl 20' > /data/anteckning.txt\" – omdirigeringen ska ske inne i containern."]),
 T("cont-volymer-2", 2, "Din egen sida", "Gör mappen sida med index.html som innehåller <h1>Goblin-sidan</h1>. Kör nginx med mappen på /usr/share/nginx/html (glöm inte :Z) och port 8080, och hämta sidan med curl.",
   'mkdir sida\necho "<h1>Goblin-sidan</h1>" > sida/index.html\npodman run -d --name web -p 8080:80 -v ./sida:/usr/share/nginx/html:Z nginx\ncurl -s localhost:8080',
   {"contains": ["<h1>Goblin-sidan</h1>"]},
   ["-v ./sida:/usr/share/nginx/html:Z", "Gör filen före podman run."]),
 T("cont-volymer-3", 3, "Databasen finns kvar", "Starta mariadb:11 som db med -e MARIADB_ROOT_PASSWORD=hemligt, -e MARIADB_DATABASE=gilde och volymen dbdata på /var/lib/mysql. Ta bort containern (rm -f) och starta en ny db med samma volym – utan att ange databasen igen. Visa sist databaserna med podman exec db mariadb -uroot -phemligt -e \"SHOW DATABASES\".",
   'podman run -d --name db -e MARIADB_ROOT_PASSWORD=hemligt -e MARIADB_DATABASE=gilde -v dbdata:/var/lib/mysql mariadb:11\npodman rm -f db\npodman run -d --name db -e MARIADB_ROOT_PASSWORD=hemligt -v dbdata:/var/lib/mysql mariadb:11\npodman exec db mariadb -uroot -phemligt -e "SHOW DATABASES"',
   {"regex": NO_ERROR + r"[\s\S]*^gilde$"},
   ["Samma -v dbdata:/var/lib/mysql båda gångerna.", "podman rm -f db tar bort en container som kör."]),
]})

M.append({"id": "cont-miljo", "title": "Miljövariabler och hemligheter", "requires": ["cont-volymer"],
 "summary": "`-e NAMN=värde` och `--env-file fil.env` ställer in containern; MariaDB vägrar starta utan lösenordsval; hemligheter i en fil med `chmod 600` – aldrig i Git eller i Containerfile.",
 "lesson_md": """
# Miljövariabler och hemligheter

Images ställs in med **miljövariabler** i stället för att man ändrar filer i dem:

```bash
podman run --rm -e KLASS=Druid alpine sh -c 'echo "Klass: $KLASS"'
```

(Enkla citattecken: `$KLASS` ska läsas **inne i containern**, inte av din egen terminal.)

MariaDB-imagen läser t.ex. `MARIADB_ROOT_PASSWORD`, `MARIADB_DATABASE`, `MARIADB_USER` och
`MARIADB_PASSWORD`. Utan något lösenordsval vägrar den starta – läs `podman logs`!

## Hemligheter

Skriv inte lösenord direkt i kommandon som hamnar i historiken eller i Git. Lägg dem i en fil som
bara du får läsa:

```bash
printf 'MARIADB_ROOT_PASSWORD=%s\\n' "$(openssl rand -hex 12)" > db.env
chmod 600 db.env                 # bara du
podman run -d --env-file db.env mariadb:11
```

Lägg `db.env` i `.gitignore`. GOBLINCAKES gör så med Ianseo (`~/.config/goblincakes/ianseo.env`).
""", "tasks": [
 T("cont-miljo-1", 1, "Klassen inne i containern", "Kör en alpine-container med miljövariabeln KLASS=Druid som skriver Klass: Druid med hjälp av variabeln.",
   'podman run --rm -e KLASS=Druid alpine sh -c \'echo "Klass: $KLASS"\'',
   {"regex": r"^Klass: Druid$"},
   ["-e KLASS=Druid före imagens namn.", "Enkla citattecken runt sh -c-kommandot, så läses $KLASS inne i containern."]),
 T("cont-miljo-2", 2, "Databasen vill inte starta", "Skriptet startar mariadb utan lösenord och containern stannar. Läs felet (podman logs db), rätta det med MARIADB_ROOT_PASSWORD och skapa databasen gilde med MARIADB_DATABASE. Visa sist läget med podman ps -a --format \"{{.Names}} {{.State}}\".",
   'podman run -d --name db -e MARIADB_ROOT_PASSWORD=hemligt -e MARIADB_DATABASE=gilde mariadb:11\npodman logs db\npodman ps -a --format "{{.Names}} {{.State}}"',
   {"regex": r"Creating database gilde[\s\S]*^db running$"},
   ["Loggen säger vilka variabler som behövs.", "-e MARIADB_ROOT_PASSWORD=… -e MARIADB_DATABASE=gilde"],
   'podman run -d --name db mariadb:11\npodman logs db\npodman ps -a --format "{{.Names}} {{.State}}"\n'),
 T("cont-miljo-3", 3, "Lösenordet i en fil", "Skriv MARIADB_ROOT_PASSWORD=Goblin123 och MARIADB_DATABASE=gilde i filen db.env, ge den rättigheterna 600 och skriv ut dem med stat -c %a db.env. Starta mariadb:11 som db med --env-file db.env och visa databaserna (lösenordet får du med . db.env eller source i skriptet).",
   'printf "MARIADB_ROOT_PASSWORD=Goblin123\\nMARIADB_DATABASE=gilde\\n" > db.env\nchmod 600 db.env\nstat -c %a db.env\npodman run -d --name db --env-file db.env mariadb:11\n. ./db.env\npodman exec db mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e "SHOW DATABASES"',
   {"regex": r"^600$[\s\S]*^gilde$"},
   ["printf med \\n skriver två rader; chmod 600 db.env.", '. ./db.env läser in variablerna i skriptet; -p"$MARIADB_ROOT_PASSWORD" (inget mellanslag efter -p).']),
]})

M.append({"id": "cont-bygga", "title": "Egen image med Containerfile", "requires": ["cont-miljo"],
 "summary": "`Containerfile`: `FROM`, `WORKDIR`, `COPY`, `RUN`, `ENV`, `EXPOSE`, `CMD [\"python3\", \"app.py\"]`; `podman build -t namn .`; `-e` vid run går före `ENV`; inga hemligheter i imagen.",
 "lesson_md": """
# Egen image med Containerfile

En **Containerfile** (Docker kallar den Dockerfile) är receptet för en egen image:

```dockerfile
FROM python:3.13-slim        # börja från en färdig image
WORKDIR /app                 # gå till /app (skapas)
COPY app.py .                # kopiera från din mapp in i imagen
RUN pip install requests     # kör ett kommando när imagen byggs
ENV KLASS=Shaman             # standardvärde – kan ändras med -e
EXPOSE 8000                  # dokumentation: tjänsten lyssnar här
CMD ["python3", "app.py"]    # vad som startar när containern körs
```

```bash
podman build -t goblinapp .       # bygg (punkten = den här mappen)
podman run --rm goblinapp
podman run --rm -e KLASS=Mage goblinapp
```

- Varje rad blir ett **lager**; ändrar du bara app.py byggs bara det som kommer efter COPY om.
- Lägg aldrig lösenord i Containerfile – de syns för alla som har imagen. Använd `-e` eller
  `--env-file` när containern startar.

> Övningsdatorn har inget nätverk: `RUN dnf/pip install …` låtsas att paketen kom med.
""", "tasks": [
 T("cont-bygga-1", 2, "Hej från min image", "Skriv hej.py som skriver Hej från min image!, och en Containerfile: FROM python:3.13-slim, WORKDIR /app, COPY hej.py ., CMD som kör python3 hej.py. Bygg den som hej och kör den.",
   "cat > hej.py <<'EOF'\nprint(\"Hej från min image!\")\nEOF\ncat > Containerfile <<'EOF'\nFROM python:3.13-slim\nWORKDIR /app\nCOPY hej.py .\nCMD [\"python3\", \"hej.py\"]\nEOF\npodman build -t hej .\npodman run --rm hej",
   {"regex": r"Successfully tagged localhost/hej:latest[\s\S]*^Hej från min image!$"},
   ["cat > fil <<'EOF' … EOF skriver flera rader till en fil.", 'CMD ["python3", "hej.py"] – JSON med dubbla citattecken.']),
 T("cont-bygga-2", 2, "Standardvärde och eget värde", "Gör välkommen.py som skriver Välkommen, <GAST> (läs miljövariabeln GAST med os.environ). Containerfile med ENV GAST=främling. Bygg som valkommen, kör den en gång utan och en gång med -e GAST=Kaytho.",
   "cat > valkommen.py <<'EOF'\nimport os\nprint(\"Välkommen,\", os.environ[\"GAST\"])\nEOF\ncat > Containerfile <<'EOF'\nFROM python:3.13-slim\nWORKDIR /app\nCOPY valkommen.py .\nENV GAST=främling\nCMD [\"python3\", \"valkommen.py\"]\nEOF\npodman build -t valkommen .\npodman run --rm valkommen\npodman run --rm -e GAST=Kaytho valkommen",
   {"regex": r"^Välkommen, främling$\s+^Välkommen, Kaytho$"},
   ["ENV GAST=främling i Containerfile.", "-e GAST=Kaytho när du kör går före ENV."]),
 T("cont-bygga-3", 3, "Webbsidan i imagen", "Gör mappen sida med index.html (<h1>Gildets sida</h1>). Bygg en image minsida från nginx som kopierar in mappen till /usr/share/nginx/html/. Kör den i bakgrunden på port 8080 och hämta sidan med curl.",
   "mkdir sida\necho \"<h1>Gildets sida</h1>\" > sida/index.html\ncat > Containerfile <<'EOF'\nFROM nginx\nCOPY sida/ /usr/share/nginx/html/\nEOF\npodman build -t minsida .\npodman run -d --name web -p 8080:80 minsida\ncurl -s localhost:8080",
   {"contains": ["<h1>Gildets sida</h1>"]},
   ["COPY sida/ /usr/share/nginx/html/ kopierar mappens innehåll.", "nginx-imagen startar webbservern själv – ingen CMD behövs."]),
]})

M.append({"id": "cont-pod", "title": "Pods – containrar som hör ihop", "requires": ["cont-bygga"],
 "summary": "`podman pod create --name ianseo -p 8180:80`; `podman run -d --pod ianseo …`; containrarna i en pod delar nätverk (når varandra på localhost) och portarna sätts på poden; `podman pod ps`, `pod rm -f`.",
 "lesson_md": """
# Pods – containrar som hör ihop

En webbsida med databas är två containrar som måste prata med varandra. En **pod** är en grupp
containrar som delar nätverk – de når varandra på `localhost`, precis som på en vanlig server.

```bash
podman pod create --name ianseo -p 8180:80          # portarna sätts på poden
podman run -d --pod ianseo --name ianseo-db -e MARIADB_ROOT_PASSWORD=… mariadb:11
podman run -d --pod ianseo --name ianseo-web php:8.3-apache
podman pod ps
podman pod rm -f ianseo                              # tar bort allt i poden
```

- `-p` går **bara** på poden, inte på containrarna i den.
- Webbcontainern når databasen på `localhost:3306`.
- Så är Ianseo uppbyggt i GOBLINCAKES: poden `ianseo` med `ianseo-db` och `ianseo-web`.
""", "tasks": [
 T("cont-pod-1", 2, "Webb och databas i en pod", "Skapa poden spel med port 8080:80. Starta nginx som spel-web och mariadb:11 (med root-lösenord) som spel-db i poden. Visa poden med podman pod ps och containrarna med podman ps --format \"{{.Names}} {{.PodName}}\".",
   'podman pod create --name spel -p 8080:80\npodman run -d --pod spel --name spel-web nginx\npodman run -d --pod spel --name spel-db -e MARIADB_ROOT_PASSWORD=hemligt mariadb:11\npodman pod ps\npodman ps --format "{{.Names}} {{.PodName}}"',
   {"regex": NO_ERROR + r"[\s\S]*spel\s+Running[\s\S]*^spel-web spel$[\s\S]*^spel-db spel$"},
   ["podman pod create --name spel -p 8080:80", "--pod spel i båda podman run."]),
 T("cont-pod-2", 3, "Porten på fel ställe", "Skriptet får ett fel när webbcontainern startas. Rätta det så att sidan går att hämta med curl på port 8080.",
   'podman pod create --name spel -p 8080:80\npodman run -d --pod spel --name spel-web nginx\ncurl -s localhost:8080',
   {"regex": NO_ERROR + r"[\s\S]*Welcome to nginx!"},
   ["Läs felet: portarna måste sättas när poden skapas.", "Flytta -p 8080:80 till podman pod create."],
   'podman pod create --name spel\npodman run -d --pod spel --name spel-web -p 8080:80 nginx\ncurl -s localhost:8080\n'),
]})

M.append({"id": "cont-quadlet", "title": "Quadlets – containrar som startar själva", "requires": ["cont-pod"],
 "summary": "Filer i `~/.config/containers/systemd/`: `namn.container` ([Container] Image=, PublishPort=, Volume=, Environment=, Pod=), `.pod`, `.volume`; `[Install] WantedBy=default.target` = start vid inloggning; `systemctl --user daemon-reload` + `start`; `enable` fungerar inte (genererade enheter).",
 "lesson_md": """
# Quadlets – containrar som startar själva

Med `podman run` måste du starta containern själv efter varje omstart. En **quadlet** är en
liten fil som låter systemd sköta den – starta vid inloggning, starta om om den kraschar:

```ini
# ~/.config/containers/systemd/web.container
[Unit]
Description=Min webbsida

[Container]
Image=docker.io/library/nginx:latest
PublishPort=127.0.0.1:8090:80
Volume=%h/sida:/usr/share/nginx/html:Z

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload     # läs in filerna (gör om efter varje ändring)
systemctl --user start web         # enheten heter som filen
systemctl --user status web
```

- `%h` = din hemmapp.
- `WantedBy=default.target` = startar vid inloggning. `systemctl --user enable` fungerar
  **inte** för quadlets – det är [Install]-raden som gäller.
- `.pod`-filer (`[Pod]` med `PodName=` och `PublishPort=`) och `.volume`-filer finns också.
  En container går med i poden med `Pod=ianseo.pod` och använder volymen med
  `Volume=ianseo-db.volume:/var/lib/mysql`.

GOBLINCAKES Ianseo är precis det här: titta i `~/.config/containers/systemd/` om du har det.
""", "tasks": [
 T("cont-quadlet-1", 2, "Webbsidan som quadlet", "Skriv ~/.config/containers/systemd/web.container: nginx, port 127.0.0.1:8090:80, startar vid inloggning. Läs in den, starta web, skriv ut systemctl --user is-active web och hämta sidan med curl.",
   "mkdir -p ~/.config/containers/systemd\ncat > ~/.config/containers/systemd/web.container <<'EOF'\n[Unit]\nDescription=Min webbsida\n\n[Container]\nImage=docker.io/library/nginx:latest\nPublishPort=127.0.0.1:8090:80\n\n[Install]\nWantedBy=default.target\nEOF\nsystemctl --user daemon-reload\nsystemctl --user start web\nsystemctl --user is-active web\ncurl -s localhost:8090",
   {"regex": NO_ERROR + r"[\s\S]*^active$[\s\S]*Welcome to nginx!"},
   ["mkdir -p ~/.config/containers/systemd och skriv filen med cat > … <<'EOF'.", "daemon-reload först, sedan start web."]),
 T("cont-quadlet-2", 3, "Som Ianseo", "Bygg Ianseos upplägg med quadlets: ianseo.pod (PodName=ianseo, PublishPort=127.0.0.1:8180:80), ianseo-db.volume, och ianseo-db.container (mariadb:11, Pod=ianseo.pod, Environment=MARIADB_ROOT_PASSWORD=ianseo MARIADB_DATABASE=ianseo, Volume=ianseo-db.volume:/var/lib/mysql). Läs in, starta ianseo-db och visa databaserna med podman exec.",
   "d=~/.config/containers/systemd\nmkdir -p $d\ncat > $d/ianseo.pod <<'EOF'\n[Pod]\nPodName=ianseo\nPublishPort=127.0.0.1:8180:80\nEOF\ncat > $d/ianseo-db.volume <<'EOF'\n[Volume]\nEOF\ncat > $d/ianseo-db.container <<'EOF'\n[Container]\nImage=docker.io/library/mariadb:11\nContainerName=ianseo-db\nPod=ianseo.pod\nEnvironment=MARIADB_ROOT_PASSWORD=ianseo MARIADB_DATABASE=ianseo\nVolume=ianseo-db.volume:/var/lib/mysql\n\n[Install]\nWantedBy=default.target\nEOF\nsystemctl --user daemon-reload\nsystemctl --user start ianseo-db\npodman pod ps\npodman exec ianseo-db mariadb -uroot -pianseo -e \"SHOW DATABASES\"",
   {"regex": NO_ERROR + r"[\s\S]*ianseo\s+Running[\s\S]*^ianseo$"},
   ["Tre filer: .pod, .volume och .container – Pod= och Volume= pekar på de andra filerna.",
    "ContainerName=ianseo-db, annars heter containern systemd-ianseo-db."]),
]})

# Every regex check reads line by line (^ and $ at each line)
for m in M:
    for t in m["tasks"]:
        if "regex" in t["check"]:
            t["check"]["regex"] = "(?m)" + t["check"]["regex"]

write_track("containrar", M)
