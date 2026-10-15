# Räkna och gruppera

```sql
SELECT COUNT(*) AS antal FROM skyttar;
SELECT klubb, COUNT(*) AS antal, AVG(poang) AS snitt
FROM skyttar
GROUP BY klubb
ORDER BY snitt DESC;
```

`GROUP BY` samlar raderna per värde – en rad per klubb. `HAVING antal > 1` väljer bland
grupperna (WHERE väljer bland raderna innan de grupperas).
