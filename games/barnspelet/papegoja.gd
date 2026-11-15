extends Node2D
## Plyschpapegojan: flyger fram och tillbaka (±3 rutor) i vågor. Går att trampa på.

const FART := 80.0
const VIDD := 144.0
const VAG := 26.0

var bana: Node2D
var platt := false
var trampbar := true
var _hem := Vector2.ZERO
var _riktning := -1.0
var _t := 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_hem = position
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Bilder.ramar("papegoja", {"flyg": [["papegoja1", "papegoja2"], 7.0, true]})
	_sprite.play("flyg")
	add_child(_sprite)


func _physics_process(dt: float) -> void:
	if platt:
		position.y += 500.0 * dt
		return
	_t += dt
	position.x += _riktning * FART * dt
	if absf(position.x - _hem.x) > VIDD:
		position.x = _hem.x + signf(position.x - _hem.x) * VIDD
		_riktning = -_riktning
	position.y = _hem.y + sin(_t * 3.6) * VAG
	_sprite.flip_h = _riktning > 0.0


func rect() -> Rect2:
	return Rect2(position.x - 22.0, position.y - 18.0, 44.0, 36.0)


func platta() -> void:
	platt = true
	_sprite.stop()
	_sprite.flip_v = true
	await get_tree().create_timer(1.2).timeout
	queue_free()
