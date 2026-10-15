# Loopar – for och while

En **loop** gör samma sak flera gånger.

```python
for serie in range(1, 4):
    print(f"Serie {serie}")
```

`range(1, 4)` ger 1, 2, 3 – **till men inte med** det sista talet. `range(5)` ger 0–4.

`while` upprepar så länge ett villkor stämmer:

```python
energi = 3
while energi > 0:
    print("Skjuter")
    energi = energi - 1
```

Glöm inte att ändra värdet – annars tar loopen aldrig slut. `break` avbryter en loop direkt.
