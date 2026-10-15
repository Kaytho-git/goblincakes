# Ändra data: INSERT, UPDATE, DELETE

```sql
INSERT INTO skyttar (namn, klubb, poang) VALUES ('Eva', 'Ystad', 640);
UPDATE skyttar SET poang = 660 WHERE namn = 'Bo';
DELETE FROM skyttar WHERE namn = 'Cia';
```

**Varning:** `UPDATE` och `DELETE` utan `WHERE` ändrar/tar bort **alla** rader. Gör gärna en
`SELECT` med samma `WHERE` först och se vilka rader det gäller – och ha en backup (Ianseo i
GOBLINCAKES gör backup var 30:e minut).
