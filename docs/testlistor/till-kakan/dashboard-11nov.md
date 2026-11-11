# GOBLINCAKES Dashboard – ändringarna 11 nov (ström, projekt, kvot, ramarna) – efter nästa image
- Ändringarna finns i imagen
  kör: grep -c "def browse\|def power" /usr/share/goblincakes/dashboard/dash.py
  väntat: 2 (annars är imagen för gammal – goblin update och starta om)
- Avstängningsruta via D-Bus
  kör: busctl --user introspect org.kde.LogoutPrompt /LogoutPrompt | grep -c promptAll
  väntat: 1 (finns inte → strömknappen kan inte öppna avstängningsrutan)
- Strömknappen
  fråga: Öppna dashboarden. Längst till höger i ikonraden under GOBLINCAKES-loggan finns en strömknapp. Tryck på den – försvinner dashboarden och kommer avstängningsrutan ("Goodbye! See you next raid!") med Logga ut, Starta om, Stäng av och Avbryt? Tryck Avbryt.
- Kvoten som ikon
  fråga: Bredvid strömknappen finns en mätarikon för kvoten (röd om något är på 90 % eller mer). Tryck på den – kommer en liten ruta med kvoten (5 tim, vecka och när den nollställs)? Stänger ✕ eller Esc den? Är kvotramen nere till vänster borta?
- Lägga till ett projekt
  fråga: Tryck på det lilla + bredvid PROJEKT. Kommer LÄGG TILL PROJEKT i mitten med din hemmapp och Git-mappar som förslag? Gå in i en mapp, tryck "Lägg till den här mappen" – syns den i PROJEKT och öppnas den i mitten?
- Samma lista i Goblin AI
  kör: cat ~/.config/goblincakes/ai-mappar.json
  väntat: mappen du nyss lade till finns med
- Ta bort ett projekt
  fråga: För musen över ett projekt i PROJEKT – kommer ett ✕ till höger? Tryck på det – försvinner projektet ur listan (mappen ska finnas kvar på disken)?
- System utan disk
  fråga: Visar SYSTEM-ramen bara CPU, grafikkort, temperatur och minne (ingen DISK)? Tryck på SYSTEM – finns DISK – LEDIGT i mitten?
- Rulla bara i projektramen
  fråga: Med många projekt: rullar hjulet bara listan i PROJEKT medan SYSTEM står still under, utan att hela vänsterspalten rullar?
