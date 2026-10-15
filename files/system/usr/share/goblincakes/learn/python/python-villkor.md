# Villkor – if, elif, else

Med `if` gör programmet olika saker beroende på något:

```python
poang = 612
if poang >= 600:
    print("Bra serie!")
elif poang >= 500:
    print("Helt okej")
else:
    print("Träna mer")
```

- Raden slutar med **kolon** `:`, och det som hör till villkoret är **indraget** (4 mellanslag).
- Jämför med `==` (lika med – två likhetstecken!), `!=` (inte lika), `<`, `>`, `<=`, `>=`.
- Kombinera med `and`, `or` och `not`: `if nivå >= 80 and klass == "Präst":`

Python kollar villkoren uppifrån och ner och gör **bara det första** som stämmer.
