#!/usr/bin/bash
# GOBLINCAKES live ISO: the window shown after login – install, partition disks, or try first.
# Opened again from the dock (Installera GOBLINCAKES / Partitionshanterare) whenever needed.
# Shows the computer's graphics card and what the installation will do about its drivers
# (the same check the installer uses: goblincakes-gpu hw).
sleep 4

graphics=$(/usr/libexec/goblincakes-gpu hw 2>/dev/null | python3 -c '
import html, json, sys
try:
    hw = json.load(sys.stdin)
except ValueError:
    sys.exit()
cards = hw.get("cards", [])
names = ", ".join(html.escape(c["name"]) for c in cards) or "okänt"
print(f"<b>Grafikkort:</b> {names}")
if hw.get("nvidiaSupported"):
    print("Förslag: <b>Nvidia-drivrutinerna</b> – de hämtas automatiskt efter första starten")
    print("(behöver internet), sedan räcker en omstart.")
elif hw.get("hasNvidia"):
    print("Nvidia-kortet är äldre än GTX 16xx/RTX 20xx, som Nvidias drivrutiner kräver.")
    print("Den öppna drivrutinen används – skrivbordet fungerar, spel går långsammare.")
elif cards:
    print("Drivrutinerna finns redan med i GOBLINCAKES – inget behöver hämtas.")
' 2>/dev/null)

yad --title="GOBLINCAKES" --window-icon=goblincakes --image=goblincakes \
    --on-top --center --no-escape --width=560 --borders=24 \
    --text-align=left --buttons-layout=end \
    --text="<span size='x-large' weight='bold'>Välkommen till GOBLINCAKES</span>

Det här är GOBLINCAKES direkt från USB-minnet. Inget på datorns diskar ändras
förrän du installerar eller formaterar.

${graphics:+$graphics

}<b>Installera GOBLINCAKES</b> – installerar på en disk du väljer.

<b>Partitionshanteraren</b> – rensa eller formatera diskar först.

<b>Prova först</b> – titta runt. Båda finns i dockan längst ner.

<small>Spel och prestanda är inte som på en installerad dator.</small>" \
    --button="Prova först:0" --button="Partitionshanteraren:20" --button="Installera GOBLINCAKES:10"
case $? in
    10) setsid liveinst >/dev/null 2>&1 & ;;
    20) setsid partitionmanager >/dev/null 2>&1 & ;;
esac
