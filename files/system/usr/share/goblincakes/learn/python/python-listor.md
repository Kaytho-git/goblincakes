# Listor

En **lista** håller många värden i ordning:

```python
raid = ["Kaytho", "Bo", "Cia"]
print(raid[0])        # Kaytho – första har index 0
raid.append("Dan")    # lägg till sist
print(len(raid))      # 4
for namn in raid:
    print(namn)
```

Bra att ha: `sum(lista)`, `max(lista)`, `min(lista)`, `sorted(lista)` (ny sorterad lista,
`reverse=True` för störst först), och `lista[1:3]` = en bit av listan (index 1 och 2).
