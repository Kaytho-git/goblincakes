extends Node2D
## Snöns boss (användaren 15 nov): en ledsen snögubbe som är ensam. Man bygger en kompis åt den – snöklot
## (d i banan) bärs dit ett i taget och lämnas med B där kompisen ska stå (till vänster om snögubben).
## Kloten hamnar rätt av sig själva: stort, mellan, huvud. När kompisen är klar blir snögubben glad och
## buren går att öppna. Den gör ingen illa, men går inte att gå igenom medan den är ledsen.
## ("sover" = klar – samma namn som djungelns boss, så banan behandlar dem lika.)

signal somnade

const DELAR := 3
const KOMPIS_DX := -150.0  ## där kompisen byggs, från snögubbens fötter
const ZOOM := 0.8          ## kameran zoomar ut här (plats att bygga)

var bana: Node2D
var platt := false
var trampbar := false
var sover := false
var delar := 0
var _sprite: Sprite2D
var _kompis: Sprite2D
var _cell := Vector2.ZERO
var _tid := 0.0


func _ready() -> void:
	_cell = Bilder.cell("snogubbe")
	_sprite = Sprite2D.new()
	_sprite.texture = Bilder.bild("snogubbe", "ledsen")
	_sprite.centered = false
	_sprite.offset = Vector2(-_cell.x / 2.0, -_cell.y)
	add_child(_sprite)
	_kompis = Sprite2D.new()
	var kc: Vector2 = Bilder.cell("kompis")
	_kompis.texture = Bilder.bild("kompis", "kompis1")
	_kompis.centered = false
	_kompis.offset = Vector2(-kc.x / 2.0, -kc.y)
	_kompis.position = Vector2(KOMPIS_DX, 0)
	_kompis.modulate = Color(1, 1, 1, 0.0)
	_kompis.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_kompis)


func _process(dt: float) -> void:
	_tid += dt
	if sover:  # glad: hoppar lite
		_sprite.position.y = -absf(sin(_tid * 5.0)) * 8.0
		_kompis.position.y = -absf(sin(_tid * 5.0 + 1.2)) * 6.0
		return
	_sprite.rotation = sin(_tid * 1.3) * 0.03  # gungar sorgset
	if delar == 0:
		# en svag skugga av första klotet visar var kompisen ska stå – tydligare när pojken bär ett klot
		var bar: bool = bana._bar != null
		_kompis.modulate.a = (0.35 + sin(_tid * 4.0) * 0.15) if bar else 0.12


func kompis_x() -> float:
	return position.x + KOMPIS_DX


## Ett snöklot lämnat vid kompisen
func lamna() -> void:
	delar += 1
	Spel.ljud("mums")
	_kompis.texture = Bilder.bild("kompis", "kompis%d" % delar)
	_kompis.modulate = Color(1, 1, 1, 1)
	var t := create_tween()
	_kompis.scale = Vector2(1.15, 0.85)
	t.tween_property(_kompis, "scale", Vector2.ONE, 0.25)
	if delar >= DELAR:
		sover = true
		_sprite.rotation = 0.0
		_sprite.texture = Bilder.bild("snogubbe", "glad")
		somnade.emit()


## Hela kroppen – pojken kan inte gå igenom medan den är ledsen
func kropp() -> Rect2:
	return Rect2(position.x - _cell.x * 0.35, position.y - _cell.y * 0.9, _cell.x * 0.7, _cell.y * 0.9)


func rect() -> Rect2:
	return Rect2()  # gör ingen illa
