# Följdfrågor till svar från nätet – efter nästa image
- Funktionen finns i imagen
  kör: grep -c "def follow_up_of" /usr/share/goblincakes/ai/goblinai.py
  väntat: 1 (0 = imagen är för gammal – kör goblin update och starta om)
- Första frågan
  fråga: Starta en ny chatt i Goblin AI och fråga "när gick senaste OS i bågskytte?". Svarade hon Paris 2024 med Källor under svaret?
- Följdfråga 1
  fråga: Fråga sedan i samma chatt "blev det några världsrekord?". Stod det "Förstår följdfrågan" i stegen med en sökfråga om bågskytte och OS, och handlade svaret om bågskytte vid OS?
- Följdfråga 2
  fråga: Fråga "fanns det några svenskar med?". Handlade svaret om svenska bågskyttar vid samma OS?
- Ingen sökning när det inte behövs
  fråga: Skriv "förklara det enklare". Stod det "ingen ny sökning behövs" (eller inget sökningssteg alls) och kom ett enklare svar?
- Ämnesbyte
  fråga: Fråga i samma chatt "vad är senaste patchen i WoW?". Gällde sökningen WoW och inte bågskytte?
