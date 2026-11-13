# AI-kartan: Codex och Kakan – efter nästa image
- Kakans logg skrivs
  fråga: Ställ en fråga i Goblin AI som får Kakan att söka på nätet (t.ex. "vad är senaste WoW-patchen?"). Svara ja när svaret har kommit.
- Kakans logg har raderna
  kör: tail -n 8 ~/.local/state/goblincakes/kakan-karta.jsonl
  väntat: rader med "e": "user", "model", "start" och "end" (med "tool": "sök") och sist "answer" – från frågan nyss
- Kakan på kartan
  fråga: Öppna dashboarden (vyn JOBB) och tryck på AI-KARTAN medan du ställer en ny fråga till Kakan. Står det KAKAN i mitten, och lyser NÄTET när hon söker? Syns stegen i raderna till höger?
- Kakans kommandokort
  fråga: Be Kakan om ett kommando (t.ex. "visa diskutrymmet") och tryck Kör på kortet. Lyser KOMMANDON på kartan medan det kör?
- Codex finns
  kör: command -v codex && ls -d ~/.codex/sessions 2>/dev/null || echo "codex finns inte"
  väntat: sökvägen till codex och mappen sessions – står det "codex finns inte" är resten OKLART (Codex är inte installerat)
- Codex på kartan
  fråga: Starta codex i ett projekt i Goblin AI:s TERMINAL och ge det en uppgift. Står det CODEX i mitten av kartan till höger, med projektets namn och modellen ovanför raderna? Lyser SKAL/FILER när det jobbar?
- Dashboarden öppnar på kartan
  fråga: Tryck Meta när ingen AI jobbar. Står det VILANDE i mitten med kartan och "senast …"? Börja skriva ett programnamn – kommer programmen? Tryck Esc två gånger – tillbaka till kartan och sedan göms dashboarden?
- Valet i Config
  fråga: Välj "Program" i Config → Dashboard (överst) och tryck Meta. Öppnar den på programmen? Välj "AI-kartan" igen.
