# Levande utseende steg 5 (dashboarden) – efter nästa image
- Delarna finns i imagen
  kör: ls /usr/share/goblincakes/qml/Goblin/Rise.qml /usr/share/goblincakes/qml/Goblin/LiveTag.qml && grep -c iconColor /usr/bin/goblin-dashboard
  väntat: båda filerna och en siffra 1 eller mer (annars är imagen för gammal – goblin update och starta om)
- Stil Levande
  kör: cat ~/.config/goblincakes/utseende
  väntat: levande (annars: välj Levande i Config → INSTÄLLNINGAR → Stil först)
- Öppningen
  fråga: Öppna och stäng dashboarden några gånger (Meta i upplägget Dashboard, annars goblin dashboard två gånger). Glider ramarna fram en i taget nedifrån – vänster först, sedan mitten och höger – och är allt på plats på under en halv sekund? Känns det trevligt eller i vägen?
- Programmen lyfter
  fråga: För musen över programmen längst ner och i Alla program. Lyfter ikonen lite och glöder den i programmets egen färg (t.ex. Steam blå, Firefox orange, Discord lila)? Stämmer färgerna ungefär?
- PÅGÅR
  fråga: Under eller strax efter en raid (inom en halvtimme efter sista pullen): står det ● PÅGÅR på kortet Senaste raiden i dashboarden, och pulserar pricken långsamt?
- Bygget
  fråga: Medan ett GOBLINCAKES-bygge kör (JOBB-vyn, ramen BYGGEN): står det ● PÅGÅR där?
- Platt är som förut
  fråga: Välj Platt igen. Kommer dashboarden fram direkt utan glidning, och lyfter/glöder programmen inte? Står PÅGÅR fortfarande kvar (utan puls) när något pågår?
