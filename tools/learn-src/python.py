from lib import write_track, T
M = []
M.append({"id": "python-hej", "title": "Ditt första program", "requires": [],
 "summary": "`print(\"text\")` skriver ut en rad; text (strängar) står inom citattecken; raderna körs uppifrån och ner. `#` = kommentar.",
 "lesson_md": """
# Ditt första program

Ett program är en lista med instruktioner som datorn gör, **uppifrån och ner**.
I Python skriver man ut text med `print`:

```python
print("Hej!")
```

Texten inom citattecken kallas en **sträng**. Utan citattecken tror Python att det är ett
namn på något, och säger till med ett fel.

Flera rader körs i ordning:

```python
print("Rad ett")
print("Rad två")
```

En rad som börjar med `#` är en **kommentar** – en anteckning till människor som Python hoppar över.

**Bra att veta:** stora och små bokstäver spelar roll – `Print` fungerar inte, bara `print`.
""", "tasks": [
 T("python-hej-1", 1, "Säg hej", "Skriv ett program som skriver ut exakt: Hej GOBLINCAKES!",
   'print("Hej GOBLINCAKES!")', {"expect": "Hej GOBLINCAKES!"},
   ["Använd print och sätt texten inom citattecken.", 'print("…") – byt … mot texten, med utropstecknet.'],
   "# Skriv din kod här\n"),
 T("python-hej-2", 2, "Tre rader", "Skriv ut de här tre raderna, i den här ordningen:\nRaid i kväll\nKl. 20:00\nTa med flaskor!",
   'print("Raid i kväll")\nprint("Kl. 20:00")\nprint("Ta med flaskor!")', {"expect": "Raid i kväll\nKl. 20:00\nTa med flaskor!"},
   ["En print per rad.", "Raderna körs uppifrån och ner – samma ordning som i uppgiften."]),
]})
M.append({"id": "python-variabler", "title": "Variabler", "requires": ["python-hej"],
 "summary": "`namn = värde`; tal (`int`, `float`) räknar man med (`+ - * / // %`), text står inom citattecken; f-strängar: `f\"Hej {namn}\"`; `int(\"5\")`/`str(5)` byter typ.",
 "lesson_md": """
# Variabler

En **variabel** är ett namn på ett värde – som en etikett på en låda.

```python
namn = "Kaytho"
nivå = 80
print(namn)
print(nivå + 1)
```

`=` betyder "lägg värdet i lådan", inte "är lika med". Värdet kan bytas senare: `nivå = nivå + 1`.

**Typer:** tal utan citattecken (`80`, `3.5`) kan man räkna med: `+ - * /`, heltalsdivision `//`
och rest `%`. Text inom citattecken är en sträng – `"80" + 1` blir ett fel. Byt typ med
`int("80")` och `str(80)`.

Text och variabler sätts ihop med en **f-sträng** – ett `f` före citattecknet och variabeln inom `{ }`:

```python
print(f"Hej {namn}, du är nivå {nivå}")
```
""", "tasks": [
 T("python-variabler-1", 1, "Din karaktär", 'Skapa variablerna namn = "Kaytho" och nivå = 80, och skriv ut: Kaytho är nivå 80',
   'namn = "Kaytho"\nnivå = 80\nprint(f"{namn} är nivå {nivå}")', {"expect": "Kaytho är nivå 80"},
   ['En f-sträng sätter in variabler: f"… {namn} …"', 'print(f"{namn} är nivå {nivå}")'],
   'namn = "Kaytho"\nnivå = 80\n'),
 T("python-variabler-2", 2, "Räkna pilar", "En bågskytt skjuter 6 pilar per serie och 12 serier. Spara talen i variabler, räkna ut totalen och skriv ut: Totalt 72 pilar",
   'pilar = 6\nserier = 12\ntotalt = pilar * serier\nprint(f"Totalt {totalt} pilar")', {"expect": "Totalt 72 pilar"},
   ["Gånger skrivs * i Python.", "pilar = 6, serier = 12, totalt = pilar * serier"]),
 T("python-variabler-3", 3, "Snittpoäng", "En skytt fick 612 poäng på 72 pilar. Räkna ut snittet per pil med två decimaler och skriv ut: Snitt 8.50 per pil",
   'poang = 612\npilar = 72\nsnitt = poang / pilar\nprint(f"Snitt {snitt:.2f} per pil")', {"expect": "Snitt 8.50 per pil"},
   ["/ ger ett decimaltal.", "I en f-sträng ger {tal:.2f} två decimaler."]),
]})
M.append({"id": "python-villkor", "title": "Villkor – if, elif, else", "requires": ["python-variabler"],
 "summary": "`if villkor:` + indrag; `elif`, `else`; jämförelser `== != < > <= >=`; `and`, `or`, `not`.",
 "lesson_md": """
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
""", "tasks": [
 T("python-villkor-1", 1, "Godkänd?", "Variabeln poang = 540. Skriv ut Godkänd om poang är minst 500, annars Underkänd.",
   'poang = 540\nif poang >= 500:\n    print("Godkänd")\nelse:\n    print("Underkänd")', {"expect": "Godkänd"},
   ["if poang >= 500: … else: …", "Glöm inte kolon och indrag."], "poang = 540\n"),
 T("python-villkor-2", 2, "Medalj", "Variabeln placering = 2. Skriv ut Guld för 1, Silver för 2, Brons för 3 och annars Ingen medalj.",
   'placering = 2\nif placering == 1:\n    print("Guld")\nelif placering == 2:\n    print("Silver")\nelif placering == 3:\n    print("Brons")\nelse:\n    print("Ingen medalj")',
   {"type": "script", "script": "check_medalj.py"},
   ["Jämför med == (två likhetstecken).", "if … elif … elif … else"], "placering = 2\n"),
]})
M.append({"id": "python-loopar", "title": "Loopar – for och while", "requires": ["python-villkor"],
 "summary": "`for i in range(1, 6):` upprepar; `while villkor:` så länge det stämmer; `break` avbryter.",
 "lesson_md": """
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
""", "tasks": [
 T("python-loopar-1", 1, "Räkna till fem", "Skriv ut talen 1 till 5, ett per rad, med en for-loop.",
   'for i in range(1, 6):\n    print(i)', {"expect": "1\n2\n3\n4\n5"},
   ["range(1, 6) ger 1–5.", "for i in range(1, 6):\n    print(i)"]),
 T("python-loopar-2", 2, "Summera serier", "Serierna gav 54, 52, 57 och 55 poäng. Lägg ihop dem med en loop och skriv ut: Summa 218",
   'summa = 0\nfor p in [54, 52, 57, 55]:\n    summa += p\nprint(f"Summa {summa}")', {"expect": "Summa 218"},
   ["Börja med summa = 0 och lägg till varje poäng.", "for p in [54, 52, 57, 55]: summa += p"]),
 T("python-loopar-3", 3, "Nedräkning", "Räkna ner från 3 med en while-loop och skriv sedan Pull! – alltså 3, 2, 1 och Pull! på var sin rad.",
   'n = 3\nwhile n > 0:\n    print(n)\n    n -= 1\nprint("Pull!")', {"expect": "3\n2\n1\nPull!"},
   ["while n > 0: … och minska n varje varv.", "print(\"Pull!\") efter loopen (utan indrag)."]),
]})
M.append({"id": "python-listor", "title": "Listor", "requires": ["python-loopar"],
 "summary": "`[a, b, c]`, index från 0, `append`, `len`, `sorted`, `sum`, `max`, slicing `lista[1:3]`.",
 "lesson_md": """
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
""", "tasks": [
 T("python-listor-1", 1, "Högsta serien", "poang = [54, 52, 57, 55]. Skriv ut den högsta serien: 57",
   'poang = [54, 52, 57, 55]\nprint(max(poang))', {"expect": "57"}, ["max() ger det största värdet.", "print(max(poang))"],
   "poang = [54, 52, 57, 55]\n"),
 T("python-listor-2", 2, "Topp tre", "poang = [54, 52, 57, 55, 49]. Skriv ut de tre högsta, högst först, på var sin rad.",
   'poang = [54, 52, 57, 55, 49]\nfor p in sorted(poang, reverse=True)[:3]:\n    print(p)', {"expect": "57\n55\n54"},
   ["sorted(poang, reverse=True) sorterar störst först.", "[:3] tar de tre första."], "poang = [54, 52, 57, 55, 49]\n"),
]})
M.append({"id": "python-funktioner", "title": "Funktioner", "requires": ["python-listor"],
 "summary": "`def namn(parametrar):` + `return`; anropa `namn(värden)`; standardvärden `def f(x=1)`.",
 "lesson_md": """
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
""", "tasks": [
 T("python-funktioner-1", 1, "Dubbla", "Skriv funktionen dubbla(x) som returnerar x gånger 2. Skriv sedan ut dubbla(21).",
   'def dubbla(x):\n    return x * 2\n\nprint(dubbla(21))', {"expect": "42"},
   ["def dubbla(x):\n    return …", "print(dubbla(21))"], "def dubbla(x):\n    pass  # byt mot din kod\n\nprint(dubbla(21))\n"),
 T("python-funktioner-2", 2, "Snitt", "Skriv funktionen snitt(lista) som returnerar medelvärdet. Skriv ut snitt([8, 9, 10, 9]) – det ska bli 9.0",
   'def snitt(lista):\n    return sum(lista) / len(lista)\n\nprint(snitt([8, 9, 10, 9]))', {"expect": "9.0"},
   ["Medelvärde = summan delat med antalet.", "sum(lista) / len(lista)"]),
]})
M.append({"id": "python-ordbocker", "title": "Ordböcker (dict)", "requires": ["python-funktioner"],
 "summary": "`{\"nyckel\": värde}`, `d[\"nyckel\"]`, `d.get(n, standard)`, `for k, v in d.items():`, `in`.",
 "lesson_md": """
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
""", "tasks": [
 T("python-ordbocker-1", 1, "Slå upp", 'roller = {"Kaytho": "Healer", "Bo": "Tank"}. Skriv ut Bos roll: Tank',
   'roller = {"Kaytho": "Healer", "Bo": "Tank"}\nprint(roller["Bo"])', {"expect": "Tank"},
   ['roller["Bo"]', 'print(roller["Bo"])'], 'roller = {"Kaytho": "Healer", "Bo": "Tank"}\n'),
 T("python-ordbocker-2", 2, "Räkna roller", 'Lista: ["Healer", "Tank", "DPS", "DPS", "DPS"]. Räkna hur många av varje med en ordbok och skriv ut: DPS 3, Healer 1, Tank 1 (en rad per roll, i bokstavsordning, som "DPS 3").',
   'roller = ["Healer", "Tank", "DPS", "DPS", "DPS"]\nantal = {}\nfor r in roller:\n    antal[r] = antal.get(r, 0) + 1\nfor r in sorted(antal):\n    print(f"{r} {antal[r]}")',
   {"expect": "DPS 3\nHealer 1\nTank 1"},
   ["antal.get(r, 0) + 1 räknar upp.", "for r in sorted(antal): print(f\"{r} {antal[r]}\")"],
   'roller = ["Healer", "Tank", "DPS", "DPS", "DPS"]\n'),
]})
M.append({"id": "python-filer", "title": "Filer", "requires": ["python-ordbocker"],
 "summary": "`with open(\"fil\", \"w\") as f: f.write(...)`; läs med `\"r\"`; `encoding=\"utf-8\"`; rad för rad med `for rad in f:`.",
 "lesson_md": """
# Filer

Program kan spara och läsa filer:

```python
with open("anteckning.txt", "w", encoding="utf-8") as f:
    f.write("Raid i kväll\\n")

with open("anteckning.txt", encoding="utf-8") as f:
    for rad in f:
        print(rad.strip())
```

- `"w"` skriver (och tömmer filen först), `"a"` lägger till sist, utan = läsa.
- `with` stänger filen själv när blocket är klart.
- `rad.strip()` tar bort radbrytningen i slutet.
- Skriv `encoding="utf-8"` så att å, ä och ö blir rätt.
""", "tasks": [
 T("python-filer-1", 2, "Spara och läs", 'Skriv raderna "Bo 655" och "Anna 612" till filen resultat.txt, läs sedan filen och skriv ut raderna.',
   'with open("resultat.txt", "w", encoding="utf-8") as f:\n    f.write("Bo 655\\n")\n    f.write("Anna 612\\n")\nwith open("resultat.txt", encoding="utf-8") as f:\n    for rad in f:\n        print(rad.strip())',
   {"expect": "Bo 655\nAnna 612"}, ["Glöm inte \\n i slutet av varje rad du skriver.", "Läs med for rad in f: print(rad.strip())"]),
 T("python-filer-2", 3, "Summa ur fil", "Filen poang.txt har ett tal per rad. Läs den och skriv ut summan: Summa 1267",
   'summa = 0\nwith open("poang.txt", encoding="utf-8") as f:\n    for rad in f:\n        summa += int(rad)\nprint(f"Summa {summa}")',
   {"expect": "Summa 1267"}, ["Varje rad är text – gör om med int(rad).", "summa += int(rad)"], files={"poang.txt": "655\n612\n"}),
]})
M.append({"id": "python-fel", "title": "Fel och felhantering", "requires": ["python-filer"],
 "summary": "Läs felmeddelandet nerifrån (typ + rad); `try:` / `except ValueError:`; `raise` för egna fel.",
 "lesson_md": """
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
""", "tasks": [
 T("python-fel-1", 2, "Tåliga tal", 'Gå igenom listan ["10", "x", "7"] och skriv ut talet gånger 2, eller "x är inget tal" när det inte går.',
   'for text in ["10", "x", "7"]:\n    try:\n        print(int(text) * 2)\n    except ValueError:\n        print(f"{text} är inget tal")',
   {"expect": "20\nx är inget tal\n14"}, ["int(\"x\") ger ValueError.", "try: … except ValueError: …"],
   'for text in ["10", "x", "7"]:\n    print(int(text) * 2)\n'),
]})
write_track("python", M)
