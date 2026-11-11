# Levande utseende steg 7 (toppfältet och dockan) – efter nästa image, gäller upplägget Toppfält och docka
- Temat finns i imagen
  kör: ls /usr/share/plasma/desktoptheme/goblincakes-levande/metadata.json && grep -c 'fill-opacity="0.62"' /usr/share/plasma/desktoptheme/goblincakes-levande/solid/widgets/panel-background.svg
  väntat: filen finns och 1 (annars är imagen för gammal – goblin update och starta om)
- Temat nu
  kör: kreadconfig6 --file plasmarc --group Theme --key name; cat ~/.config/goblincakes/utseende 2>/dev/null || echo platt
  väntat: goblincakes med platt, goblincakes-levande med levande (tomt = goblincakes)
- Byta till Levande
  fråga: Välj Levande i Config → INSTÄLLNINGAR → Stil. Blir toppfältet halvgenomskinligt (bakgrundsbilden skymtar igenom) inom några sekunder? Ser popupfönstren (AppGrid, kalendern, systemfältets rutor) ut som förut?
- Dockan
  fråga: För musen över dockans program. Kommer en svag glöd i din färg bakom ikonen du är över (vågen ska fungera som förut)? Syns ett svagt ljus i dockans överkant?
- Toppfältets widgetar
  fråga: Byt låt i Spotify/GoblinAmp – tonar låten i toppfältet in? För musen över kvotstaplarna och uppdateringsikonen – glöder de lite? Glider kvotstaplarna när kvoten uppdateras?
- Under spel
  fråga: Starta ett spel och byt låt medan det kör – byts texten direkt (ingen toning)? Glöden vid hovring får finnas kvar.
- Tillbaka till Platt
  fråga: Välj Platt. Blir toppfältet mörkt och helt igen, och försvinner dockans ljus och glöd?
- Efter inloggning
  fråga: Logga ut och in med Levande valt. Är toppfältet fortfarande glas?
