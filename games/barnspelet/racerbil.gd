extends Node2D
## Racerbilen: kör fram och tillbaka, vänder vid väggar och kanter. Positionen = mitt under hjulen.
## Vaknar först när pojken är nära (som i den sortens spel – annars hinner den köra iväg).

const FART := 90.0
const TYNGD := 3800.0
const HALV := 38.0
const HOJD := 40.0

var bana: Node2D
var riktning := -1.0
var vaken := false
var platt := false
var _vy := 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Bilder.ramar("racerbil", {"kor": [["kor1", "kor2"], 6.0, true]})
	_sprite.centered = false
	var cell: Vector2 = Bilder.cell("racerbil")
	_sprite.offset = Vector2(-cell.x / 2.0, -cell.y)
	_sprite.play("kor")
	add_child(_sprite)


func _physics_process(dt: float) -> void:
	if platt:
		return
	if not vaken:
		if absf(bana.pojke.position.x - position.x) > 640.0:
			return
		vaken = true
	var nx := position.x + riktning * FART * dt
	var fram := nx + riktning * HALV
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
	_sprite.flip_h = riktning > 0.0  # ritad åt vänster
	if position.y > bana.botten + 200.0:
		queue_free()


func rect() -> Rect2:
	return Rect2(position.x - HALV, position.y - HOJD, HALV * 2.0, HOJD)


## Pojken trampade på den: platt, sedan borta
func platta() -> void:
	platt = true
	_sprite.stop()
	scale = Vector2(1.15, 0.4)
	await get_tree().create_timer(0.6).timeout
	queue_free()
