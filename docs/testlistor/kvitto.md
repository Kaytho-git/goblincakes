# Kvittot under svaren + klart-kontrollen (punkt 23)

Så här provar du (rader utan "- " först läses inte av /testa):
  1. Vänta på nästa image (Goblin AI körs från /usr) och starta om datorn.
  2. I Claude Code på datorn, skriv: "Kopiera docs/testlistor/kvitto.md till Kakans testlistor".
     Claude kör då (i repomappen):
       git pull
       mkdir -p ~/.local/share/goblincakes/testlistor
       cp docs/testlistor/kvitto.md ~/.local/share/goblincakes/testlistor/
  3. Öppna Goblin AI och skriv /testa kvitto. Kakan går igenom punkterna nedan och frågar dig.

- Kvittot finns i imagen
  kör: grep -c "def receipt" /usr/share/goblincakes/ai/goblinai.py
  väntat: 1
- Kvitto efter en fråga med verktyg
  fråga: Öppna en ny chatt och skriv "vilka fel har WoW haft idag?". Står det en rad "▸ Kvitto: läste …" under svaret, ovanför Kopiera svaret?
- Kvittot fälls ut
  fråga: Klicka på "▸ Kvitto". Syns en lista med vad hon läste (✓ framför varje rad)?
- Inget kvitto vid vanligt prat
  fråga: Skriv "hej, hur mår du?". Svaret ska INTE ha någon kvittorad. Stämmer det?
- Väntar på Tillåt
  fråga: Be henne "skapa filen ~/kvitto-prov.txt med texten hej". Om hon säger att det är klart innan du tryckt Tillåt: står det i rött "✗ Inte klart än – det som ska göras väntar på att du trycker Tillåt"? (Svarar hon bara med kortet utan att säga klart syns ingen röd rad – svara då "hoppa".)
- Kvittot uppdateras när kortet körts
  fråga: Tryck Tillåt på kortet. Flyttar kvittot till hennes nästa svar, och står det "körde 1 · ändrade 1" där?
- Kontrollerat efteråt
  fråga: Läser hon filen efteråt (ett läsande kommando som cat) och säger klart – står det "✓ Klart – ändrat och kontrollerat efteråt" i accentfärgen? Säger hon klart utan att läsa: står det "! Ändrat – men inte kontrollerat efteråt"?
- Hon rättar sig själv
  fråga: Säger hon klart utan att läsa filen: skriver hon direkt ett nytt svar där hon kollar filen (cat) och sedan säger vad hon såg – och står det då "✓ Klart – ändrat och kontrollerat efteråt" under det svaret?
- Provfilen bort
  kör: gio trash ~/kvitto-prov.txt 2>&1; ls ~/kvitto-prov.txt 2>&1
  väntat: No such file
- Kvittot i terminalen
  fråga: Kör "goblin ai" i en terminal och fråga "vilka fel har datorn haft idag?". Står det "Kvitto: läste …" efter svaret?
- Kvittot i Skicka till Claude
  kör: grep -l "Kvitto:" ~/.local/share/goblincakes/till-claude/*.md 2>/dev/null | tail -1
  väntat: en fil (bara om Skicka till Claude använts efter uppdateringen – annars hoppa)
