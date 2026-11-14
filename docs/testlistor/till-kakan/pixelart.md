# Pixelart: Kakan och ChatGPT ritar samma
- Ritprogrammet är installerat och har Z-Image-Turbo
  kör: /usr/libexec/goblincakes-image status | python3 -c "import json,sys; d=json.load(sys.stdin); print('installerat', d['installed']); print('z-image', [m['ready'] for m in d['models'] if m['id']=='z-image-turbo']); print('stilar', d.get('styles'))"
  väntat: "installerat True" och "z-image [True]"; raden "stilar" listar pixelart (ready får vara False – tillägget hämtas vid första bilden). Saknas "stilar" helt är imagen för gammal (före 14 nov).
- Pixelart-tillägget går att hämta (tar en stund, vänta)
  kör: /usr/libexec/goblincakes-image pull-style pixelart
  väntat: sista raden "@@ Klart: Pixelart (16-bit)" och kod 0
- Kakan ritar Saturnus i pixelart (tar 1–3 min, vänta)
  kör: goblin pixelart kakan saturnus
  väntat: en rad "✓ Saturnus: …/Bilder/Barnläge/pixelart/kakan/saturnus.png (128 × 128, … färger)". "Ett spel kör" = avsluta spelet och försök igen.
- ChatGPT ritar Saturnus
  fråga: Kör `goblin pixelart chatgpt saturnus` i en terminal. ChatGPT-appen öppnas i Codex med texten ifylld – tryck Enter där. Kom det en rad "✓ Saturnus: …/chatgpt/saturnus.png" efter att bilden ritats? (Står inte Codex vald i appens rullgardin: välj Codex och försök igen.)
- Stilen ligger i Codex AGENTS.md
  kör: grep -c "goblincakes-pixelart" ~/.codex/AGENTS.md
  väntat: 2
- Jämförelsebilden
  fråga: Kör `goblin pixelart jämför`. En bild öppnas med Saturnus fyra gånger (Kakan rå och städad, ChatGPT rå och städad). Är de städade bilderna skarpa pixlar utan rosa kant runt planeten?
- Vilken är finast?
  fråga: Vilken Saturnus gillar du bäst – Kakans eller ChatGPT:s? Och ser den städade bättre ut än den råa? (Svaret går till Claude.)
- Pixelart i Goblin AI-chatten
  fråga: Skriv i Goblin AI: "rita en liten drake i pixelart". Står det "Din dator · Z-Image-Turbo · pixelart" under bilden, och ser den ut som pixelart?
