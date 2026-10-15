# Hur Ianseo är byggt

Ianseo är en PHP-app med en MariaDB-databas. I GOBLINCAKES kör den i containrar
(`ianseo-web` med filerna i `/opt/ianseo`, `ianseo-db` med databasen `ianseo`).

Ianseos tabeller har ett **prefix per tabell** på kolumnerna, t.ex.:

| Tabell | Innehåll | Några kolumner |
|---|---|---|
| `Tournament` | tävlingar | `ToId`, `ToCode`, `ToName` |
| `Entries` | deltagare | `EnId`, `EnName`, `EnFirstName`, `EnCountry`, `EnDivision`, `EnClass`, `EnTournament` |
| `Countries` | klubbar/länder | `CoId`, `CoCode`, `CoName` |
| `Qualifications` | kvalresultat (samma id som deltagaren) | `QuId`, `QuScore`, `QuGold`, `QuXnine` |

Lika poäng avgörs av antal 10:or (`QuGold`) och sedan X/9:or (`QuXnine`).

**Viktigt:** pröva aldrig ny kod mot en riktig tävling. Ta en kopia av databasen (GOBLINCAKES gör
backup i `~/Ianseo/Backup`) – här i lärläget används förenklade kopior av tabellerna i SQLite.
Kolla kolumnerna i din egen Ianseo (`SHOW COLUMNS FROM Entries;`) – de kan skilja mellan versioner.
