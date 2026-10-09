#!/usr/bin/bash
# GOBLINCAKES live ISO: the window shown after login – install, partition disks, or try first.
# Opened again from the dock (Installera GOBLINCAKES / Partitionshanterare) whenever needed.
sleep 4
yad --title="GOBLINCAKES" --window-icon=goblincakes --image=goblincakes \
    --on-top --center --no-escape --width=520 --borders=24 \
    --text-align=left --buttons-layout=end \
    --text="<span size='x-large' weight='bold'>Välkommen till GOBLINCAKES</span>

Det här är GOBLINCAKES direkt från USB-minnet. Inget på datorns diskar ändras
förrän du installerar eller formaterar.

<b>Installera GOBLINCAKES</b> – installerar på en disk du väljer.
Har datorn ett Nvidia-kort (RTX 20xx / GTX 16xx eller nyare) hämtas
Nvidia-drivrutinerna automatiskt efter första starten.

<b>Partitionshanteraren</b> – rensa eller formatera diskar först.

<b>Prova först</b> – titta runt. Båda finns i dockan längst ner.

<small>Spel och prestanda är inte som på en installerad dator.</small>" \
    --button="Prova först:0" --button="Partitionshanteraren:20" --button="Installera GOBLINCAKES:10"
case $? in
    10) setsid liveinst >/dev/null 2>&1 & ;;
    20) setsid partitionmanager >/dev/null 2>&1 & ;;
esac
