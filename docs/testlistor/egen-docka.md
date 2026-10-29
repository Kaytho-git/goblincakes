# Egen docka (widgeten org.goblincakes.dock)

Så här provar du (rader utan "- " först läses inte av /testa):
  1. I Claude Code på datorn, skriv: "Gör steg 1–3 i docs/testlistor/egen-docka.md".
     Claude kör då (i repomappen):
       git pull
       mkdir -p ~/.local/share/plasma/plasmoids ~/.local/share/goblincakes/testlistor
       cp -r files/system/usr/share/plasma/plasmoids/org.goblincakes.dock ~/.local/share/plasma/plasmoids/
       cp docs/testlistor/egen-docka.md ~/.local/share/goblincakes/testlistor/
  2. Starta om skrivbordet (fönstren stängs inte):  systemctl --user restart plasma-plasmashell
  3. Ingen ny image behövs – kopian i hemmappen används direkt.
  4. Öppna Goblin AI och skriv /testa egen-docka. Kakan går igenom punkterna nedan och frågar dig.
  5. Efteråt: ta bort kopian när widgeten finns i imagen, annars används den gamla kopian i stället:
       rm -r ~/.local/share/plasma/plasmoids/org.goblincakes.dock
     Den nya dockan ligger kvar bredvid den gamla tills vi byter – högerklick → Ta bort tar bort den.

- Widgeten finns (kopian i hemmappen eller i imagen)
  kör: ls ~/.local/share/plasma/plasmoids/org.goblincakes.dock/contents/ui/main.qml /usr/share/plasma/plasmoids/org.goblincakes.dock/contents/ui/main.qml 2>&1
  väntat: minst en av filerna finns
- Lägg till widgeten
  fråga: Ta fram dockan (Meta+Z), högerklicka på den → Lägg till widgetar → sök "GOBLINCAKES Docka" och dra in den bredvid de gamla ikonerna. Högerklicka på dockan → Redigera panel och dra panelens höjd till ungefär 70 px. Syns Ghostty och Firefox i en ram i accentfärgen?
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
