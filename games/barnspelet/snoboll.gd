extends Node2D
## En snöboll som rullar (ur en snöhög): fart åt ett håll, fortare nerför backar, långsammare uppför.
## Hoppa över den eller trampa på den (användaren 15 nov) – den spricker. Spricker mot en vägg; försvinner ner i en grop.

const FART := 170.0    ## på plan mark
const BACKE := 520.0   ## extra fart per sekund nerför (mindre uppför)
const MAX := 480.0
const HALV := 22.0

var bana: Node2D
var riktning := -1.0
var blad := "snoboll"  ## tumbleweed i Sanden (bilderna <blad>1, <blad>2)
var platt := false
var trampbar := true
var raknas := false  ## inte med i målets räkning (de kommer hela tiden)
var _vx := 0.0
var _vy := 0.0
var _liv := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	_vx = riktning * FART
	_sprite = Sprite2D.new()
	_sprite.texture = Bilder.bild(blad, blad + "1")
	_sprite.position = Vector2(0, -HALV)
	add_child(_sprite)


func _physics_process(dt: float) -> void:
	if platt:
		return
	_liv += dt
	var b: int = bana.backe(position)
	if b != 0:
		_vx += -b * BACKE * dt  # backe upp åt höger (1) = nerför åt vänster
	else:
		_vx = move_toward(_vx, signf(_vx) * FART, 200.0 * dt)
	_vx = clampf(_vx, -MAX, MAX)
	var nx := position.x + _vx * dt
	if bana.vagg(Vector2(nx + signf(_vx) * HALV, position.y - 30.0)):
		_spricka()
		return
	position.x = nx
	var m: Array = bana.pa_marken(position, _vy, dt)
	position = m[0]
	_vy = m[1]
	_sprite.rotation += _vx * dt / HALV
	if position.y > bana.botten + 100.0 or _liv > 14.0 or absf(bana.pojke.position.x - position.x) > 1400.0:
		queue_free()


func _spricka() -> void:
	platt = true
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.5, 0.3), 0.15)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)


func rect() -> Rect2:
	return Rect2(position.x - HALV + 4.0, position.y - HALV * 2.0 + 4.0, HALV * 2.0 - 8.0, HALV * 2.0 - 4.0)


func platta() -> void:
	if not platt:
		_spricka()
