# GOBLINCAKES på mobilen

Bakgrunder och färglista för att ge en Android-telefon GOBLINCAKES-utseende (gjort för Samsung Galaxy S24 Ultra, 1440×3120).

- `gc-mobil.png` – djupblå med goblin-loggan i egna färger
- `gc-mobil-mork.png` – mörk och platt, loggan ton-i-ton
- `farglista.png` – färgerna för Theme Park (Good Lock) fält för fält (Background, On background, surface, On surface, Primary, On primary, Secondary) och var man hittar dem – provad på S24 Ultra 19 nov

Skicka till telefonen med GoblinShare (LocalSend) eller ladda ner från GitHub.

Källorna är `*.svg` och `farglista.html`; PNG-filerna renderas med Chromium (Playwright): bakgrunderna i 1440×3120 med skala 1, färglistan 720 bred med skala 2 (hela sidan). Utan Playwright: `flatpak run org.chromium.Chromium --headless=new --force-device-scale-factor=2 --window-size=720,1500 --screenshot=… file://…/farglista.html`.
