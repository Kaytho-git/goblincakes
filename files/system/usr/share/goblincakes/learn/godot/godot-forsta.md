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
