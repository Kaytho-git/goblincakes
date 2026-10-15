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
