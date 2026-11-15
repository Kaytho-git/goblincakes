extends Node2D
## Gummikrokodilen i vattnet: gömmer sig under ytan, hoppar rakt upp med jämna mellanrum och ner igen.
## Går inte att trampa på – man väntar tills den är nere och hoppar över. Positionen = vattenytan.

const HOPP := 980.0
const TYNGD := 2600.0
const VANTA := [1.4, 2.4]

var bana: Node2D
var platt := false
var trampbar := false
var _yta := 0.0
var _vy := 0.0
var _uppe := false
var _vanta := 1.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_yta = position.y
	_vanta = randf_range(VANTA[0], VANTA[1])
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Bilder.ramar("krokodil", {"stang": [["krokodil1"], 1.0, false], "gap": [["krokodil2"], 1.0, false]})
	_sprite.centered = false
	var cell: Vector2 = Bilder.cell("krokodil")
	_sprite.offset = Vector2(-cell.x / 2.0, -cell.y)
	_sprite.play("stang")
	add_child(_sprite)
	position.y = _yta + cell.y  # under ytan
	z_index = -1  # bakom vattnet


func _physics_process(dt: float) -> void:
	if not _uppe:
		_vanta -= dt
		if _vanta <= 0.0 and absf(bana.pojke.position.x - position.x) < 700.0:
			_uppe = true
			_vy = -HOPP
		return
	_vy += TYNGD * dt
	position.y += _vy * dt
	_sprite.play("gap" if absf(_vy) < 300.0 else "stang")
	var under: float = _yta + Bilder.cell("krokodil").y
	if _vy > 0.0 and position.y >= under:
		position.y = under
		_uppe = false
		_vanta = randf_range(VANTA[0], VANTA[1])


func rect() -> Rect2:
	var top := position.y - Bilder.cell("krokodil").y * 0.85
	if top > _yta - 8.0:
		return Rect2()  # under vattnet: rör inget
	return Rect2(position.x - 22.0, top, 44.0, minf(position.y, _yta) - top)
