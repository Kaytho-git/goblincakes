# Filer

Program kan spara och läsa filer:

```python
with open("anteckning.txt", "w", encoding="utf-8") as f:
    f.write("Raid i kväll\n")

with open("anteckning.txt", encoding="utf-8") as f:
    for rad in f:
        print(rad.strip())
```

- `"w"` skriver (och tömmer filen först), `"a"` lägger till sist, utan = läsa.
- `with` stänger filen själv när blocket är klart.
- `rad.strip()` tar bort radbrytningen i slutet.
- Skriv `encoding="utf-8"` så att å, ä och ö blir rätt.
