from lib import write_track, T
M = []
M.append({"id": "bash-kommandon", "title": "Terminalen: filer och mappar", "requires": [],
 "summary": "`ls`, `cd`, `pwd`, `mkdir -p`, `touch`, `cat`, `cp`, `mv`, `rm` (`-r` för mappar); `echo text > fil` skriver, `>>` lägger till; `~` = hemmappen.",
 "lesson_md": """
# Terminalen: filer och mappar

Terminalen styr datorn med kommandon. De viktigaste:

| Kommando | Gör |
|---|---|
| `pwd` | var är jag? |
| `ls` / `ls -la` | visa filer (även dolda, med detaljer) |
| `cd mapp` / `cd ..` / `cd ~` | gå in / upp en nivå / hem |
| `mkdir -p a/b` | skapa mappar |
| `touch fil.txt` | skapa en tom fil |
| `cat fil.txt` | visa innehållet |
| `cp a b` / `mv a b` | kopiera / flytta eller byta namn |
| `rm fil` / `rm -r mapp` | ta bort (**ingen papperskorg!**) |

`echo "text" > fil.txt` skriver text till en fil (tömmer den först), `>>` lägger till sist.

Tips: **Tab** fyller i filnamn, **↑** tar fram förra kommandot, `man ls` visar hjälpen.
""", "tasks": [
 T("bash-kommandon-1", 1, "Raidlista", "Skapa mappen raid, skriv raden Kaytho till filen raid/lista.txt, lägg till raden Bo, och visa filen med cat.",
   'mkdir -p raid\necho "Kaytho" > raid/lista.txt\necho "Bo" >> raid/lista.txt\ncat raid/lista.txt', {"expect": "Kaytho\nBo"},
   ["> skriver, >> lägger till.", "cat raid/lista.txt visar filen."]),
 T("bash-kommandon-2", 2, "Byt namn", "Skapa filen gammal.txt med texten hej, byt namn på den till ny.txt och visa sedan alla .txt-filer med ls.",
   'echo "hej" > gammal.txt\nmv gammal.txt ny.txt\nls *.txt', {"expect": "ny.txt"},
   ["mv byter namn.", "ls *.txt visar bara .txt-filer."]),
]})
M.append({"id": "bash-variabler", "title": "Variabler och kommandon i kommandon", "requires": ["bash-kommandon"],
 "summary": "`namn=värde` (inga mellanslag runt =), `\"$namn\"` (citattecken!), `$(kommando)`, räkna med `$(( a * b ))`.",
 "lesson_md": """
# Variabler och kommandon i kommandon

```bash
namn="Kaytho"
echo "Hej $namn"
antal=$(ls | wc -l)          # resultatet av ett kommando
echo "Det finns $antal filer"
echo $(( 6 * 12 ))           # räkna med heltal
```

- **Inga mellanslag** runt `=` (`namn = x` blir ett fel).
- Sätt variabler inom **dubbla citattecken** `"$namn"` – annars delas värden med mellanslag upp.
  Enkla citattecken `'$namn'` skriver ut texten precis som den står.
- `$(…)` kör ett kommando och ger dess utskrift. `$(( … ))` räknar.
""", "tasks": [
 T("bash-variabler-1", 1, "Hej med variabel", 'Sätt namn="Kaytho" och skriv ut: Hej Kaytho!',
   'namn="Kaytho"\necho "Hej $namn!"', {"expect": "Hej Kaytho!"}, ['echo "Hej $namn!"', "Inga mellanslag runt =."]),
 T("bash-variabler-2", 2, "Räkna pilar", "Sätt pilar=6 och serier=12 och skriv ut: Totalt 72 pilar",
   'pilar=6\nserier=12\necho "Totalt $(( pilar * serier )) pilar"', {"expect": "Totalt 72 pilar"},
   ["$(( … )) räknar.", 'echo "Totalt $(( pilar * serier )) pilar"']),
]})
M.append({"id": "bash-pipes", "title": "Pipor: grep, sort, wc", "requires": ["bash-variabler"],
 "summary": "`|` skickar utskrift vidare; `grep ord` (`-i`, `-v`, `-c`), `sort` (`-n`, `-r`), `uniq -c`, `wc -l`, `head`/`tail -n`, `cut -d' ' -f1`.",
 "lesson_md": """
# Pipor: grep, sort, wc

Med `|` (pipe) blir ett kommandos utskrift nästa kommandos indata:

```bash
cat logg.txt | grep "ERROR" | wc -l     # hur många felrader?
sort namn.txt | uniq -c                  # hur många av varje
```

| Verktyg | Gör |
|---|---|
| `grep ord` | rader som innehåller ordet (`-i` struntar i versaler, `-v` = de som inte gör det) |
| `sort` | sorterar (`-n` som tal, `-r` baklänges) |
| `uniq -c` | räknar likadana rader i följd (sortera först) |
| `wc -l` | antal rader |
| `head -n 3` / `tail -n 3` | första / sista raderna |
| `cut -d' ' -f1` | första fältet i varje rad |

Det här är vardag i Linux – t.ex. `journalctl --user -b | grep -i fel`.
""", "tasks": [
 T("bash-pipes-1", 1, "Räkna fel", "Filen logg.txt finns. Skriv ut hur många rader som innehåller ERROR.",
   'grep "ERROR" logg.txt | wc -l', {"expect": "3"}, ["grep ERROR logg.txt ger raderna.", "| wc -l räknar dem."],
   files={"logg.txt": "INFO start\nERROR disk\nINFO ok\nERROR nät\nERROR disk\n"}),
 T("bash-pipes-2", 2, "Vanligaste felet", "Ur logg.txt: räkna hur många gånger varje ERROR-rad förekommer och skriv ut den vanligaste raden med antal, t.ex. 2 ERROR disk",
   "grep ERROR logg.txt | sort | uniq -c | sort -rn | head -n 1 | sed 's/^ *//'", {"expect": "2 ERROR disk"},
   ["sort | uniq -c räknar, sort -rn sorterar störst först.", "head -n 1 tar den översta; sed 's/^ *//' tar bort mellanslagen först."],
   files={"logg.txt": "INFO start\nERROR disk\nINFO ok\nERROR nät\nERROR disk\n"}),
]})
M.append({"id": "bash-villkor", "title": "Villkor och felkoder", "requires": ["bash-pipes"],
 "summary": "`if [ -f fil ]; then … elif … else … fi`; `-f`/`-d`/`-z`, tal `-eq -lt -gt`, text `=`/`!=`; `$?`, `&&`, `||`.",
 "lesson_md": """
# Villkor och felkoder

Varje kommando avslutas med en **felkod**: `0` = gick bra, annat = fel. Den finns i `$?`.

```bash
if [ -f inställningar.txt ]; then
  echo "Filen finns"
else
  echo "Filen saknas"
fi
```

| Test | Betyder |
|---|---|
| `-f fil` / `-d mapp` | finns filen / mappen? |
| `-z "$x"` | är texten tom? |
| `"$a" = "$b"` | samma text |
| `$a -eq $b`, `-lt`, `-gt` | tal: lika, mindre, större |

Kortare: `mkdir backup && echo "klart"` (bara om det gick) och `cd mapp || exit 1` (om det inte gick).
Mellanslagen inne i `[ … ]` är **obligatoriska**.
""", "tasks": [
 T("bash-villkor-1", 1, "Finns filen?", "Skriv ut Finns om filen config.txt finns, annars Saknas.",
   'if [ -f config.txt ]; then\n  echo "Finns"\nelse\n  echo "Saknas"\nfi', {"expect": "Saknas"},
   ["[ -f config.txt ] testar om filen finns.", "if …; then … else … fi"]),
 T("bash-villkor-2", 2, "Diskvarning", "Variabeln anvand=91 (procent av disken). Skriv ut Varning om den är över 90, annars OK.",
   'anvand=91\nif [ "$anvand" -gt 90 ]; then\n  echo "Varning"\nelse\n  echo "OK"\nfi', {"expect": "Varning"},
   ["-gt betyder större än för tal.", 'if [ "$anvand" -gt 90 ]; then'], "anvand=91\n"),
]})
M.append({"id": "bash-loopar", "title": "Loopar", "requires": ["bash-villkor"],
 "summary": "`for x in a b c; do … done`, `for f in *.txt`, `for i in {1..5}`; `while read -r rad; do … done < fil`.",
 "lesson_md": """
# Loopar

```bash
for namn in Kaytho Bo Cia; do
  echo "Hej $namn"
done

for fil in *.txt; do
  echo "Hittade $fil"
done

for i in {1..3}; do echo "$i"; done

while read -r rad; do
  echo "Rad: $rad"
done < lista.txt
```

`for f in *.txt` är det vanligaste sättet att göra något med många filer – t.ex. byta namn eller
packa ner dem.
""", "tasks": [
 T("bash-loopar-1", 1, "Hälsa på alla", "Skriv ut Hej Kaytho, Hej Bo och Hej Cia på var sin rad med en for-loop.",
   'for namn in Kaytho Bo Cia; do\n  echo "Hej $namn"\ndone', {"expect": "Hej Kaytho\nHej Bo\nHej Cia"},
   ["for namn in Kaytho Bo Cia; do … done", 'echo "Hej $namn"']),
 T("bash-loopar-2", 2, "Byt ändelse", "Mappen har a.log och b.log. Byt namn på alla .log-filer till .txt och visa sedan filerna med ls.",
   'for f in *.log; do\n  mv "$f" "${f%.log}.txt"\ndone\nls', {"expect": "a.txt\nb.txt"},
   ['"${f%.log}" tar bort .log från slutet av namnet.', 'mv "$f" "${f%.log}.txt"'],
   files={"a.log": "a\n", "b.log": "b\n"}),
]})
M.append({"id": "bash-funktioner", "title": "Skript och funktioner", "requires": ["bash-loopar"],
 "summary": "`#!/bin/bash` + `chmod +x`; argument `$1 $2 \"$@\" $#`; `namn() { … }`; `local`; `set -euo pipefail`.",
 "lesson_md": """
# Skript och funktioner

Ett **skript** är en fil med kommandon. Första raden säger vilket program som ska köra det:

```bash
#!/bin/bash
set -euo pipefail          # stanna vid fel – gör skript mycket säkrare
echo "Hej $1"
```

Gör filen körbar med `chmod +x hej.sh` och kör `./hej.sh Kaytho`. Argumenten heter `$1`, `$2` …,
alla på en gång `"$@"`, antalet `$#`.

**Funktioner** fungerar likadant:

```bash
halsa() {
  local namn="$1"
  echo "Hej $namn"
}
halsa Kaytho
```

Lägg egna skript i `~/.local/bin` – då kan du köra dem var som helst i terminalen.
""", "tasks": [
 T("bash-funktioner-1", 2, "En funktion med argument", "Skriv funktionen summa som skriver ut summan av sina två argument, och anropa summa 40 2 (ska skriva 42).",
   'summa() {\n  echo $(( $1 + $2 ))\n}\nsumma 40 2', {"expect": "42"},
   ["$1 och $2 är argumenten.", "echo $(( $1 + $2 ))"]),
 T("bash-funktioner-2", 3, "Säkerhetskopia", 'Skriv funktionen backup som kopierar filen i $1 till samma namn + .bak och skriver "Sparade <fil>.bak". Anropa backup anteckning.txt och visa sedan .bak-filens innehåll.',
   'backup() {\n  cp "$1" "$1.bak"\n  echo "Sparade $1.bak"\n}\nbackup anteckning.txt\ncat anteckning.txt.bak', {"expect": "Sparade anteckning.txt.bak\nviktigt"},
   ['cp "$1" "$1.bak"', "Glöm inte citattecknen runt $1."], files={"anteckning.txt": "viktigt\n"}),
]})
M.append({"id": "bash-rattigheter", "title": "Rättigheter", "requires": ["bash-funktioner"],
 "summary": "`ls -l`: rwx för ägare/grupp/andra; `chmod +x`, `chmod 644`/`755`/`600`; `sudo` = som administratör.",
 "lesson_md": """
# Rättigheter

`ls -l` visar t.ex. `-rwxr-xr--`: tre grupper om tre – **ägaren**, **gruppen**, **alla andra** –
med **r**ead (läsa), **w**rite (skriva) och e**x**ecute (köra).

Som tal: r = 4, w = 2, x = 1, ihop per grupp:

| Tal | Betyder | Används för |
|---|---|---|
| `644` | rw-r--r-- | vanliga filer |
| `755` | rwxr-xr-x | skript och mappar |
| `600` | rw------- | hemligheter (nycklar, lösenord) |

```bash
chmod +x skript.sh      # gör körbar
chmod 600 nyckel.txt    # bara du får läsa
stat -c %a nyckel.txt   # visar 600
```

`sudo` kör ett kommando som administratör – bara när det verkligen behövs.
""", "tasks": [
 T("bash-rattigheter-1", 2, "En hemlig fil", "Skapa filen nyckel.txt, ge den rättigheterna så att bara du kan läsa och skriva, och skriv ut rättigheterna med stat -c %a.",
   'touch nyckel.txt\nchmod 600 nyckel.txt\nstat -c %a nyckel.txt', {"expect": "600"},
   ["Läsa + skriva = 4 + 2 = 6, för andra 0.", "chmod 600 nyckel.txt"]),
]})
M.append({"id": "linux-goblincakes", "title": "Linux i GOBLINCAKES", "requires": ["bash-rattigheter"],
 "summary": "Atomiskt: `/usr` går inte att ändra, `rpm-ostree` byter hela systemet (rollback vid start); program = Flatpak; egna saker i hemmappen; `systemctl --user`, `journalctl --user`; `goblin`-kommandona.",
 "lesson_md": """
# Linux i GOBLINCAKES

GOBLINCAKES är ett **atomiskt** system: hela systemet (`/usr`) är en färdig bild som inte går att
ändra medan det kör. Uppdateringar hämtar en ny bild som används **vid nästa start** – och går
något fel väljer man förra versionen i startmenyn.

| Sak | Hur |
|---|---|
| Uppdatera allt | `goblin update` |
| Program | Flatpak (`flatpak list`, `flatpak install …`) eller GOBLINCAKES Config |
| Systempaket (sällan) | `rpm-ostree install …` – gäller efter omstart |
| Egna skript | `~/.local/bin` |
| Inställningar | `~/.config` (dolda mappar börjar med punkt) |
| Tjänster | `systemctl --user status goblincakes-ollama` |
| Loggar | `journalctl --user -b` (sedan senaste start) |
| Skrivbara systemdelar | `/etc` och `/var` |

`goblin help` visar alla GOBLINCAKES-kommandon.
""", "tasks": [
 T("linux-goblincakes-1", 1, "Rätt kommando", "Skriv ett skript med en funktion per fråga som skriver ut rätt kommando:\nuppdatera → goblin update\nloggar → journalctl --user -b\nAnropa uppdatera och sedan loggar.",
   'uppdatera() { echo "goblin update"; }\nloggar() { echo "journalctl --user -b"; }\nuppdatera\nloggar', {"expect": "goblin update\njournalctl --user -b"},
   ["Tabellen i lektionen har svaren.", 'uppdatera() { echo "goblin update"; }'],
   "uppdatera() { echo \"\"; }\nloggar() { echo \"\"; }\nuppdatera\nloggar\n"),
]})
write_track("bash", M)

G = []
def git_files():
    return {}
G.append({"id": "git-forsta", "title": "Git: spara versioner", "requires": ["bash-kommandon"],
 "summary": "`git init`, `git add fil`/`git add -A`, `git commit -m \"text\"`, `git log --oneline`; namn och e-post med `git config`.",
 "lesson_md": """
# Git: spara versioner

**Git** sparar versioner av dina filer – du kan alltid se vad som ändrats och gå tillbaka.

```bash
git init                         # gör mappen till ett Git-förråd
git config user.name "Kaytho"    # vem du är (en gång)
git config user.email "kaytho@example.com"
git add main.lua                 # välj vad som ska med i nästa version
git commit -m "Första versionen" # spara versionen med en beskrivning
git log --oneline                # visa versionerna
```

Tänk: **add** = lägg i påsen, **commit** = försegla påsen med en lapp. Skriv meddelanden som
säger *varför*: "Lägg till /hej-kommandot", inte "ändringar".

Här i lärläget: lägg till `-q` (tyst) på `init` och `commit` så att utskriften blir ren.
""", "tasks": [
 T("git-forsta-1", 1, "Två versioner", "Skapa ett förråd (git init -q), sätt namn och e-post, gör två commits (skapa fil.txt, commit; ändra den, commit) och skriv sedan ut antalet commits med git log --oneline | wc -l.",
   'git init -q\ngit config user.name "Kaytho"\ngit config user.email "kaytho@example.com"\necho "v1" > fil.txt\ngit add fil.txt\ngit commit -q -m "Första versionen"\necho "v2" > fil.txt\ngit add fil.txt\ngit commit -q -m "Andra versionen"\ngit log --oneline | wc -l',
   {"expect": "2"}, ["Glöm inte git config user.name och user.email.", "add + commit två gånger, sedan git log --oneline | wc -l"]),
]})
G.append({"id": "git-status", "title": "Git: vad har ändrats?", "requires": ["git-forsta"],
 "summary": "`git status` (`--short`: `M` ändrad, `??` ny), `git diff` visar raderna, `.gitignore` för filer som inte ska med.",
 "lesson_md": """
# Git: vad har ändrats?

```bash
git status            # vilka filer är ändrade, nya, tillagda?
git status --short    # kort:  M = ändrad,  ?? = ny (inte med i Git än)
git diff              # exakt vilka rader som ändrats (- borta, + nya)
```

Filer som **aldrig** ska med (lösenord, stora filer, byggresultat) skriver man i `.gitignore`:

```
*.log
hemligt.txt
```

Kolla alltid `git status` innan du gör commit – då kommer inget hemligt med av misstag.
""", "tasks": [
 T("git-status-1", 2, "Ignorera hemligheter", "I ett nytt förråd: skapa main.lua och hemligt.txt, lägg hemligt.txt i .gitignore och skriv ut git status --short (main.lua och .gitignore ska synas som nya, inte hemligt.txt).",
   'git init -q\necho "print(1)" > main.lua\necho "lösen" > hemligt.txt\necho "hemligt.txt" > .gitignore\ngit status --short',
   {"expect": "?? .gitignore\n?? main.lua"}, ['echo "hemligt.txt" > .gitignore', "git status --short visar ?? för nya filer."]),
]})
G.append({"id": "git-grenar", "title": "Git: grenar", "requires": ["git-status"],
 "summary": "`git switch -c ny-gren`, `git switch main`, `git merge gren`, `git branch` – prova saker utan att röra det som fungerar.",
 "lesson_md": """
# Git: grenar

En **gren** är en egen linje av versioner – prova något nytt utan att röra det som fungerar:

```bash
git switch -c ny-funktion    # skapa och gå till grenen
# … ändra, add, commit …
git switch main              # tillbaka – ändringarna finns kvar i grenen
git merge ny-funktion        # ta in grenen i main när den är klar
git branch                   # visa grenarna
```

`git init -b main` gör att huvudgrenen heter `main` från början.
""", "tasks": [
 T("git-grenar-1", 2, "Prova i en gren", "I ett förråd (git init -q -b main, med namn/e-post och en första commit av fil.txt med texten bas): skapa grenen test, ändra fil.txt till nytt och gör commit, gå tillbaka till main och skriv ut fil.txt (bas), slå sedan ihop test och skriv ut fil.txt igen (nytt).",
   'git init -q -b main\ngit config user.name "Kaytho"\ngit config user.email "k@example.com"\necho "bas" > fil.txt\ngit add fil.txt\ngit commit -q -m "Bas"\ngit switch -q -c test\necho "nytt" > fil.txt\ngit commit -q -am "Nytt"\ngit switch -q main\ncat fil.txt\ngit merge -q test\ncat fil.txt',
   {"expect": "bas\nnytt"}, ["git switch -c test skapar grenen.", "git commit -am sparar ändrade filer direkt; -q gör utskriften tyst."]),
]})
G.append({"id": "git-angra", "title": "Git: ångra", "requires": ["git-grenar"],
 "summary": "`git restore fil` (släng ändringar), `git restore --staged fil` (ta ur add), `git revert <commit>` (ny commit som tar bort en gammal), `git log` för att hitta den.",
 "lesson_md": """
# Git: ångra

| Vill du … | Kommando |
|---|---|
| slänga ändringar i en fil sedan senaste commit | `git restore fil` |
| ta bort en fil från nästa commit (efter add) | `git restore --staged fil` |
| ångra en gammal commit (säkert, även efter push) | `git revert <id>` |
| se gamla versioner | `git log --oneline`, `git show <id>` |

`revert` gör en **ny** commit som tar bort ändringen – historiken finns kvar, så inget försvinner.
Det finns farligare kommandon (`reset --hard`) – använd dem inte förrän du vet exakt vad de gör.
""", "tasks": [
 T("git-angra-1", 2, "Släng en ändring", "I ett förråd med fil.txt = bra (commitad): skriv dåligt till fil.txt, ångra med git restore och skriv ut filen.",
   'git init -q\ngit config user.name "Kaytho"\ngit config user.email "k@example.com"\necho "bra" > fil.txt\ngit add fil.txt\ngit commit -q -m "Bra"\necho "dåligt" > fil.txt\ngit restore fil.txt\ncat fil.txt',
   {"expect": "bra"}, ["git restore fil.txt tar tillbaka senaste commit.", "Gör först en commit med texten bra."]),
]})
G.append({"id": "git-github", "title": "Git: GitHub", "requires": ["git-angra"],
 "summary": "`git remote add origin <url>`, `git push -u origin main`, `git pull`, `git clone <url>`; logga in med `gh auth login`.",
 "lesson_md": """
# Git: GitHub

GitHub är ett ställe på nätet där förråd kan ligga – som backup och för att samarbeta.

```bash
git remote add origin https://github.com/dittnamn/mitt-tillagg.git
git push -u origin main      # skicka upp (första gången med -u)
git pull                     # hämta det som ändrats där
git clone <url>              # hämta ett helt förråd
```

I GOBLINCAKES finns `gh` (GitHub CLI): `gh auth login` loggar in en gång, `gh repo create`
skapar ett förråd. Lägg **aldrig** lösenord eller nycklar i ett publikt förråd.

(Övningsdatorn har inget nät – här provar du kopplingen, uppladdningen gör du på riktigt.)
""", "tasks": [
 T("git-github-1", 1, "Koppla till GitHub", "I ett nytt förråd: lägg till fjärrförrådet origin med adressen https://github.com/kaytho/mitt-tillagg.git och skriv ut git remote.",
   'git init -q\ngit remote add origin https://github.com/kaytho/mitt-tillagg.git\ngit remote', {"expect": "origin"},
   ["git remote add origin <adress>", "git remote visar namnen."]),
]})
write_track("git", G)
