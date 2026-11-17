# Bilder i Goblin AI:s terminal (efter nästa image)
- Koden finns i imagen
  kör: grep -c imageLinks /usr/share/goblincakes/ai/terminal/index.html; grep -c "def imageUrl" /usr/share/goblincakes/ai/ptyterm.py
  väntat: två rader, den första 3 eller mer och den andra 1
- Förhandsvisning när musen är över en bildväg
  fråga: Starta om Goblin AI. Öppna fliken TERMINAL och skriv: ls /usr/share/icons/hicolor/scalable/apps/goblincakes-*.svg | head -3 – håll musen över en av raderna. Blir raden understruken och syns en liten bild efter en kort stund?
- Stor bild vid klick
  fråga: Klicka på samma rad. Visas bilden stort med ÖPPNA I BILDVISAREN och STÄNG överst, och stänger Esc den så att du kan skriva i terminalen igen?
- Öppna i bildvisaren
  fråga: Klicka på en rad igen och sedan ÖPPNA I BILDVISAREN. Öppnas bilden i ett vanligt bildprogram?
- Claude Codes egna bildvägar
  fråga: Be Claude Code i TERMINAL-fliken ta en skärmbild eller visa en bild (t.ex. "skriv ut hela sökvägen till en png i repot"). Blir sökvägen understruken och visas bilden när du håller musen över den – även om sökvägen är så lång att den går över två rader?
