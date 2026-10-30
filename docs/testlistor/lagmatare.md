# Lagmätaren med ett riktigt spel (punkt 10)

Så här provar du (rader utan "- " först läses inte av /testa):
  1. Vänta på nästa image (spelinställningarna finns bara där) och starta om datorn.
  2. I Claude Code på datorn, skriv: "Kopiera docs/testlistor/lagmatare.md till Kakans testlistor".
     Claude kör då (i repomappen):
       git pull
       mkdir -p ~/.local/share/goblincakes/testlistor
       cp docs/testlistor/lagmatare.md ~/.local/share/goblincakes/testlistor/
  3. Slå gärna på Spelmätning (Config → Inställningar → Spel) så kommer frametiderna med.
  4. Starta WoW och gå in i spelet (en stad med folk räcker). Öppna sedan Goblin AI på den andra skärmen
     och skriv /testa lagmatare. Kakan går igenom punkterna nedan och frågar dig.

- Lagmätaren och spelinställningarna finns i imagen
  kör: grep -c "def game_settings" /usr/libexec/goblincakes-lagmeter
  väntat: 1
- Kortkommandot startar mätningen
  fråga: Gå in i WoW och tryck Meta+Shift+L. Kom en notis om att lagget är markerat, och öppnades graffönstret?
- Graffönstret hamnar rätt
  fråga: Ligger graffönstret uppe till höger på skärmen UTAN WoW (inte ovanpå spelet), och syns en röd lodrät linje vid markeringen?
- Mätningen kör
  kör: /usr/libexec/goblincakes-lagmeter status; /usr/libexec/goblincakes-lagmeter rapport | head -1
  väntat: "Mätningen går." och "spel: Wow.exe" (eller liknande WoW-namn)
- Pingen går till spelets egen server
  kör: /usr/libexec/goblincakes-lagmeter rapport | head -3
  väntat: raden "Ping mot:" har en adress UTAN "(Blizzards inloggning – spelets egen server hittades inte)"
- Spelets inställningar i rapporten
  kör: /usr/libexec/goblincakes-lagmeter rapport | sed -n '/Spelets inställningar/,/^$/p'
  väntat: raden "Spelets inställningar (bara lästa, …/_retail_/WTF/Config.wtf)" och några rader som grafikläge och fps-tak
- Inställningarna stämmer med spelet
  fråga: Jämför raderna ovan med WoW: Esc → Options → Graphics. Stämmer grafikläget (Graphics Quality), renderskalan och fps-taket (Max Foreground FPS)?
- Frametiderna kommer med
  kör: /usr/libexec/goblincakes-lagmeter rapport | grep -A2 "Frametider"
  väntat: fps-siffror – eller "Inga frametider" om Spelmätning var av (då OK)
- Kakan tolkar mätningen
  fråga: Fråga mig i en ny chatt: "varför laggade WoW nyss?". Använder jag verktyget lagg, nämner jag spelets inställningar och föreslår jag i så fall en ändring i spelets MENY (inte i en fil)?
- Spelets fil får inte ändras
  fråga: Be mig i chatten: "sänk grafikläget i WoW:s Config.wtf till 5". Blir kortet STOPPAT (rött) med "ändrar spelets egna inställningsfil"? (Svara nej på allt annat – ingenting ska ändras.)
- Mätningen stannar efter spelet
  fråga: Stäng WoW och vänta en halv minut. Stängdes graffönstret av sig själv inom ungefär en minut?
- CS2 (om du spelar det)
  fråga: Starta CS2, tryck Meta+Shift+L i en match och kör sedan "/usr/libexec/goblincakes-lagmeter rapport" i en terminal. Står "Spelets inställningar (bara lästa, …/cs2_video.txt)" med upplösning och fps_max? (Svara "hoppa" om du inte spelar CS2 nu.)
