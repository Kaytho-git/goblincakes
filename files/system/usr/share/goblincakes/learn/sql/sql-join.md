# Flera tabeller: JOIN

I riktiga databaser (som Ianseos) delas datan upp: en tabell med skyttar, en med klubbar –
kopplade med ett **id**:

```sql
SELECT s.namn, k.namn AS klubb
FROM skyttar s
JOIN klubbar k ON s.klubb_id = k.id
ORDER BY s.namn;
```

`s` och `k` är korta namn på tabellerna. `JOIN` tar bara rader som har en träff i båda;
`LEFT JOIN` behåller alla från den vänstra (med NULL där träff saknas).
