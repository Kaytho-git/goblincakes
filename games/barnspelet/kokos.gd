extends Node2D
## En palm med en kokosnöt: när pojken kommer nära skakar nöten en stund och ramlar sedan.
## Träffar den pojken på vägen ner = "oj". Landar den spricker den och försvinner. Positionen = palmens fot.

const NARA := 120.0
const SKAKA := 0.6
const TYNGD := 2200.0

var bana: Node2D
var platt := false
var trampbar := false
var _not: Sprite2D
var _start := Vector2.ZERO
var _lage := "vantar"  ## vantar, skakar, faller, sprucken
var _tid := 0.0
var _vy := 0.0


func _ready() -> void:
	var palm := Sprite2D.new()
	palm.texture = Bilder.textur("palm")
	var c: Vector2 = Bilder.cell("palm")
	palm.centered = false
	palm.offset = Vector2(-c.x / 2.0, -c.y)
	palm.z_index = -2
	add_child(palm)
	_not = Sprite2D.new()
	_not.texture = Bilder.bild("kokos", "kokos1")
	_start = Vector2(10.0, -c.y * 0.6)  # bland nötterna under bladen
	_not.position = _start
	add_child(_not)


func _physics_process(dt: float) -> void:
	_tid += dt
	match _lage:
		"vantar":
			var dx: float = bana.pojke.position.x - position.x
			if absf(dx) < NARA:
				_lage = "skakar"
				_tid = 0.0
		"skakar":
			_not.position.x = _start.x + (2.0 if fmod(_tid, 0.1) < 0.05 else -2.0)
			if _tid > SKAKA:
				_not.position.x = _start.x
				_lage = "faller"
		"faller":
			_vy += TYNGD * dt
			_not.position.y += _vy * dt
			if bana.fast(global_position + _not.position + Vector2(0, 14)):
				_lage = "sprucken"
				_tid = 0.0
				_not.texture = Bilder.bild("kokos", "kokos2")
		"sprucken":
			if _tid > 0.8:
				_not.visible = false
				set_physics_process(false)


func rect() -> Rect2:
	if _lage != "faller":
		return Rect2()
	var p := global_position + _not.position
	return Rect2(p.x - 14.0, p.y - 14.0, 28.0, 28.0)
