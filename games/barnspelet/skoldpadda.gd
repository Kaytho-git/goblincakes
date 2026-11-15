extends Node2D
## Sandens boss (användaren 15 nov): en sur gammal sköldpadda som gömmer sig i skalet mitt i banan och spärrar
## vägen in till gossedjuret. Pojken fyller hinken vid sanddynorna (3 dynor = full hink) och springer hit –
## varje full hink blir en del av ett sandslott bredvid den. Tre delar (9 dynor): sköldpaddan blir glad, går
## till slottet och leker där, och vägen är fri. ("sover" = klar, som de andra bossarna.)

signal somnade

const DELAR := 3
const SLOTT_DX := -230.0  ## där slottet byggs, från sköldpaddans fötter (på pojkens sida)

var bana: Node2D
var platt := false
var trampbar := false
var sover := false
var delar := 0
var _sprite: Sprite2D
var _slott: Sprite2D
var _cell := Vector2.ZERO
var _tid := 0.0
var _framme := false


func _ready() -> void:
	_cell = Bilder.cell("skoldpadda")
	_sprite = Sprite2D.new()
	_sprite.texture = Bilder.bild("skoldpadda", "ledsen")
	_sprite.centered = false
	_sprite.offset = Vector2(-_cell.x / 2.0, -_cell.y)
	add_child(_sprite)
	_slott = Sprite2D.new()
	var sc: Vector2 = Bilder.cell("sandslott")
	_slott.texture = Bilder.bild("sandslott", "slott1")
	_slott.centered = false
	_slott.offset = Vector2(-sc.x / 2.0, -sc.y)
	_slott.position = Vector2(SLOTT_DX, 0)
	_slott.modulate = Color(1, 1, 1, 0.0)
	_slott.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_slott)


func _process(dt: float) -> void:
	_tid += dt
	if sover:
		if _framme:  # leker vid slottet: hoppar och vänder sig
			_sprite.position.y = -absf(sin(_tid * 4.0)) * 10.0
			_sprite.flip_h = fmod(_tid, 3.0) > 1.5
		else:
			_sprite.position.y = -absf(sin(_tid * 8.0)) * 3.0  # går: vaggar
		return
	_sprite.position.x = sin(_tid * 1.1) * 1.5  # muttrar i skalet
	if delar == 0:  # en svag skugga visar var slottet ska stå – tydligare med full hink
		_slott.modulate.a = (0.35 + sin(_tid * 4.0) * 0.15) if bana._hink >= 3 else 0.12


func kompis_x() -> float:
	return position.x + SLOTT_DX


## En full hink: en del av slottet
func fyll() -> void:
	delar += 1
	Spel.ljud("mums")
	_slott.texture = Bilder.bild("sandslott", "slott%d" % delar)
	_slott.modulate = Color(1, 1, 1, 1)
	_slott.scale = Vector2(1.15, 0.85)
	create_tween().tween_property(_slott, "scale", Vector2.ONE, 0.25)
	if delar >= DELAR:
		sover = true
		_sprite.texture = Bilder.bild("skoldpadda", "glad")
		somnade.emit()
		# går bort till slottet (slottet står kvar där det byggdes: flyttas till banan)
		_slott.reparent.call_deferred(get_parent())
		var t := create_tween()
		t.tween_property(self, "position:x", position.x + SLOTT_DX + 70.0, 2.4)
		t.tween_callback(func(): _framme = true)


## Hela kroppen – pojken kan inte gå igenom medan den är sur
func kropp() -> Rect2:
	if sover:
		return Rect2()
	return Rect2(position.x - _cell.x * 0.45, position.y - _cell.y * 0.8, _cell.x * 0.9, _cell.y * 0.8)


func rect() -> Rect2:
	return Rect2()  # gör ingen illa
