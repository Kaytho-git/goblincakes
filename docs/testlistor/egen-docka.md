# Egen docka (widgeten org.goblincakes.dock) – efter nästa image
- Widgeten finns i imagen
  kör: ls /usr/share/plasma/plasmoids/org.goblincakes.dock/contents/ui/main.qml
  väntat: filen finns
- Lägg till widgeten
  fråga: Högerklicka på skrivbordet → Lägg till eller hantera paneler → Lägg till panel → Tom panel, flytta den till nederkanten, högerklicka → Lägg till widgetar → sök "GOBLINCAKES Docka" och dra in den. Syns Ghostty och Firefox?
- Fel i loggen
  kör: journalctl --user -b -o cat _COMM=plasmashell | grep -i "goblincakes.dock" | tail -20
  väntat: inga rader med "Error" eller "TypeError"
- Öppen-markering
  fråga: Öppna Firefox. Får Firefox en liten fyrkant i accentfärgen under ikonen, och en bredare när Firefox är det aktiva fönstret?
- Vågen
  fråga: Dra musen sakta längs dockan. Växer ikonen under musen mest och grannarna lite mindre, mjukt som på macOS? Sjunker de tillbaka när musen lämnar?
- Klick
  fråga: Klicka på Firefox när det är aktivt – minimeras det? Klicka igen – kommer det tillbaka? Klicka på Ghostty när det är stängt – startar det?
- Fästa och flytta
  fråga: Dra ett program från AppGrid till dockan – fästs det där du släppte? Dra en ikon i dockan till en ny plats – stannar den där?
- Högerklick
  fråga: Högerklicka på en ikon – finns Nytt fönster, Stäng och Lossa från dockan, och fungerar Lossa?
- Storlek
  fråga: Redigera panelen och dra i dess kant så den blir högre/lägre (prova runt 70 px). Följer ikonerna med, och håller de sig inom ramen även när de växer?
- Välj stil
  fråga: Högerklicka på dockan → Konfigurera → Ramen: prova "Växer med vågen" och "Står still (luftig)". Vilken gillar du? (Den andra tas bort.)
- Program som inte är fästa
  fråga: Öppna ett program som inte är fäst (t.ex. Inställningar). Syns det INTE i den nya dockan?
