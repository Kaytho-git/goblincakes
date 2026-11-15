extends Node2D
## Fiender som går/kör/ringlar längs marken: racerbilen, ormen. Vänder vid väggar och kanter.
## Positionen = mitt under fötterna/hjulen. Vaknar först när pojken är nära (annars hinner den gå iväg).
## Sätt typ innan den läggs in i banan.

const TYPER := {
	"racerbil": {"fart": 90.0, "halv": 38.0, "hojd": 40.0, "rutor": ["kor1", "kor2"], "fps": 6.0},
	"orm": {"fart": 125.0, "halv": 36.0, "hojd": 24.0, "rutor": ["orm1", "orm2"], "fps": 5.0},
}
const TYNGD := 3800.0

var bana: Node2D
var typ := "racerbil"
var riktning := -1.0
var vaken := false
var platt := false
var trampbar := true
var _vy := 0.0
var _t: Dictionary
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_t = TYPER[typ]
	var blad: String = typ
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Bilder.ramar(blad, {"ga": [_t["rutor"], _t["fps"], true]})
	_sprite.centered = false
	var cell: Vector2 = Bilder.cell(blad)
	_sprite.offset = Vector2(-cell.x / 2.0, -cell.y)
	_sprite.play("ga")
	add_child(_sprite)


func _physics_process(dt: float) -> void:
	if platt:
		return
	if not vaken:
		if absf(bana.pojke.position.x - position.x) > 640.0:
			return
		vaken = true
	var halv: float = _t["halv"]
	var fart: float = _t["fart"]
	var nx: float = position.x + riktning * fart * dt
	var fram: float = nx + riktning * halv
	var vagg: bool = bana.fast(Vector2(fram, position.y - 12.0))
	var kant: bool = bana.fast(Vector2(position.x, position.y + 2.0)) and not bana.fast(Vector2(fram, position.y + 2.0))
	if vagg or kant:
		riktning = -riktning
	else:
		position.x = nx
	_vy = minf(_vy + TYNGD * dt, 950.0)
	var ny := position.y + _vy * dt
	if bana.fast(Vector2(position.x, ny)):
		ny = floorf(ny / bana.RUTA) * bana.RUTA
		_vy = 0.0
	position.y = ny
	_sprite.flip_h = riktning > 0.0  # ritade åt vänster
	if position.y > bana.botten + 200.0:
		queue_free()


func rect() -> Rect2:
	return Rect2(position.x - _t["halv"], position.y - _t["hojd"], _t["halv"] * 2.0, _t["hojd"])


## Pojken trampade på den: platt, sedan borta
func platta() -> void:
	platt = true
	_sprite.stop()
	scale = Vector2(1.15, 0.4)
	await get_tree().create_timer(0.6).timeout
	queue_free()
