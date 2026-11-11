# Levande utseende steg 2 (övergångar) – efter nästa image
- Övergångarna finns i imagen
  kör: grep -c "moving" /usr/share/goblincakes/qml/Goblin/FlatButton.qml
  väntat: 4 eller fler (0 eller filen saknas = imagen är för gammal – goblin update och starta om)
- Välj Levande
  fråga: Öppna GOBLINCAKES Config → INSTÄLLNINGAR → Stil och tryck Levande. Står det under rutan vad Levande gör hittills (knappar, kryssrutor, reglage och fält tonar)?
- Läget just nu
  kör: python3 -c "import sys; sys.path.insert(0,'/usr/share/goblincakes'); import accent; print(accent.look())"
  väntat: 'living': True, 'gaming': False, 'motion': True (motion False utan spel = Plasmas animationer är avstängda)
- Hur det känns
  fråga: För musen fram och tillbaka över knapparna längst ner i Config och slå av och på ett reglage. Tonar färgen mjukt, trycks knappen ner lite när du håller musknappen nere, och ritas bocken fram när du kryssar i något (t.ex. Skrivbordets upplägg)? Känns tempot lagom, för långsamt eller för snabbt?
- Andra fönster
  fråga: Öppna Goblin AI och GoblinRecorder – tonar knapparna där också (utan att du startat om dem efter bytet till Levande)?
- Under spel
  fråga: Starta ett spel (t.ex. WoW) och titta på Config medan spelet kör (inom en halv minut efter starten): tonar knapparna inte längre (direkt byte som i Platt)? Stäng spelet – tonar de igen?
- Spelläget i valet
  kör: python3 -c "import sys; sys.path.insert(0,'/usr/share/goblincakes'); import accent; print(accent.look())"
  väntat: medan spelet kör 'gaming': True, 'motion': False
- Tillbaka till Platt
  fråga: Välj Platt i Config → Stil. Byter allt färg direkt igen, utan tonande och utan att knappar trycks ner?
