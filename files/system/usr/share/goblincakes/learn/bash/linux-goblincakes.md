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
