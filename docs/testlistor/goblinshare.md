# GoblinShare på riktigt (två datorer och en telefon)

Så här provar du (rader utan "- " först läses inte av /testa):
  1. Vänta på nästa image och starta om datorn.
  2. I Claude Code på datorn, skriv: "Kopiera docs/testlistor/goblinshare.md till Kakans testlistor".
     Claude kör då (i repomappen):
       git pull
       mkdir -p ~/.local/share/goblincakes/testlistor
       cp docs/testlistor/goblinshare.md ~/.local/share/goblincakes/testlistor/
  3. Ha telefonen nära med appen LocalSend installerad (App Store / Google Play), på samma wifi som datorn.
     Har frugans dator GOBLINCAKES: slå på GoblinShare där också (Config → Program → System).
  4. Öppna Goblin AI och skriv /testa goblinshare. Kakan går igenom punkterna nedan och frågar dig.

- GoblinShare finns i imagen
  kör: test -x /usr/libexec/goblincakes-share && test -x /usr/bin/goblin-share && systemctl --user cat goblincakes-share.service >/dev/null && echo finns
  väntat: finns
- Slå på GoblinShare
  fråga: Öppna GOBLINCAKES Config → Program → System och kryssa i GoblinShare (eller kör goblin share på). Frågade datorn efter lösenordet (brandväggen)? Svara ja eller nej – båda är OK.
- Tjänsten kör
  kör: systemctl --user is-active goblincakes-share
  väntat: active
- Porten och brandväggen
  kör: ss -lntu | grep 53317; firewall-cmd --get-default-zone; firewall-cmd --list-ports
  väntat: 53317 både som tcp och udp; i list-ports antingen 1025-65535 eller 53317 för både tcp och udp
- Status från tjänsten
  kör: /usr/libexec/goblincakes-share status
  väntat: "Synlig som" med ditt namn och en adress som börjar på 192.168 eller 10., ingen FEL-rad
- Telefonen syns i GoblinShare
  fråga: Öppna LocalSend på telefonen, sedan GoblinShare (appmenyn eller goblin share) och tryck Leta igen. Syns telefonen som en ruta under PÅ NÄTVERKET?
- Datorn syns i LocalSend
  fråga: Syns datorn i LocalSend-appen på telefonen (med ditt namn och GOBLINCAKES)? Dra ner för att uppdatera om den inte syns.
- Från datorn till telefonen
  fråga: Dra en bild från Dolphin till telefonens ruta i GoblinShare. Frågade telefonen, och kom bilden fram när du tryckte acceptera?
- Från telefonen till datorn
  fråga: Skicka en bild från LocalSend på telefonen till datorn. Kom en notis med Ta emot / Neka, och hamnade bilden i Hämtade/GoblinShare när du tryckte Ta emot?
- Den mottagna bilden
  kör: ls -la ~/Hämtade/GoblinShare/ 2>/dev/null || ls -la ~/Downloads/GoblinShare/
  väntat: bilden från telefonen finns där (inte som .part)
- Meddelande från telefonen
  fråga: Skicka en text från LocalSend (Skicka → Text) till datorn. Kom en notis med texten, och syns den under HISTORIK i GoblinShare med en Kopiera-knapp?
- Dolphins högerklick
  fråga: Högerklicka på en fil i Dolphin. Finns "Skicka med GoblinShare", och öppnas GoblinShare med "Att skicka – …" överst?
- Den andra GOBLINCAKES-datorn
  fråga: Om frugans dator har GoblinShare på: syns den med GOBLINCAKES och en färgad remsa överst på rutan, och går det att skicka en mapp dit?
- Tjänstens logg
  kör: journalctl --user -u goblincakes-share -n 30 --no-pager
  väntat: inga Traceback-rader
