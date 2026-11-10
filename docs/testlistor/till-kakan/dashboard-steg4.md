# GOBLINCAKES Dashboard steg 4 (skrivbordsraden och Meta) – efter nästa image
- Delarna finns i imagen
  kör: test -x /usr/libexec/goblincakes-desktop-layout && test -f /usr/share/plasma/plasmoids/org.goblincakes.deskclock/metadata.json && test -f /usr/share/dbus-1/services/org.goblincakes.dashboard.service && echo finns
  väntat: finns (annars är imagen för gammal – goblin update och starta om)
- Vilket upplägg som gäller
  kör: /usr/libexec/goblincakes-desktop-layout status
  väntat: classic (standard) – eller dashboard om du redan bytt
- Byta till dashboarden
  fråga: Öppna GOBLINCAKES Config → INSTÄLLNINGAR → Skrivbordets upplägg och tryck Dashboard. Försvann toppfältet och dockan, och kom en rad upp i mitten av överkanten med Discord, klockan (datum och vecka under), nätverk, ljud och Spelas nu – i egna rutor, utan bakgrund mellan rutorna?
- Meta
  fråga: Tryck Meta (bara Meta). Kommer dashboarden upp i helskärm på huvudskärmen? Tryck Meta igen – försvinner den? Prova också med musen på den andra skärmen – den ska ändå komma på huvudskärmen.
- Meta i kortkommandona
  kör: grep -A2 '^\[goblin-dashboard\]' ~/.config/kglobalshortcutsrc; grep 'activate application launcher' ~/.config/kglobalshortcutsrc
  väntat: under [goblin-dashboard] en rad toggle=Meta,…; startmenyns rad har bara Alt+F1 först (inte Meta)
- Storleken på raden
  fråga: Är raden uppe i mitten lagom stor nu (klockan och rutorna mindre än första gången)? Säg annars om den ska vara ännu mindre eller lite större.
- Raden göms av fönster
  fråga: Öppna ett fönster och maximera det. Gömmer sig raden, och kommer den fram när du för musen mot överkanten mitt på skärmen? Syns den igen när skrivbordet är tomt?
- Klockrutan
  fråga: Tryck på klockan – öppnas kalendern med veckonummer och röda dagar? Rulla hjulet över ljudikonen – ändras ljudet och visas procenten en kort stund? Mittenklick = tyst? Visar musens/headsetets batteri rätt sida (mus till vänster, headset till höger)?
- Discord och Spelas nu
  fråga: Gå in i en röstkanal i Discord. Står servern och kanalen i Discord-rutan? Spela musik – står låten i Spelas nu-rutan, pausar ett klick, byter hjulet låt?
- Steam och Kakan
  fråga: Låt Steam ladda ner något eller ställ en fråga till Kakan. Kommer en Steam-ruta längst till vänster / en KAKAN ARBETAR-ruta längst till höger, och försvinner den när det är klart?
- Notiser och systemfältsikoner
  fråga: Systemfältet ligger gömt uppe till höger. För musen mot överkanten längst till höger – kommer det fram, och finns Discords/Steams ikoner där (eller bakom pilen)? Kommer notiser fram som vanligt?
- Byta tillbaka
  fråga: Tryck Toppfält och docka i Config. Kom toppfältet och dockan tillbaka med dina fästa program och samma dockstorlek, och öppnar Meta AppGrid igen?
- GOBLINCAKES egna program
  fråga: Öppna dashboarden. Ligger GOBLINCAKES egna program (bara Config, Goblin AI, GoblinRecorder, GoblinAmp och GoblinShare) med små ikoner ovanför programraden längst ner, i både SPEL och JOBB, och startar ett klick programmet?
- Dockans program i upplägget Dashboard
  fråga: Med upplägget Dashboard valt: visar programraden längst ner samma program som du hade fästa i dockan?
- Dockan och dashboarden delar program
  fråga: Lägg till ett program under APPARNA LÄNGST NER i Config → DASHBOARD. Kom det in i dockan också? Fäst sedan ett annat program i dockan – syns det längst ner i dashboarden nästa gång du öppnar den?
