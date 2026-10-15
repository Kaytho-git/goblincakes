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
