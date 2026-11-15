extends Node2D
## Djungelns boss (användaren 15 nov): en leksaks-orangutang som är hungrig. Man kastar bananer (B) i
## munnen när den gapar; efter MATT bananer somnar den och buren går att öppna. Den gör ingen illa –
## knepet är att förstå att den vill ha mat och att träffa när munnen är öppen.

signal somnade

const MATT := 3
const HUNGRIG := 1.6  ## sekunder med armarna i kors
const GAPAR := 1.8    ## sekunder med öppen mun
const TUGGAR := 1.3

var bana: Node2D
var platt := false
var trampbar := false
var mattnad := 0
var sover := false
var _lage := "hungrig"
var _tid := 0.0
var _sprite: AnimatedSprite2D
var _cell := Vector2.ZERO


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Bilder.ramar("orangutang", {
		"hungrig": [["hungrig"], 1.0, false],
		"gapar": [["gapar"], 1.0, false],
		"tuggar": [["tuggar"], 1.0, false],
		"sover": [["sover"], 1.0, false],
	})
	_sprite.centered = false
	_cell = Bilder.cell("orangutang")
	_sprite.offset = Vector2(-_cell.x / 2.0, -_cell.y)
	_sprite.play("hungrig")
	add_child(_sprite)


func _physics_process(dt: float) -> void:
	if sover:
		# andas i sömnen
		_sprite.scale.y = 1.0 + sin(Time.get_ticks_msec() / 600.0) * 0.015
		return
	_tid += dt
	match _lage:
		"hungrig":
			if _tid > HUNGRIG and absf(bana.pojke.position.x - position.x) < 800.0:
				_byt("gapar")
		"gapar":
			if _tid > GAPAR:
				_byt("hungrig")
		"tuggar":
			if _tid > TUGGAR:
				if mattnad >= MATT:
					sover = true
					_byt("sover")
					somnade.emit()
				else:
					_byt("hungrig")
	# mättare = rundare
	var k := 1.0 + mattnad * 0.04
	_sprite.scale = Vector2(k, 1.0)


func _byt(lage: String) -> void:
	_lage = lage
	_tid = 0.0
	_sprite.play(lage)


## Munnen – bara när den gapar. Generös (barnet ska kunna träffa): ansiktet i övre mitten.
func mun() -> Rect2:
	if _lage != "gapar" or sover:
		return Rect2()
	return Rect2(position.x - _cell.x * 0.46, position.y - _cell.y * 0.82, _cell.x * 0.66, _cell.y * 0.46)  # hela huvudet framifrån


## En banan träffade munnen
func mata() -> void:
	mattnad += 1
	Spel.ljud("mums")
	_byt("tuggar")


## Hela kroppen – bananer som missar studsar bort, pojken kan inte gå igenom
func kropp() -> Rect2:
	return Rect2(position.x - _cell.x * 0.4, position.y - _cell.y * 0.9, _cell.x * 0.8, _cell.y * 0.9)


func rect() -> Rect2:
	return Rect2()  # gör ingen illa
