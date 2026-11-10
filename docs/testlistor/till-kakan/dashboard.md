# GOBLINCAKES Dashboard steg 1 – efter nästa image
- Programmet finns i imagen
  kör: test -x /usr/bin/goblin-dashboard && test -f /usr/share/goblincakes/dashboard/Main.qml && echo finns
  väntat: finns (annars är imagen för gammal – goblin update och starta om)
- Systemets siffror
  kör: python3 /usr/share/goblincakes/dashboard/dash.py system
  väntat: JSON med raderna cpu, gpu, temp, ram och disk (saknas gpu eller temp = skriv det i rapporten med grafikkortets namn)
- Programmen nederst
  kör: python3 /usr/share/goblincakes/dashboard/dash.py bottom
  väntat: en lista med samma program som är fästa i dockan
- Musiken
  kör: python3 /usr/share/goblincakes/dashboard/dash.py player
  väntat: med musik igång: title, artist, length större än 0 och art (omslagets adress); utan musik: {}
- Nätverk och ljud
  kör: python3 /usr/share/goblincakes/dashboard/dash.py tray nätverk; python3 /usr/share/goblincakes/dashboard/dash.py tray ljud
  väntat: en rad med Ethernet "ansluten", och ljudet med "volume" (percent och name)
- Urklipp
  kör: python3 /usr/share/goblincakes/dashboard/dash.py tray urklipp
  väntat: de senast kopierade texterna (inte "Urklippet är tomt" om något har kopierats)
- Kvoten
  kör: python3 /usr/share/goblincakes/dashboard/dash.py quota
  väntat: services med claude och dess windows (5 h och Vecka)
- Fönstret öppnas
  fråga: Skriv goblin dashboard i en terminal. Fyller dashboarden hela skärmen (inget toppfält eller docka syns), och på vilken skärm hamnade den?
- Öppna program
  fråga: Syns dina öppna program överst med rätt namn och ikon? Tryck på ett av dem – kom det fönstret fram och försvann dashboarden?
- Sök och starta
  fråga: Öppna dashboarden igen och skriv "fire". Visas Firefox först, och startar den med Enter?
- Ikonerna
  fråga: Har programmen i mitten och nederst sina riktiga ikoner (inte bara en bokstav)?
- Göms av sig själv
  fråga: Öppna dashboarden och tryck Alt+Tab till ett annat fönster. Försvann dashboarden? Kom den tillbaka direkt med goblin dashboard?
- System i mitten
  fråga: Tryck på rutan SYSTEM. Visas kort för processor, grafikkort, temperatur, minne och disk med staplar som växer, och en lista över vad som tar mest processor?
- Projekt
  fråga: Tryck + Lägg till projekt och välj mappen goblincakes. Syntes mappväljaren ovanpå dashboarden, och visas sedan de senaste commitsen? Fungerar VS Code och Claude Code under ÖPPNA?
- Spelas nu
  fråga: Spela en låt i Spotify eller GoblinAmp. Visas titel, artist och omslag nere till höger, går tiden, och fungerar föregående/paus/nästa?
- Ljudrutan
  fråga: Tryck på högtalarikonen under loggan. Ändras volymen när du trycker i stapeln, och fungerar Tyst?
- Esc
  fråga: Stänger Esc ett steg i taget (lilla rutan, sökningen, tillbaka till alla program, och sist hela dashboarden)?
