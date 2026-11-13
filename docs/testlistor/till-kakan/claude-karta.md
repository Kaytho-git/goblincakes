# CLAUDE CODE-kartan – efter nästa image (dashboarden och Goblin AI)
- Filerna finns i imagen
  kör: ls /usr/share/goblincakes/claudemap.py /usr/share/goblincakes/claudefeed.py /usr/share/goblincakes/qml/Goblin/ClaudeMap.qml
  väntat: alla tre finns (saknas de är imagen för gammal – goblin update och starta om)
- Läsaren hittar Claude Codes logg
  kör: python3 /usr/share/goblincakes/claudemap.py | head -12
  väntat: JSON med "session", "folder" och "model" (t.ex. "opus 5.5"); {"none": true} betyder att Claude Code aldrig körts på datorn – då OKLART, inte FEL
- Kartan i Goblin AI
  fråga: Öppna TERMINAL i Goblin AI och starta Claude Code i ett projekt (claude). Syns kartan till höger med CLAUDE i mitten och projektets namn och modellen ovanför raderna? Lyser stationerna (FILER, SKAL …) när Claude jobbar?
- Knappen KARTA
  fråga: Tryck KARTA i flikraden. Försvinner kartan och får terminalen hela bredden? Tryck igen – kommer den tillbaka? Stäng och öppna Goblin AI – är valet kvar?
- Terminalen hackar inte
  fråga: Låt Claude jobba en stund med kartan synlig. Skriver terminalen lika jämnt som förut (inget hack när kartan ritas)?
- Rätt session med två flikar
  fråga: Öppna en andra TERMINAL-flik och starta Claude Code i ett annat projekt. Byt mellan flikarna – byter kartan till fliken som visas inom ett par sekunder? Syns två knappar ovanför kartan?
- Dashboarden
  fråga: Öppna dashboarden och byt till vyn JOBB. Finns ramen CLAUDE CODE till vänster med projektet och vad som körs? Tryck på den – kommer kartan i mitten med raderna till höger?
- Fel och svar
  fråga: Be Claude köra ett kommando som misslyckas (t.ex. "kör ls /finnsinte"). Blir det en röd prick på SKAL och ett ✕ i raderna? Försvinner pricken när du skriver nästa meddelande?
- Levande och Platt
  fråga: Med Stil: Levande – flyger små prickar ut till stationerna och tillbaka, och går en ring ut från mitten när svaret är klart? Välj Platt i Config – lyser stationerna bara upp, utan prickar som flyger?
