# Hämta data med SELECT

En databas har **tabeller** med rader och kolumner – som ett kalkylark.

```sql
SELECT namn, poang FROM skyttar;
SELECT * FROM skyttar ORDER BY poang DESC LIMIT 3;
```

- `*` = alla kolumner (bra när man tittar, men skriv ut kolumnerna i riktig kod).
- `ORDER BY poang DESC` = högst först (`ASC` = lägst först).
- `LIMIT 3` = bara tre rader. Avsluta med `;`.

Här i lärläget används SQLite – samma SQL som MariaDB/MySQL (Ianseo) för allt det här.
