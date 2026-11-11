# Levande utseende steg 6 (skrivbordsraden mindre + tonat glas) – efter nästa image, gäller upplägget Dashboard
- Ändringen finns i imagen
  kör: grep -c "glass" /usr/share/plasma/plasmoids/org.goblincakes.deskclock/contents/ui/ClockBox.qml
  väntat: 3 eller fler (0 = imagen är för gammal – goblin update och starta om)
- Upplägget
  kör: /usr/libexec/goblincakes-desktop-layout status
  väntat: dashboard (classic = raden finns inte – byt i Config → INSTÄLLNINGAR → Skrivbordets upplägg för att prova, och tillbaka efteråt)
- Radens höjd
  kör: grep -B2 -A8 'org.goblincakes.deskclock' ~/.config/plasma-org.kde.plasma.desktop-appletsrc | head -3; /usr/libexec/goblincakes-desktop-layout login; echo klart
  väntat: klart (login rättar radens höjd till 52)
- Storleken
  fråga: För musen mot överkanten mitt på skärmen. Är raden (klockrutan, Discord och Spelas nu) ungefär 20 % mindre än förut och går texten fortfarande att läsa? Är den lagom nu, eller ska den vara ännu mindre/lite större?
- Glaset med Levande
  fråga: Välj Levande i Config → INSTÄLLNINGAR → Stil och vänta 5 sekunder. Blir rutorna i raden halvgenomskinliga (bakgrundsbilden skymtar igenom) utan ram, med en tunn ljus linje överst? Går texten att läsa mot din bakgrundsbild?
- Platt
  fråga: Välj Platt igen och vänta 5 sekunder. Får rutorna tillbaka sin mörka bakgrund med ram (men i den mindre storleken)?
