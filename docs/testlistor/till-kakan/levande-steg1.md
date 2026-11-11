# Levande utseende steg 1 (gemensam modul och valet Stil) – efter nästa image
- Modulen finns i imagen
  kör: ls /usr/share/goblincakes/qml/Goblin/
  väntat: CheckSquare.qml FlatButton.qml FlatField.qml FlatScrollBar.qml Frame.qml ToggleSwitch.qml qmldir (annars är imagen för gammal – goblin update och starta om)
- Fönstren hittar modulen
  kör: for w in config ai dashboard recorder share remove lagmeter; do grep -c 'qml/Goblin' /usr/share/goblincakes/$w/Main.qml; done
  väntat: 1 på varje rad
- Stil i Config
  fråga: Öppna GOBLINCAKES Config → INSTÄLLNINGAR. Finns rutan Stil under Färg, med Platt (ikryssad) och Levande? Tryck Levande – kommer texten "Levande byggs i omgångar …"? Tryck Platt igen.
- Valet sparas
  kör: cat ~/.config/goblincakes/utseende
  väntat: platt (efter att du tryckt Platt igen)
- Knapparna ser ut som förut
  fråga: Öppna Config, Goblin AI, GoblinRecorder, GoblinShare och dashboarden. Ser knappar, kryssrutor, reglage, textfält och rullister exakt ut som förut (samma storlek, färg och hovring)? Fungerar ett klick på en knapp och reglage som vanligt? Är STOPP i Goblin AI fortfarande röd?
- Inga fel i fönstren
  kör: journalctl --user --since "10 min ago" | grep -i "qml/Goblin\|is not a type\|non-existent property" | tail -5
  väntat: inget (raderna här = en del från modulen saknas eller fel namn)
