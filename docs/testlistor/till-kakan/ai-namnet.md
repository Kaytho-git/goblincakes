# AI:ns namn (Goblin AI som standard, ditt namn överallt) – efter nästa image
- Namnet är sparat
  kör: cat ~/.config/goblincakes/ai-name 2>/dev/null || echo "inget namn sparat"
  väntat: Kakan – står det "inget namn sparat" är det FEL för användaren (då heter AI:n Goblin AI överallt; skriv Kakan i Goblin AI → Inställningar → Namn)
- Namnet läses av alla delar
  kör: python3 -c "import sys; sys.path.insert(0, '/usr/share/goblincakes/ai'); import ainame; print(ainame.name(), ainame.gen())"
  väntat: samma namn som i förra punkten och samma namn med s på slutet, t.ex. "Kakan Kakans"
- Väckordet
  kör: python3 /usr/share/goblincakes/ai/voicecmd.py "hej kakan" "goblin ai pausa"
  väntat: greet på första raden och pause på andra (inte None) när namnet är Kakan
- Rösten
  fråga: Säg bara "Kakan" (utan att hålla F8, eller med F8 om rösten inte lyssnar själv). Hälsar hon och lyssnar sedan? Står det Kakan överst i rutan uppe till höger?
- Texterna
  fråga: Öppna dashboarden. Står det "Fråga Kakan …" på knapparna (WoW, CS2, Byggen) och KAKAN / KAKANS RAPPORTER på rapportramen? Står det KAKAN i mitten av AI-kartan när du jobbar med mig?
- Byta namn
  fråga: Skriv ett annat namn i Goblin AI → Inställningar → Namn (t.ex. Test), öppna dashboarden igen och säg "hej test". Följer texterna och väckordet med? Byt tillbaka till Kakan efteråt.
- Provmappen är kvar
  kör: ls -d ~/kakan-prov ~/goblin-prov 2>&1
  väntat: ~/kakan-prov finns om den fanns förut; ~/goblin-prov ska INTE ha skapats när ~/kakan-prov finns
