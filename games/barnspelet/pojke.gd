extends CharacterBody2D
## Pojken. Positionen = mellan fötterna. 48 spelpixlar = en ruta, pojken är 96 hög.

signal dog

# ── Känslan: alla siffror här (spelpixlar per sekund, sekunder) ──
const GA := 250.0           ## gångfart (≈ 5 rutor/s)
const SPRING := 400.0       ## med X nedtryckt
const ACC := 1100.0         ## uppfart på marken
const BROMS := 1600.0       ## när spaken släpps
const VAND := 2800.0        ## när man byter håll
const LUFT_ACC := 900.0     ## styrning i luften
const HOPP := 830.0         ## starthastighet uppåt → ≈ 3,6 rutor när A hålls
const HOPP_SPRING := 900.0  ## i full spring → ≈ 4,2 rutor
const TYNGD_UPP := 2000.0   ## på väg upp med A nedtryckt
const TYNGD := 3800.0       ## annars (släpper man A blir hoppet lägre)
const MAX_FALL := 950.0
const KANT_TID := 0.10      ## hopp strax efter att man gått över en kant
const BUFFERT := 0.12       ## A strax innan landningen hoppar direkt vid landningen
const STUDS := 560.0        ## efter att ha trampat på en fiende (A nedtryckt: HOPP)

const BREDD := 34.0
const HOJD := 86.0

var dod := false
var _vand := 1.0
var _kant := 0.0
var _buffert := 0.0
var _hopp_forra := false
var _sprite: AnimatedSprite2D
var _dod_tid := 0.0


func _ready() -> void:
	var form := RectangleShape2D.new()
	form.size = Vector2(BREDD, HOJD)
	var shape := CollisionShape2D.new()
	shape.shape = form
	shape.position = Vector2(0, -HOJD / 2.0)
	add_child(shape)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 10.0
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Bilder.ramar("pojken", {
		"sta": [["sta"], 1.0, false],
		"ga": [["kliv1", "mellan1", "kliv2", "mellan2"], 8.0, true],
		"spring": [["spring1", "spring2", "spring3", "spring4"], 12.0, true],
		"hopp": [["hopp"], 1.0, false],
		"fall": [["fall"], 1.0, false],
		"bromsa": [["bromsa"], 1.0, false],
		"oj": [["oj"], 1.0, false],
	})
	_sprite.centered = false
	var cell: Vector2 = Bilder.cell("pojken")
	_sprite.offset = Vector2(-cell.x / 2.0, -cell.y)
	_sprite.play("sta")
	add_child(_sprite)


func _physics_process(dt: float) -> void:
	if dod:
		_dod_tid += dt
		if _dod_tid > 0.35:  # står still en kort stund med "oj", sedan upp och ner ur bild
			velocity.y = minf(velocity.y + TYNGD * 0.6 * dt, MAX_FALL)
			position += velocity * dt
		return
	var x := Spel.styr_x()
	var spring := Spel.spring_nere()
	var hopp := Spel.hopp_nere()
	var nytt_hopp := hopp and not _hopp_forra
	_hopp_forra = hopp

	# sidled
	var mal := x * (SPRING if spring else GA)
	var acc := LUFT_ACC
	if is_on_floor():
		acc = ACC if x != 0.0 else BROMS
		if x != 0.0 and signf(x) != signf(velocity.x) and velocity.x != 0.0:
			acc = VAND
	velocity.x = move_toward(velocity.x, mal, acc * dt)
	if x != 0.0:
		_vand = signf(x)

	# hopp: kant-tid och buffert gör det snällt
	_kant = KANT_TID if is_on_floor() else maxf(0.0, _kant - dt)
	_buffert = BUFFERT if nytt_hopp else maxf(0.0, _buffert - dt)
	if _buffert > 0.0 and _kant > 0.0:
		var fart := absf(velocity.x) / SPRING
		velocity.y = -lerpf(HOPP, HOPP_SPRING, clampf((fart - 0.65) / 0.35, 0.0, 1.0))
		_buffert = 0.0
		_kant = 0.0
		Spel.ljud("hopp")
	var g := TYNGD_UPP if (velocity.y < 0.0 and hopp) else TYNGD
	velocity.y = minf(velocity.y + g * dt, MAX_FALL)
	move_and_slide()
	_bild()


## Vilken rörelse som syns. Spring från 320 px/s (gång 250, spring 400); bromsa = spaken åt andra hållet
## med fart kvar (han tittar dit han var på väg); fall = på väg ner.
func _bild() -> void:
	var x := Spel.styr_x()
	var fart := absf(velocity.x)
	var bromsar := is_on_floor() and x != 0.0 and fart > 150.0 and signf(x) != signf(velocity.x)
	_sprite.flip_h = (velocity.x < 0.0) if bromsar else (_vand < 0.0)
	_sprite.position.y = 0.0
	_sprite.speed_scale = 1.0
	if not is_on_floor():
		_sprite.play("hopp" if velocity.y < 0.0 else "fall")
	elif bromsar:
		_sprite.play("bromsa")
	elif fart > 320.0:
		_sprite.play("spring")
		_sprite.speed_scale = clampf(fart / SPRING, 0.8, 1.3)
	elif fart > 20.0:
		_sprite.play("ga")
		_sprite.speed_scale = clampf(fart / GA, 0.6, 1.3)
	else:
		_sprite.play("sta")
		# andas: en pixel upp och ner när han står still
		_sprite.position.y = -1.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.6 else 0.0


## Trampat på en fiende: studsa upp (högre om A hålls)
func studsa() -> void:
	velocity.y = -(HOPP if Spel.hopp_nere() else STUDS)
	_kant = 0.0
	Spel.ljud("trampa")


func do() -> void:
	if dod:
		return
	dod = true
	_dod_tid = 0.0
	velocity = Vector2(0, -700)
	collision_mask = 0
	_sprite.flip_h = false
	_sprite.play("oj")
	z_index = 10
	Spel.ljud("oj")
	dog.emit()


func rect() -> Rect2:
	return Rect2(position.x - BREDD / 2.0, position.y - HOJD, BREDD, HOJD)
