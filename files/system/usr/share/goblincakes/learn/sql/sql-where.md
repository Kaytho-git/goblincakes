# Välja rader med WHERE

```sql
SELECT namn FROM skyttar WHERE klubb = 'Lund';
SELECT namn FROM skyttar WHERE poang > 600 AND klubb = 'Malmö';
SELECT namn FROM skyttar WHERE namn LIKE 'A%';      -- börjar på A
SELECT namn FROM skyttar WHERE klubb IN ('Lund', 'Ystad');
```

Text står inom **enkla** citattecken. `%` i `LIKE` betyder "vad som helst". Tom kolumn testas med
`IS NULL` (inte `= NULL`).
