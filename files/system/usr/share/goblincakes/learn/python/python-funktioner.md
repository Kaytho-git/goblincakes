# Funktioner

En **funktion** är kod med ett namn som man kan använda om och om igen:

```python
def halsa(namn):
    return f"Hej {namn}!"

print(halsa("Kaytho"))
print(halsa("Bo"))
```

- `def` skapar funktionen, det inom parentesen är **parametrar** (det man skickar in).
- `return` skickar tillbaka ett svar. Utan `return` ger funktionen `None`.
- En parameter kan ha ett standardvärde: `def serie(pilar=6):`

Funktioner gör programmet lättare att läsa – ge dem namn som säger vad de gör.
