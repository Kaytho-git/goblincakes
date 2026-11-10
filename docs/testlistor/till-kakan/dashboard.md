# GOBLINCAKES Dashboard steg 1–3 – efter nästa image
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
- WoW-siffrorna
  kör: python3 /usr/share/goblincakes/dashboard/stats.py wow-fetch
  väntat: players med dina karaktärer (class, spec, ilvl) och raid med bosses; minst en wipe har pct som är ett tal (inte null) – null på alla = Warcraft Logs svarade inte, skriv det i rapporten
- CS2-siffrorna
  kör: python3 /usr/share/goblincakes/dashboard/stats.py cs2
  väntat: count, wins, losses och maps – samma matcher som CS2 Stats i GoblinRecorder (inte de privata)
- Byggena
  kör: python3 /usr/share/goblincakes/dashboard/stats.py builds
  väntat: builder true och rows med de senaste byggena (state, hash, title, when)
- Rapporterna
  kör: python3 /usr/share/goblincakes/dashboard/stats.py reports
  väntat: rows med dina senaste rapporter till Claude, rubriken som title
- Vyerna
  kör: python3 /usr/share/goblincakes/dashboard/dash.py views
  väntat: views med SPEL (left projects, system; right wow, cs2) och JOBB (right builds, reports) – eller de vyer du själv valt i Config
- Ramarna till höger
  fråga: Öppna dashboarden. Syns WOW STATS och CS2 STATS till höger ovanför Spelas nu i vyn SPEL, och BYGGEN och KAKAN i vyn JOBB?
- Byta vy
  fråga: Byt vy med hjulet över prickarna under mitten, med Ctrl+← → och (om du har pekplatta) ett svep i sidled. Byts vyn ett steg i taget, och står mitten kvar där du lämnade den när du kommer tillbaka till en vy?
- Anpassa
  fråga: Tryck Anpassa uppe till höger. Öppnades GOBLINCAKES Config på sidan DASHBOARD och försvann dashboarden? Har programmen i listan under + Lägg till app sina ikoner?
- Ändra en vy
  fråga: Byt namn på JOBB i Config, välj Ingen i höger ram 2 och lägg till ett program längst ner. Visar dashboarden det nya namnet, bara en ram till höger och programmet nederst nästa gång du öppnar den?
- Senaste raiden
  fråga: Tryck på Senaste raiden. Stämmer bossarna, antal pulls, kill/bästa wipe och din parse med Warcraft Logs? Visar staplarna bossens hälsa per pull när du trycker på en boss?
- Karaktären
  fråga: Tryck på en karaktär. Stämmer klassfärgen, item level och rutorna med WoW Stats i GoblinRecorder?
- CS2 i mitten
  fråga: Tryck på CS2 STATS. Stämmer vinster/förluster och siffrorna per karta med CS2 Stats i GoblinRecorder?
- Fråga Kakan
  fråga: Tryck Fråga Kakan om bossen i Senaste raiden. Öppnades Goblin AI med frågan i en ny chatt, och försvann dashboarden?
- Byggen i mitten
  fråga: Tryck på BYGGEN. Visas listan, och öppnar ett tryck på en rad bygget på GitHub i webbläsaren?
