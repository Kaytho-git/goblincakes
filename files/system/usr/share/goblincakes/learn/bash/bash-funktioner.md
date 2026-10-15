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
