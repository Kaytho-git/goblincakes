"""Godot (GDScript): the user's main.gd is a node script, run by sandbox/godotrun.py in Godot
without a window. frames.txt = how many frames _process runs (60 = 1 second), inputs.txt =
keys pressed/released on given frames. Code below is written with 4 spaces and turned into tabs
(Godot's own style, and what Tab gives in the editor for .gd files)."""
import re

from lib import write_track, T


def G(code):
    """4-space indentation → tabs."""
    return "\n".join(re.sub(r"^((?:    )+)", lambda m: "\t" * (len(m.group(1)) // 4), line)
                     for line in code.strip("\n").splitlines()) + "\n"


def GT(id, level, title, prompt, solution, check, hints, starter="", frames=None, inputs=None):
    files = {}
    if frames:
        files["frames.txt"] = f"{frames}\n"
    if inputs:
        files["inputs.txt"] = "\n".join(inputs) + "\n"
    return T(id, level, title, prompt, G(solution), check, hints, G(starter) if starter else "", files or None)


START = """
extends Node

func _ready():
    pass
"""

M = []
M.append({"id": "godot-forsta", "title": "Första skriptet i Godot", "requires": [],
 "summary": "Skript sitter på noder: `extends Node`, `func _ready():` körs när noden kommer in i spelet; `print()`; `var hp := 100` (typen gissas) eller `var hp: int = 100`; `const`; text med `\"%s har %d HP\" % [namn, hp]`; indrag med Tab.",
 "lesson_md": """
# Första skriptet i Godot

Ett spel i Godot är byggt av **noder** – en spelare, en kamera, en ljudkälla, en text. Noderna
sitter i ett träd (en **scen**). Ett **skript** ger en nod beteende. Varje skript börjar med vilken
sorts nod det sitter på:

```gdscript
extends Node

func _ready():
	print("Hej från Godot!")
```

- `func _ready():` körs **en gång**, när noden kommer in i spelet. Allt som hör till funktionen
  skrivs med **indrag** (Tab) – precis som i Python.
- `print()` skriver i Godots utdatafönster (här: under din kod).

## Variabler

```gdscript
var namn := "Kaytho"        # := gissar typen (här String)
var hp: int = 100           # eller skriv typen själv
var fart := 2.5             # float = decimaltal
var levande := true         # bool
const MAX_HP := 100         # en konstant ändras aldrig
```

Text och tal sätts ihop med `%`: `"%s har %d HP" % [namn, hp]` (`%s` = text, `%d` = heltal,
`%.1f` = decimaltal med en decimal). Eller `print(namn, " har ", hp, " HP")` – print sätter ihop
allt den får.

> I Godot-editorn skapar du en scen, lägger till en nod och klickar på skriptikonen för att ge
> den ett skript. Här i övningen är din kod skriptet på en nod som heter **Main**.
""", "tasks": [
 GT("godot-forsta-1", 1, "Hej Azeroth", "Skriv ut texten Hej från Godot! när noden startar.",
    START.replace("pass", 'print("Hej från Godot!")'), {"expect": "Hej från Godot!"},
    ["Byt pass mot en print-rad.", 'print("Hej från Godot!") – med Tab före.'], START),
 GT("godot-forsta-2", 1, "Skada", 'Skapa variablerna namn = "Kaytho", hp = 100 och skada = 35. Räkna ut hur mycket HP som är kvar och skriv: Kaytho har 65 HP kvar',
    """
extends Node

func _ready():
    var namn := "Kaytho"
    var hp := 100
    var skada := 35
    hp -= skada
    print("%s har %d HP kvar" % [namn, hp])
""", {"expect": "Kaytho har 65 HP kvar"},
    ["hp -= skada drar av skadan.", 'print("%s har %d HP kvar" % [namn, hp])'], START),
 GT("godot-forsta-3", 2, "Fart i decimaler", "Spelaren går 2.5 meter per steg och tar 7 steg. Skriv ut: Sträcka: 17.5 m – räkna med variabler, inte för hand.",
    """
extends Node

const STEG_LANGD := 2.5

func _ready():
    var steg := 7
    var stracka := STEG_LANGD * steg
    print("Sträcka: %.1f m" % stracka)
""", {"expect": "Sträcka: 17.5 m"},
    ["Decimaltal × heltal blir ett decimaltal (float).", '%.1f skriver en decimal: print("Sträcka: %.1f m" % stracka)'], START),
]})

M.append({"id": "godot-villkor", "title": "Villkor och loopar", "requires": ["godot-forsta"],
 "summary": "`if … :`, `elif`, `else`; `and`/`or`/`not`; `for i in range(1, 4):`, `for sak in lista:`, `while`; `match värde:` med `_:` som \"allt annat\".",
 "lesson_md": """
# Villkor och loopar

```gdscript
if hp <= 0:
	print("Död")
elif hp < 30:
	print("Låg hälsa!")
else:
	print("Mår bra")
```

Jämförelser: `==`, `!=`, `<`, `<=`, `>`, `>=`. Kombinera med `and`, `or`, `not`.

## Loopar

```gdscript
for i in range(3):          # 0, 1, 2
	print(i)
for i in range(1, 4):       # 1, 2, 3
	print("Våg ", i)
for namn in ["Bo", "Ann"]:  # varje sak i en lista
	print(namn)
while hp > 0:
	hp -= 10
```

## match – många val

```gdscript
match klass:
	"mage":
		print("Frostbolt")
	"warrior":
		print("Charge")
	_:
		print("Attack")    # _ = allt annat
```
""", "tasks": [
 GT("godot-villkor-1", 1, "Hälsomätare", "Sätt hp = 25. Skriv Död om hp är 0 eller mindre, Låg hälsa! om hp är under 30, annars Mår bra.",
    """
extends Node

func _ready():
    var hp := 25
    if hp <= 0:
        print("Död")
    elif hp < 30:
        print("Låg hälsa!")
    else:
        print("Mår bra")
""", {"expect": "Låg hälsa!"},
    ["if, elif och else – i den ordningen.", "Glöm inte kolon efter villkoren och ett extra indrag under dem."],
    "extends Node\n\nfunc _ready():\n    var hp := 25\n"),
 GT("godot-villkor-2", 1, "Vågor", "Skriv ut Våg 1, Våg 2 och Våg 3 på var sin rad med en for-loop.",
    """
extends Node

func _ready():
    for i in range(1, 4):
        print("Våg ", i)
""", {"expect": "Våg 1\nVåg 2\nVåg 3"},
    ["range(1, 4) ger 1, 2, 3.", 'print("Våg ", i)'], START),
 GT("godot-villkor-3", 2, "Klassens förmåga", 'Sätt klass = "mage". Använd match: mage → Frostbolt, warrior → Charge, allt annat → Attack. Prova sedan att byta klass.',
    """
extends Node

func _ready():
    var klass := "mage"
    match klass:
        "mage":
            print("Frostbolt")
        "warrior":
            print("Charge")
        _:
            print("Attack")
""", {"expect": "Frostbolt"},
    ["match klass: och sedan ett fall per rad med kolon.", "_: fångar allt annat."], START),
 GT("godot-villkor-4", 3, "Nedräkning", "Räkna ned med en while-loop från 3 till 1 (en rad var) och skriv sedan Pull!",
    """
extends Node

func _ready():
    var n := 3
    while n > 0:
        print(n)
        n -= 1
    print("Pull!")
""", {"expect": "3\n2\n1\nPull!"},
    ["while n > 0: och dra av 1 varje varv.", "print(\"Pull!\") ska stå efter loopen – utan extra indrag."], START),
]})

M.append({"id": "godot-funktioner", "title": "Funktioner, arrayer och ordböcker", "requires": ["godot-villkor"],
 "summary": "`func skada(bas: int, krit: bool) -> int:` + `return`; `Array` (`append`, `size()`, `[i]`, `has`, `sort()`), `Dictionary` (`{\"Bo\": 10}`, `d[\"Bo\"]`, `keys()`, `has()`).",
 "lesson_md": """
# Funktioner, arrayer och ordböcker

## Egna funktioner

```gdscript
func skada(bas: int, kritisk: bool) -> int:
	if kritisk:
		return bas * 2
	return bas
```

`-> int` säger vad funktionen ger tillbaka. Anropa: `print(skada(10, true))`.

## Arrayer – listor

```gdscript
var loot := ["Svärd", "Sköld"]
loot.append("Dryck")      # lägg till sist
print(loot.size())        # 3
print(loot[0])            # Svärd (första = 0)
if loot.has("Sköld"):
	print("Har sköld")
```

## Ordböcker (Dictionary) – namn → värde

```gdscript
var poang := {"Kaytho": 10, "Bo": 25}
poang["Ann"] = 18
for namn in poang:         # går igenom nycklarna
	print(namn, ": ", poang[namn])
```
""", "tasks": [
 GT("godot-funktioner-1", 1, "Dubbel skada", "Skriv funktionen dubbel(x: int) -> int som ger tillbaka x gånger två, och skriv ut dubbel(21).",
    """
extends Node

func dubbel(x: int) -> int:
    return x * 2

func _ready():
    print(dubbel(21))
""", {"expect": "42"},
    ["func dubbel(x: int) -> int: och sedan return x * 2.", "Funktionen ska stå utanför _ready, på samma nivå."], START),
 GT("godot-funktioner-2", 2, "Lootlistan", 'Skapa listan loot = ["Svärd", "Sköld", "Dryck"], lägg till "Guld", skriv ut hur många saker det är och sedan varje sak på en egen rad.',
    """
extends Node

func _ready():
    var loot := ["Svärd", "Sköld", "Dryck"]
    loot.append("Guld")
    print(loot.size())
    for sak in loot:
        print(sak)
""", {"expect": "4\nSvärd\nSköld\nDryck\nGuld"},
    ['loot.append("Guld")', "print(loot.size()) och sedan for sak in loot:"], START),
 GT("godot-funktioner-3", 3, "Vem vann?", 'Poängen är {"Kaytho": 10, "Bo": 25, "Ann": 18}. Hitta den med flest poäng med en loop och skriv: Bo vann med 25',
    """
extends Node

func _ready():
    var poang := {"Kaytho": 10, "Bo": 25, "Ann": 18}
    var bast := ""
    var mest := -1
    for namn in poang:
        if poang[namn] > mest:
            mest = poang[namn]
            bast = namn
    print("%s vann med %d" % [bast, mest])
""", {"expect": "Bo vann med 25"},
    ["Spara bästa namnet och poängen i två variabler och jämför i loopen.", "for namn in poang: ger nycklarna; poang[namn] ger poängen."],
    'extends Node\n\nfunc _ready():\n    var poang := {"Kaytho": 10, "Bo": 25, "Ann": 18}\n'),
]})

M.append({"id": "godot-noder", "title": "Noder och scenträdet", "requires": ["godot-funktioner"],
 "summary": "`Node2D.new()`, `.name`, `.position = Vector2(x, y)`, `add_child(nod)`; `get_node(\"Namn\")` eller `$Namn`; `get_children()`, `get_child_count()`; `remove_child` + `queue_free()` tar bort.",
 "lesson_md": """
# Noder och scenträdet

Allt i spelet är noder i ett träd. **Node2D** är en nod med en plats på skärmen (`position`).
I editorn lägger du till noder med **+** – i kod gör du så här:

```gdscript
extends Node2D

func _ready():
	var spelare := Node2D.new()
	spelare.name = "Spelare"
	spelare.position = Vector2(100, 50)   # x åt höger, y NEDÅT
	add_child(spelare)                     # nu finns den i trädet
	print($Spelare.position)               # (100.0, 50.0)
```

- `$Spelare` är kortform för `get_node("Spelare")` – barnet som heter Spelare.
- `get_children()` ger alla barn, `get_child_count()` hur många.
- `queue_free()` tar bort en nod (när bildrutan är klar). Vill du att den försvinner ur
  listan direkt: `remove_child(nod)` först.
- **Vector2** är en punkt eller riktning: `Vector2(3, 4).length()` = 5.

> I en riktig scen gör du oftast noderna i editorn och skriver `@onready var spelare = $Spelare`
> högst upp, så finns de redan när `_ready` körs.
""", "tasks": [
 GT("godot-noder-1", 1, "Spelaren på plats", "Skapa en Node2D som heter Spelare, sätt den på position (100, 50), lägg till den som barn och skriv ut $Spelare.position.",
    """
extends Node2D

func _ready():
    var spelare := Node2D.new()
    spelare.name = "Spelare"
    spelare.position = Vector2(100, 50)
    add_child(spelare)
    print($Spelare.position)
""", {"expect": "(100.0, 50.0)"},
    ["Node2D.new() skapar noden; add_child(spelare) lägger in den i trädet.", "print($Spelare.position) – $Spelare fungerar först efter add_child."],
    "extends Node2D\n\nfunc _ready():\n    pass\n"),
 GT("godot-noder-2", 2, "Tre fiender", "Skapa tre Node2D i en loop: Fiende1, Fiende2, Fiende3 med x = 64, 128, 192 (y = 0). Skriv sedan antalet barn och varje barns namn och x på var sin rad, t.ex. Fiende1 64",
    """
extends Node2D

func _ready():
    for i in range(1, 4):
        var f := Node2D.new()
        f.name = "Fiende%d" % i
        f.position = Vector2(64 * i, 0)
        add_child(f)
    print(get_child_count())
    for barn in get_children():
        print(barn.name, " ", int(barn.position.x))
""", {"expect": "3\nFiende1 64\nFiende2 128\nFiende3 192"},
    ['"Fiende%d" % i ger namnet; Vector2(64 * i, 0) platsen.', "int(barn.position.x) skriver 64 i stället för 64.0."],
    "extends Node2D\n\nfunc _ready():\n    pass\n"),
 GT("godot-noder-3", 3, "Fiende besegrad", "Skapa Fiende1–3 som förra uppgiften (namnen räcker), ta sedan bort Fiende2 (remove_child + queue_free) och skriv antalet barn och de namn som är kvar.",
    """
extends Node2D

func _ready():
    for i in range(1, 4):
        var f := Node2D.new()
        f.name = "Fiende%d" % i
        add_child(f)
    var dod := $Fiende2
    remove_child(dod)
    dod.queue_free()
    print(get_child_count())
    for barn in get_children():
        print(barn.name)
""", {"expect": "2\nFiende1\nFiende3"},
    ["Hämta noden med $Fiende2 innan du tar bort den.", "remove_child(dod) tar ut den ur listan direkt; dod.queue_free() raderar den sedan."],
    "extends Node2D\n\nfunc _ready():\n    pass\n"),
]})

M.append({"id": "godot-process", "title": "_process och rörelse", "requires": ["godot-noder"],
 "summary": "`func _process(delta):` körs varje bildruta; `delta` = sekunder sedan förra (1/60); `position.x += fart * delta` = pixlar per sekund oavsett bildfrekvens; `Vector2(1, 1).normalized()` för jämn fart snett.",
 "lesson_md": """
# _process och rörelse

`_ready` körs en gång. `_process(delta)` körs **varje bildruta** – oftast 60 gånger per sekund.
`delta` är hur lång tid som gått sedan förra bildrutan (ungefär 0.0167 sekunder).

```gdscript
extends Node2D

var fart := 120.0      # pixlar per sekund

func _process(delta):
	position.x += fart * delta
```

Multiplicera alltid med `delta`! Annars rör sig spelet snabbare på en dator med 144 Hz än på en
med 60 Hz.

## Gå snett

```gdscript
var riktning := Vector2(1, 1).normalized()   # längd 1 → samma fart snett som rakt
position += riktning * fart * delta
```

## Räkna bildrutor

Övningen kör ett bestämt antal bildrutor (uppgiften säger hur många) med exakt 60 bilder per
sekund. Vill du skriva något vid en viss tid kan du räkna själv:

```gdscript
var bilder := 0

func _process(delta):
	bilder += 1
	if bilder == 60:       # efter en sekund
		print(int(round(position.x)))
```
""", "tasks": [
 GT("godot-process-1", 1, "En sekund åt höger", "Flytta noden 120 pixlar per sekund åt höger. Efter 60 bildrutor (en sekund): skriv x = och x-läget avrundat till heltal. Övningen kör 60 bildrutor.",
    """
extends Node2D

var fart := 120.0
var bilder := 0

func _process(delta):
    position.x += fart * delta
    bilder += 1
    if bilder == 60:
        print("x = ", int(round(position.x)))
""", {"expect": "x = 120"},
    ["position.x += fart * delta flyttar lite varje bildruta.", "Räkna bildrutor i en variabel och skriv när den är 60: int(round(position.x))."],
    "extends Node2D\n\nvar fart := 120.0\n\nfunc _process(delta):\n    pass\n", frames=60),
 GT("godot-process-2", 2, "Snett nedåt", "Rör noden snett åt höger och nedåt (riktning (1, 1)) med farten 100 pixlar per sekund i en halv sekund (30 bildrutor). Skriv sedan position.round(). Övningen kör 30 bildrutor.",
    """
extends Node2D

var fart := 100.0
var riktning := Vector2(1, 1).normalized()
var bilder := 0

func _process(delta):
    position += riktning * fart * delta
    bilder += 1
    if bilder == 30:
        print(position.round())
""", {"expect": "(35.0, 35.0)"},
    ["Vector2(1, 1).normalized() ger riktningen med längden 1.", "position += riktning * fart * delta; skriv position.round() vid bildruta 30."],
    "extends Node2D\n\nvar fart := 100.0\n\nfunc _process(delta):\n    pass\n", frames=30),
 GT("godot-process-3", 3, "Studsa", "Noden börjar på x = 0 och rör sig 300 pixlar per sekund. När x blir större än 200 ska den vända (fart = -fart), och när x blir mindre än 0 vända igen. Skriv x avrundat efter 60 bildrutor.",
    """
extends Node2D

var fart := 300.0
var bilder := 0

func _process(delta):
    position.x += fart * delta
    if position.x > 200 or position.x < 0:
        fart = -fart
    bilder += 1
    if bilder == 60:
        print(int(round(position.x)))
""", {"expect": "110"},
    ["Byt tecken på farten när noden passerar en kant: fart = -fart.", "Två villkor med or: position.x > 200 or position.x < 0."],
    "extends Node2D\n\nvar fart := 300.0\n\nfunc _process(delta):\n    pass\n", frames=60),
]})

M.append({"id": "godot-input", "title": "Tangenter och styrning", "requires": ["godot-process"],
 "summary": "Handlingar (actions) i Project → Project Settings → Input Map; `Input.is_action_pressed(\"ui_right\")`, `is_action_just_pressed` (bara första bildrutan), `Input.get_axis(\"ui_left\", \"ui_right\")` (−1…1), `Input.get_vector(…)` för fyra riktningar.",
 "lesson_md": """
# Tangenter och styrning

Godot tänker i **handlingar** (actions) i stället för tangenter: `ui_left`, `ui_right`, `ui_up`,
`ui_down` och `ui_accept` (Enter/mellanslag) finns från början. Egna gör du i
**Project → Project Settings → Input Map** (t.ex. "hoppa" = mellanslag + A på handkontrollen).

```gdscript
func _process(delta):
	if Input.is_action_pressed("ui_right"):      # hålls nere
		position.x += 200 * delta
	if Input.is_action_just_pressed("ui_accept"):  # bara bildrutan den trycktes
		print("Hopp!")
```

Kortare: `Input.get_axis("ui_left", "ui_right")` ger −1 (vänster), 0 eller 1 (höger).
För fyra riktningar: `Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")` ger en Vector2.

> I övningen trycker en låtsasspelare på tangenterna vid bestämda bildrutor – uppgiften säger när.
""", "tasks": [
 GT("godot-input-1", 1, "Hoppa", "Skriv Hopp! varje gång ui_accept trycks ned (en gång per tryck, inte varje bildruta den hålls). Låtsasspelaren trycker vid bildruta 10 och 40 och håller några bildrutor varje gång.",
    """
extends Node2D

func _process(delta):
    if Input.is_action_just_pressed("ui_accept"):
        print("Hopp!")
""", {"expect": "Hopp!\nHopp!"},
    ["is_action_pressed är sant så länge den hålls – du vill ha is_action_just_pressed.", 'if Input.is_action_just_pressed("ui_accept"): print("Hopp!")'],
    "extends Node2D\n\nfunc _process(delta):\n    pass\n", frames=60,
    inputs=["10 press ui_accept", "14 release ui_accept", "40 press ui_accept", "45 release ui_accept"]),
 GT("godot-input-2", 2, "Gå med pilarna", "Låt noden gå 200 pixlar per sekund åt det håll Input.get_axis(\"ui_left\", \"ui_right\") säger. Låtsasspelaren håller höger i en halv sekund. Skriv x avrundat vid bildruta 60.",
    """
extends Node2D

var fart := 200.0
var bilder := 0

func _process(delta):
    position.x += Input.get_axis("ui_left", "ui_right") * fart * delta
    bilder += 1
    if bilder == 60:
        print(int(round(position.x)))
""", {"expect": "100"},
    ["get_axis ger 1 när höger hålls, annars 0.", "position.x += Input.get_axis(\"ui_left\", \"ui_right\") * fart * delta"],
    "extends Node2D\n\nvar fart := 200.0\nvar bilder := 0\n\nfunc _process(delta):\n    pass\n", frames=60,
    inputs=["1 press ui_right", "31 release ui_right"]),
 GT("godot-input-3", 3, "Fyra riktningar", "Styr noden i alla fyra riktningar med Input.get_vector och farten 150. Låtsasspelaren håller höger och ned samtidigt i 40 bildrutor. Skriv position.round() vid bildruta 60.",
    """
extends Node2D

var fart := 150.0
var bilder := 0

func _process(delta):
    var riktning := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    position += riktning * fart * delta
    bilder += 1
    if bilder == 60:
        print(position.round())
""", {"expect": "(71.0, 71.0)"},
    ['Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") – i den ordningen.', "get_vector är redan normaliserad: snett går lika fort som rakt."],
    "extends Node2D\n\nvar fart := 150.0\nvar bilder := 0\n\nfunc _process(delta):\n    pass\n", frames=60,
    inputs=["1 press ui_right", "1 press ui_down", "41 release ui_right", "41 release ui_down"]),
]})

M.append({"id": "godot-signaler", "title": "Signaler och Timer", "requires": ["godot-input"],
 "summary": "`signal traffad(skada: int)`, `traffad.connect(_on_traffad)`, `traffad.emit(12)`; inbyggda signaler som `Timer.timeout` och `Button.pressed`; en nod säger till, andra lyssnar – utan att känna varandra.",
 "lesson_md": """
# Signaler och Timer

En **signal** är ett meddelande: "något hände". Den som skickar behöver inte veta vem som lyssnar
– det gör spelet lätt att bygga om.

```gdscript
signal traffad(skada: int)

func _ready():
	traffad.connect(_on_traffad)   # lyssna
	traffad.emit(12)               # skicka

func _on_traffad(skada: int):
	print("Aj! -", skada)
```

Noder har inbyggda signaler: knappar har `pressed`, en **Timer** har `timeout`:

```gdscript
var t := Timer.new()
t.wait_time = 0.5      # sekunder
t.one_shot = true      # bara en gång
t.timeout.connect(_on_pling)
add_child(t)
t.start()
```

> I editorn kopplar du signaler i fliken **Node → Signals** – Godot skriver då
> `_on_…`-funktionen åt dig.
""", "tasks": [
 GT("godot-signaler-1", 1, "Träffad!", "Gör en signal traffad(skada: int), koppla den till en funktion som skriver Aj! -<skada>, och skicka den med 12.",
    """
extends Node

signal traffad(skada: int)

func _ready():
    traffad.connect(_on_traffad)
    traffad.emit(12)

func _on_traffad(skada: int):
    print("Aj! -", skada)
""", {"expect": "Aj! -12"},
    ["signal traffad(skada: int) står högst upp, under extends.", "connect först, sedan emit(12)."], START),
 GT("godot-signaler-2", 2, "Pling efter en halv sekund", "Skapa en Timer som efter 0.5 sekunder (en gång) skriver Pling! Övningen kör 60 bildrutor.",
    """
extends Node

func _ready():
    var t := Timer.new()
    t.wait_time = 0.5
    t.one_shot = true
    t.timeout.connect(_on_pling)
    add_child(t)
    t.start()

func _on_pling():
    print("Pling!")
""", {"expect": "Pling!"},
    ["Timer.new(), wait_time = 0.5, one_shot = true.", "Koppla t.timeout till en egen funktion, add_child(t) och t.start()."], START, frames=60),
 GT("godot-signaler-3", 3, "Game over", "Gör signalen dog. Skriv funktionen ta_skada(n) som drar n från hp (start 100), skriver HP <värde> och skickar dog när hp blir 0 eller mindre. Koppla dog till en funktion som skriver Game over. Anropa ta_skada(40) tre gånger.",
    """
extends Node

signal dog

var hp := 100

func _ready():
    dog.connect(_on_dog)
    for i in range(3):
        ta_skada(40)

func ta_skada(n: int):
    hp = max(hp - n, 0)
    print("HP ", hp)
    if hp <= 0:
        dog.emit()

func _on_dog():
    print("Game over")
""", {"expect": "HP 60\nHP 20\nHP 0\nGame over"},
    ["max(hp - n, 0) gör att HP inte blir negativt.", "Kolla hp <= 0 efter att du skrivit ut HP, och skicka då dog.emit()."], START),
]})

M.append({"id": "godot-spel", "title": "Ett litet spel: samla mynt", "requires": ["godot-signaler"],
 "summary": "Spelregler i `_process`: avstånd med `position.distance_to(mynt) < 16`, ta bort ur listan medan man går baklänges (`for i in range(lista.size() - 1, -1, -1)`), poäng, signal när allt är klart.",
 "lesson_md": """
# Ett litet spel: samla mynt

Nu sätter vi ihop allt: rörelse med tangenter, en lista med mynt, poäng och en signal när spelet
är vunnet.

```gdscript
var mynt := [Vector2(50, 0), Vector2(100, 0)]

func _process(delta):
	position.x += Input.get_axis("ui_left", "ui_right") * 120 * delta
	for i in range(mynt.size() - 1, -1, -1):        # baklänges: säkert att ta bort
		if position.distance_to(mynt[i]) < 16:
			mynt.remove_at(i)
			poang += 1
```

- `distance_to` ger avståndet mellan två punkter.
- Ta bort ur en lista medan du går **baklänges** – annars hoppar loopen över saker.
- I ett riktigt spel är mynten egna noder med en **Area2D** som skickar signalen
  `body_entered` när spelaren nuddar dem. Logiken är densamma.
""", "tasks": [
 GT("godot-spel-1", 2, "Poäng och vinst", "Spelaren går åt höger med get_axis (fart 120). Mynten ligger på x = 50, 100 och 150 (y = 0). Plocka ett mynt när avståndet är under 16 och skriv Mynt! Poäng: <poäng>. När alla är tagna: skicka signalen vann och skriv Du vann! (bara en gång). Låtsasspelaren håller höger i 2 sekunder.",
    """
extends Node2D

signal vann

var mynt := [Vector2(50, 0), Vector2(100, 0), Vector2(150, 0)]
var poang := 0
var klar := false

func _ready():
    vann.connect(_on_vann)

func _process(delta):
    position.x += Input.get_axis("ui_left", "ui_right") * 120 * delta
    for i in range(mynt.size() - 1, -1, -1):
        if position.distance_to(mynt[i]) < 16:
            mynt.remove_at(i)
            poang += 1
            print("Mynt! Poäng: ", poang)
    if mynt.is_empty() and not klar:
        klar = true
        vann.emit()

func _on_vann():
    print("Du vann!")
""", {"expect": "Mynt! Poäng: 1\nMynt! Poäng: 2\nMynt! Poäng: 3\nDu vann!"},
    ["Gå igenom mynten baklänges och använd position.distance_to(mynt[i]) < 16.", "En variabel klar ser till att vann bara skickas en gång."],
    'extends Node2D\n\nsignal vann\n\nvar mynt := [Vector2(50, 0), Vector2(100, 0), Vector2(150, 0)]\nvar poang := 0\n\nfunc _process(delta):\n    pass\n',
    frames=150, inputs=["1 press ui_right", "121 release ui_right"]),
 GT("godot-spel-2", 3, "Fienden jagar", "En fiende (en Node2D som barn, start (200, 0)) går mot spelaren med 60 pixlar per sekund (move_toward). Spelaren står still på (0, 0). När fienden är närmare än 10 pixlar: skriv Fångad! och sekunderna det tog med en decimal (t.ex. Fångad! 3.2 s) – bara en gång.",
    """
extends Node2D

var fiende := Node2D.new()
var tid := 0.0
var fangad := false

func _ready():
    fiende.position = Vector2(200, 0)
    add_child(fiende)

func _process(delta):
    if fangad:
        return
    tid += delta
    fiende.position = fiende.position.move_toward(Vector2.ZERO, 60 * delta)
    if fiende.position.distance_to(Vector2.ZERO) < 10:
        fangad = true
        print("Fångad! %.1f s" % tid)
""", {"expect": "Fångad! 3.2 s"},
    ["move_toward(mål, steg) flyttar högst steg pixlar mot målet.", "Räkna tiden med tid += delta och skriv med \"%.1f\" % tid."],
    "extends Node2D\n\nfunc _process(delta):\n    pass\n", frames=240),
]})

write_track("godot", M)
