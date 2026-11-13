# Barnläget (efter nästa image, 13 nov)
- Barnläget finns i imagen
  kör: ls -l /usr/bin/goblin-kids /usr/share/goblincakes/kids/kids.py /usr/share/applications/goblin-kids.desktop /etc/xdg/autostart/goblincakes-kids-restore.desktop
  väntat: alla fyra filerna finns
- Inget barnläge är fast på efter inloggningen
  kör: cat ~/.local/state/goblincakes/kids-active.json 2>/dev/null || echo "ingen statusfil"; kreadconfig6 --file kwinrulesrc --group General --key rules
  väntat: "ingen statusfil", och listan med regler innehåller inte goblincakes-kids
- Config-fliken
  fråga: Öppna GOBLINCAKES Config → BARNLÄGE. Lägg till Bluey och Tux Paint med + Lägg till, och spara en PIN-kod. Syns Blueys omslag, och står det "Steam-spel" (inte "Steam-överlägget är PÅ") under Bluey? Om det står PÅ: stäng Steam och tryck "Stäng av överlägget" – försvinner det?
- Splashen
  fråga: Tryck Starta barnläget. Kommer stjärnsplashen med ljud (stjärnor, gnistor som snurrar in, ett ljussken, en planet som Saturnus som kommer inifrån rymden) och sedan två stora bilder? Hackar den?
- Bara en skärm
  fråga: Är den andra skärmen täckt av en lugn natthimmel, och är dina egna fönster borta?
- Kortkommandona är spärrade
  fråga: Tryck Meta, Alt+Tab, Alt+F4 och Ctrl+Alt+Del i barnläget (och en gång medan Bluey är igång). Händer det ingenting?
- Namnen med Coris röst
  fråga: Står det under varje spel i Config → BARNLÄGE vad Cori säger (t.ex. "Bluey"), och spelar ▶ upp det? Ändra texten för ett spel – kommer ett nytt ljud? Syns "Chatterbox" eller "Piper" i texten över korten?
- Namnet när musen vilar på spelet
  fråga: Håll musen still över Bluey i barnläget en halv sekund. Säger Cori "Bluey"? Dra musen snabbt över spelen – blir det tyst (ska inte prata hela tiden)?
- Bluey
  fråga: Klicka på Bluey. Startar spelet på huvudskärmen utan att Steams fönster syns? Kommer Steam-överlägget med Shift+Tab? (Det ska inte komma.) Avsluta spelet från dess meny – kommer barnläget tillbaka?
- Tux Paint
  fråga: Klicka på Tux Paint. Startar det i helskärm? Rita något och spara, avsluta med Tux Paints egen Avsluta-knapp – kommer spelbilderna tillbaka? Finns teckningen i bildknappen uppe till vänster efter att du gått ut och in i barnläget?
- Bakgrunden
  fråga: Byt bakgrund med bildknappen uppe till vänster. Byts den, och är samma bakgrund kvar nästa gång barnläget startar?
- Strömknappen och notiserna
  fråga: Tryck kort på datorns strömknapp i barnläget. Händer ingenting? (Skicka gärna ett Discord-meddelande till dig själv – syns ingen notis?)
- Volymtaket
  fråga: Höj volymen till max i barnläget. Stannar den på 60 % (eller det du valt i Config)?
- Avsluta med PIN-koden
  fråga: Klicka på X uppe till höger, skriv fel kod en gång (skakar rutan?) och sedan rätt. Kommer dina fönster, den andra skärmen, Meta och strömknappen tillbaka som förut?
- Allt är återställt efteråt
  kör: cat ~/.local/state/goblincakes/kids-active.json 2>/dev/null || echo "ingen statusfil"; kreadconfig6 --file kwinrulesrc --group General --key rules; grep -c goblincakes-barnläge ~/.config/MangoHud/MangoHud.conf 2>/dev/null || echo "0 eller ingen MangoHud-fil"
  väntat: "ingen statusfil", ingen goblincakes-kids i reglerna, och 0 (eller ingen MangoHud-fil)
