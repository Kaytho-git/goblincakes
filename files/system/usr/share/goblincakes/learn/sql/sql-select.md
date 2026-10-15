# Hämta data med SELECT

En databas har **tabeller** med rader och kolumner – som ett kalkylark.

```sql
SELECT namn, poang FROM skyttar;
```

hämtar två kolumner från tabellen `skyttar`. Sortera med `ORDER BY` (`DESC` = störst först),
välj ut rader med `WHERE`:

```sql
SELECT namn FROM skyttar WHERE poang > 600 ORDER BY poang DESC;
```

Avsluta med `;`.
