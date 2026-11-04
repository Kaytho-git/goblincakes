# Hjälp via terminal (GoblinShare) – efter nästa image på båda datorerna
- Funktionen finns i imagen
  kör: grep -c "def help_start" /usr/share/goblincakes/share/share.py
  väntat: 1 (0 = imagen är för gammal – kör goblin update och starta om, på båda datorerna)
- SSH-programmen finns
  kör: command -v ssh ssh-keygen
  väntat: två sökvägar, /usr/bin/ssh och /usr/bin/ssh-keygen
- GoblinShare är på
  kör: goblin share status
  väntat: "Synlig som …" och att frugans dator räknas bland enheterna
- Be om hjälp på frugans dator
  fråga: På frugans dator: tryck Be om hjälp överst i GoblinShare. Frågade den efter lösenordet (bara första gången), och visades sedan en sexsiffrig kod?
- SSH-servern där
  fråga: På frugans dator i en terminal: systemctl is-active sshd. Svarade den active?
- Fel kod nekas
  fråga: Här: tryck Terminal på frugans ruta och skriv 000000. Stod det "Fel kod – försök igen (4 försök kvar)" i rutan?
- Terminal med rätt kod
  fråga: Skriv nu koden frugan läser upp och tryck Anslut. Öppnades en terminal inloggad på hennes dator, och står det "… är inne i din dator" med Avsluta hos henne?
- Namnet för ssh
  kör: goblin share terminal
  väntat: en rad "<frugans dator>: ansluten – ssh <namn> <kommando>"
- Kommando via anslutningen
  kör: ssh "$(sed -n 's/^Host //p' ~/.ssh/goblinshare.conf | head -1)" hostname
  väntat: frugans dators namn (inte din), utan att den frågar efter lösenord
- Nyckeln borta medan du är inne
  fråga: På frugans dator under tiden: grep -c goblinshare ~/.ssh/authorized_keys. Blev det 0?
- Avsluta
  fråga: Frugan trycker Avsluta. Stängdes din terminal till henne?
- Ute efter Avsluta
  kör: ssh -o BatchMode=yes "$(sed -n 's/^Host //p' ~/.ssh/goblinshare.conf | head -1)" hostname
  väntat: Permission denied (publickey) – inte frugans datornamn
- Stänga terminalen själv
  fråga: Be frugan om en ny kod, anslut, och stäng sedan terminalen själv. Fick hon notisen "… har lämnat datorn"?
- Hjälp via terminal av
  fråga: På frugans dator: GoblinShare → Inställningar → slå av "Tillåt hjälp via terminal". Är sshd av där nu (systemctl is-active sshd = inactive)?
- Tjänstens logg
  kör: journalctl --user -u goblincakes-share -n 40 --no-pager
  väntat: inga Traceback-rader
