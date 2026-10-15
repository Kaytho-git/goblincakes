# Ordböcker (dict)

En **ordbok** kopplar ihop en nyckel med ett värde – som en telefonbok:

```python
klasser = {"Kaytho": "Präst", "Bo": "Krigare"}
print(klasser["Kaytho"])          # Präst
klasser["Cia"] = "Magiker"         # lägg till
for namn, klass in klasser.items():
    print(f"{namn}: {klass}")
```

`"Bo" in klasser` ger `True`/`False`. `klasser.get("Dan", "okänd")` ger ett standardvärde i
stället för ett fel när nyckeln saknas.
