# Dashboarden: Blizzard-data i WoW Stats och ramen WoW-läget (18 nov)
- Hjälparen finns i imagen
  kör: python3 /usr/share/goblincakes/dashboard/blizzard.py status
  väntat: en rad "configured" (true eller false) och "clients" med develop.battle.net
- Blizzard-nyckeln läggs in
  fråga: Öppna GOBLINCAKES Config → DASHBOARD och rulla ner till BLIZZARD. Tryck "Skapa nyckel …", logga in på develop.battle.net, Create Client (namn GOBLINCAKES, Redirect URL http://localhost), klistra in Client ID och Client Secret och tryck Spara. Står det "Nyckeln fungerar och är sparad"?
- Nyckelfilen är bara läsbar för dig
  kör: stat -c '%a' ~/.config/goblincakes/blizzard.json
  väntat: 600
- Blizzard svarar för en karaktär (tar några sekunder)
  ```bash
  python3 - <<'EOF'
  import json, sys
  sys.path.insert(0, "/usr/share/goblincakes/dashboard")
  import stats, blizzard
  p = (stats.wow().get("players") or [{}])[0]
  print("karaktär:", p.get("name"), p.get("realm"), p.get("region"))
  c = blizzard.char(p["name"], p["realm"], p["region"])
  print(json.dumps({k: c.get(k) for k in ("missing", "game", "level", "ilvl", "guild", "picture")}, ensure_ascii=False))
  print("M+:", (c.get("mplus") or {}).get("score"), "dungeons:", len((c.get("mplus") or {}).get("best") or []))
  print("raider:", [r["name"] for r in c.get("raids") or []])
  print("pvp:", c.get("pvp"))
  EOF
  ```
  väntat: "missing" är null, "level" och "ilvl" är siffror, "picture" är en sökväg under ~/.cache/goblincakes/blizzard/, "raider" har minst en raid. M+ och pvp får vara null/tomma om karaktären inte kört nycklar eller PvP den här säsongen
- WoW-läget svarar
  ```bash
  python3 - <<'EOF'
  import json, sys
  sys.path.insert(0, "/usr/share/goblincakes/dashboard")
  import stats, blizzard
  p = (stats.wow().get("players") or [{}])[0]
  w = blizzard.world(p.get("region") or "eu", [p.get("realm")])
  print(json.dumps({k: w.get(k) for k in ("token", "why", "realms")}, ensure_ascii=False))
  print("reset om", blizzard.reset_text(w["reset"]))
  EOF
  ```
  väntat: "token" är ett guldpris (flera hundra tusen), "why" är null, realmen har "up": true och "Online" i "text"
- Karaktären i dashboarden
  fråga: Öppna dashboarden (vyn med WoW Stats) och tryck på din karaktär. Syns bilden av karaktären till vänster, och under siffrorna M+ SCORE, RAIDPROGRESS, PVP och MYTHIC+ · BÄSTA PER DUNGEON? Stämmer siffrorna med Armory/Raider.IO? Ser bilden bra ut (inte för utzoomad eller avklippt)?
- M+ score i listan
  fråga: Står det "M+" med en färgad siffra bredvid ilvl på karaktärerna i WoW Stats-ramen?
- Ramen WoW-läget
  fråga: Lägg till ramen WoW-läget i en vy (Config → DASHBOARD → vyerna, t.ex. i stället för CS2 Stats) och öppna dashboarden. Syns token-priset, tid till veckoreset och realmen med grön prick?
- Köp token
  fråga: Tryck "Köp token i Blizzards butik" i WoW-läget. Öppnas Blizzards butik för World of Warcraft i webbläsaren, och hittar du WoW Token där?
- Veckoreset stämmer
  fråga: Stämmer "VECKORESET OM" med när resetten faktiskt är (onsdag morgon)?
