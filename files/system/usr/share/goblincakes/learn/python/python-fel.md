# Fel och felhantering

När något går fel skriver Python ett **felmeddelande**. Läs det **nerifrån**: sista raden säger
vad som hände (`ValueError`, `NameError`, `KeyError` …), raden ovanför var i koden.

Vissa fel kan man vänta sig – t.ex. att någon skriver text där det skulle vara ett tal.
Fånga dem med `try` och `except`:

```python
for text in ["12", "tolv"]:
    try:
        print(int(text) * 2)
    except ValueError:
        print(f"{text} är inget tal")
```

Fånga bara de fel du vet vad du ska göra med – ett tomt `except:` gömmer riktiga buggar.
