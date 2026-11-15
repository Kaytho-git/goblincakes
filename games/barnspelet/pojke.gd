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
const LUFT_VAND := 2000.0   ## åt andra hållet i luften – för kort hopp går att rädda (användaren 15 nov)
const HOPP := 830.0         ## starthastighet uppåt → ≈ 3,6 rutor när A hålls
const HOPP_SPRING := 900.0  ## i full spring → ≈ 4,2 rutor
const TYNGD_UPP := 2000.0   ## på väg upp med A nedtryckt
const TYNGD := 3800.0       ## annars (släpper man A blir hoppet lägre)
const MAX_FALL := 950.0
const KANT_TID := 0.10      ## hopp strax efter att man gått över en kant
const BUFFERT := 0.12       ## A strax innan landningen hoppar direkt vid landningen
const STUDS := 560.0        ## efter att ha trampat på en fiende (A nedtryckt: HOPP)
## Ducka och glida (användaren 15 nov): ner = ducka (låg, står still); ner i fart = glida på rumpan,
## farten avtar; ormar och bilar slås ut av en glidning. Hoppa går ur båda (farten behålls).
const GLID_FART := 200.0    ## minst så här fort för att glida i stället för att ducka
const GLID_BROMS := 420.0
const GLID_TID := 0.75
const LAG := 40.0           ## höjden när han duckar/glider – under ett block en ruta upp (48) får han plats
const KRYP := 110.0         ## duckar = kryper i den farten; under ett tak tar glidningen inte slut förrän den stannar
## Isplattorna (bana 2): halt – farten kommer långsamt och han glider vidare när spaken släpps
const IS_ACC := 300.0
const IS_BROMS := 120.0
const IS_VAND := 500.0
## Kvicksanden (bana 3): sjunker sakta, går sakta, kan alltid hoppa ur (för djupt = oj, bana.gd)
const SJUNK := 28.0
const KVICK_FART := 90.0

const BREDD := 34.0
const HOJD := 86.0

var dod := false
var ducker := false
var glider := false
var hojd_nu := HOJD
var _glid_tid := 0.0
var _form: RectangleShape2D
var _shape: CollisionShape2D
var _vand := 1.0
var _kant := 0.0
var _buffert := 0.0
var _hopp_forra := false
var _sprite: AnimatedSprite2D
var _dod_tid := 0.0
var _kvick := -1.0  ## djupet i kvicksanden (px), −1 = inte i den
var blad := "pojken"
var skydd := 0.0  ## efter en träff: blinkar och kan inte träffas igen (sekunder kvar)  ## bildbladet (kläderna; pojken-safari-hink = bär hinken)


func _ready() -> void:
	_form = RectangleShape2D.new()
	_form.size = Vector2(BREDD, HOJD)
	_shape = CollisionShape2D.new()
	_shape.shape = _form
	_shape.position = Vector2(0, -HOJD / 2.0)
	add_child(_shape)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 16.0                # följer marken nerför backar i full fart
	floor_max_angle = deg_to_rad(50.0)      # backarna är 45°
	_sprite = AnimatedSprite2D.new()
	# kläderna efter banan (json "pojke": snön = pojken-vinter; användaren 15 nov) – annars de vanliga
	var bana_nod: Node = get_parent()
	var meta: Dictionary = bana_nod._meta if bana_nod != null and bana_nod.get("_meta") is Dictionary else {}
	blad = meta.get("pojke", "pojken")
	# med hinken i handen (Sanden: json "pojke_hink", bara när banan har sanddynor)
	var hb: String = meta.get("pojke_hink", "")
	if hb != "" and FileAccess.file_exists("res://bilder/%s.json" % hb) and bana_nod.saker.any(func(x): return x["typ"] == "sanddyn"):
		blad = hb
	if not FileAccess.file_exists("res://bilder/%s.json" % blad):
		blad = "pojken"
	var anims := {
		"sta": [["idle1", "idle2"], 1.4, true],  # andas
		"titta": [["idle3"], 1.0, false],         # tittar på oss
		"upp": [["idle4"], 1.0, false],           # tittar upp i himlen
		"ga": [["kliv1", "mellan1", "kliv2", "mellan2"], 8.0, true],
		"spring": [["spring1", "spring2", "spring3", "spring4"], 12.0, true],
		"hopp": [["hopp"], 1.0, false],
		"fall": [["fall"], 1.0, false],
		"bromsa": [["bromsa"], 1.0, false],
		"duck": [["duck"], 1.0, false],
		"glid": [["glid"], 1.0, false],
		"oj": [["oj"], 1.0, false],
	}
	if Bilder.info(blad)["frames"].has("kryp1"):  # krypa på knä och händer (ducka + åt sidan)
		anims["kryp"] = [["kryp1", "kryp2", "kryp3", "kryp4"], 7.0, true]
	_sprite.sprite_frames = Bilder.ramar(blad, anims)
	_sprite.centered = false
	var cell: Vector2 = Bilder.cell(blad)
	_sprite.offset = Vector2(-cell.x / 2.0, -cell.y)
	_sprite.play("sta")
	add_child(_sprite)
	_andas = meta.get("andedrakt", false)


## Andedräkten i kylan (banans json "andedrakt": true – snön; användaren 15 nov): ett litet vitt moln
## ur munnen då och då, som glider framåt, växer och bleknar bort
var _andas := false
var _andas_tid := 1.0
var _moln_bild: ImageTexture


func _andedrakt(dt: float) -> void:
	_andas_tid -= dt
	if _andas_tid > 0.0 or dod:
		return
	_andas_tid = randf_range(1.6, 2.4) if absf(velocity.x) < 300.0 else randf_range(0.9, 1.3)  # tätare när han springer
	if _moln_bild == null:
		var img := Image.create(10, 7, false, Image.FORMAT_RGBA8)
		for p in [[2, 1], [3, 1], [5, 1], [6, 1], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [7, 2],
				[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3],
				[1, 4], [2, 4], [3, 4], [4, 4], [5, 4], [6, 4], [7, 4], [8, 4], [2, 5], [3, 5], [6, 5], [7, 5]]:
			img.set_pixel(p[0], p[1], Color(1, 1, 1, 0.85 if p[1] in [2, 3] else 0.6))
		_moln_bild = ImageTexture.create_from_image(img)
	var m := Sprite2D.new()
	m.texture = _moln_bild
	m.z_index = 4
	m.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # flyttas med en tween
	var munnen := Vector2(_vand * 17.0, -hojd_nu + (24.0 if hojd_nu < HOJD else 30.0))
	m.position = position + munnen
	m.scale = Vector2(1.2, 1.2)
	m.flip_h = _vand < 0.0
	get_parent().add_child(m)
	var t := m.create_tween().set_parallel()
	t.tween_property(m, "position", m.position + Vector2(_vand * 22.0 + velocity.x * 0.3, -10.0), 1.1).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "scale", Vector2(2.6, 2.4), 1.1).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(m.queue_free)


func _physics_process(dt: float) -> void:
	if dod:
		_dod_tid += dt
		if _dod_tid > 0.35:  # står still en kort stund med "oj", sedan upp och ner ur bild
			velocity.y = minf(velocity.y + TYNGD * 0.6 * dt, MAX_FALL)
			position += velocity * dt
		return
	if skydd > 0.0:  # blinkar efter en träff
		skydd = maxf(0.0, skydd - dt)
		_sprite.visible = skydd == 0.0 or int(skydd * 12.0) % 2 == 0
	var x := Spel.styr_x()
	var spring := Spel.spring_nere()
	var hopp := Spel.hopp_nere()
	var nytt_hopp := hopp and not _hopp_forra
	_hopp_forra = hopp

	# ducka / glida
	var ner := Spel.ner_nere() and is_on_floor()
	var tak := not _plats_att_sta()
	if glider:
		_glid_tid += dt
		velocity.x = move_toward(velocity.x, 0.0, GLID_BROMS * dt)
		if tak and absf(velocity.x) > KRYP:  # under ett block: glider vidare ut på andra sidan (användaren 15 nov)
			velocity.x = signf(velocity.x) * maxf(absf(velocity.x), KRYP * 1.5)
		elif tak or _glid_tid > GLID_TID or absf(velocity.x) < 60.0 or not is_on_floor():
			# stopp (en vägg under taket) = duckar/kryper vidare – fastnade förut i glidläget utan styrning
			glider = false
			ducker = ner or tak
	elif ner and not ducker:
		if absf(velocity.x) >= GLID_FART:
			glider = true
			_glid_tid = 0.0
		else:
			ducker = true
	elif ducker and not ner and _plats_att_sta():
		ducker = false
	if ducker and not ner and not _plats_att_sta():
		pass  # under ett tak: stannar nere tills det finns plats
	_lag(ducker or glider)

	# sidled
	var mal := x * (SPRING if spring else GA)
	if ducker or glider:
		mal = 0.0  # står still när han duckar; glidningen bromsar själv
		if ducker:
			mal = x * KRYP  # duckar = kryper sakta (användaren 15 nov: "crouch walk"; man ska aldrig fastna)
	var acc := LUFT_ACC
	if not is_on_floor() and x != 0.0 and velocity.x != 0.0 and signf(x) != signf(velocity.x):
		acc = LUFT_VAND
	if is_on_floor():
		acc = ACC if x != 0.0 else BROMS
		if x != 0.0 and signf(x) != signf(velocity.x) and velocity.x != 0.0:
			acc = VAND
		var b: Node2D = get_parent()
		if b.has_method("halt") and b.halt(position):
			acc = IS_ACC if x != 0.0 else IS_BROMS
			if x != 0.0 and signf(x) != signf(velocity.x) and velocity.x != 0.0:
				acc = IS_VAND
	if not glider:
		velocity.x = move_toward(velocity.x, mal, acc * dt)
	if x != 0.0:
		_vand = signf(x)

	var bn: Node2D = get_parent()
	_kvick = bn.kvicksand(position) if bn.has_method("kvicksand") else -1.0
	if _kvick >= 0.0:
		velocity.x = clampf(velocity.x, -KVICK_FART, KVICK_FART)
	# hopp: kant-tid och buffert gör det snällt (i kvicksanden går det alltid att hoppa)
	_kant = KANT_TID if (is_on_floor() or _kvick >= 0.0) else maxf(0.0, _kant - dt)
	_buffert = BUFFERT if nytt_hopp else maxf(0.0, _buffert - dt)
	if _buffert > 0.0 and _kant > 0.0:
		var fart := absf(velocity.x) / SPRING
		velocity.y = -lerpf(HOPP, HOPP_SPRING, clampf((fart - 0.65) / 0.35, 0.0, 1.0))
		_buffert = 0.0
		_kant = 0.0
		if (glider or ducker) and _plats_att_sta():
			glider = false
			ducker = false
			_lag(false)
		Spel.ljud("hopp")
	var g := TYNGD_UPP if (velocity.y < 0.0 and hopp) else TYNGD
	velocity.y = minf(velocity.y + g * dt, MAX_FALL)
	if _kvick >= 0.0 and velocity.y > SJUNK:
		velocity.y = SJUNK
	var vind: float = bn.vind(position) if bn.has_method("vind") else 0.0
	velocity.x += vind  # vindpusten knuffar bakåt (på marken och i luften)
	move_and_slide()
	velocity.x = 0.0 if is_on_wall() and vind != 0.0 else velocity.x - vind
	_bild()
	if _andas:
		_andedrakt(dt)


## Vilken rörelse som syns. Spring från 320 px/s (gång 250, spring 400); bromsa = spaken åt andra hållet
## med fart kvar (han tittar dit han var på väg); fall = på väg ner.
## Låg (duckar/glider) eller vanlig höjd – krockrutan och det som räknas som träff
func _lag(lag: bool) -> void:
	hojd_nu = LAG if lag else HOJD
	if not is_equal_approx(_form.size.y, hojd_nu):
		_form.size = Vector2(BREDD, hojd_nu)
		_shape.position = Vector2(0, -hojd_nu / 2.0)


## Plats ovanför för att resa sig (inget fast i huvudhöjd)
func _plats_att_sta() -> bool:
	var b: Node2D = get_parent()
	if not b.has_method("fast"):
		return true
	for dx in [-BREDD / 2.0 + 2.0, BREDD / 2.0 - 2.0]:
		if b.fast(position + Vector2(dx, -HOJD + 4.0)):
			return false
	return true


func _bild() -> void:
	var x := Spel.styr_x()
	var fart := absf(velocity.x)
	var bromsar := is_on_floor() and x != 0.0 and fart > 150.0 and signf(x) != signf(velocity.x)
	_sprite.flip_h = (velocity.x < 0.0) if bromsar else (_vand < 0.0)
	_sprite.position.y = 0.0
	_sprite.speed_scale = 1.0
	if glider and _sprite.sprite_frames.has_animation("glid"):
		_sprite.flip_h = velocity.x < 0.0
		_sprite.play("glid")
	elif ducker and fart > 10.0 and _sprite.sprite_frames.has_animation("kryp"):
		_sprite.play("kryp")
		_sprite.speed_scale = clampf(fart / KRYP, 0.5, 1.2)
	elif ducker and _sprite.sprite_frames.has_animation("duck"):
		_sprite.play("duck")
		# kryper utan krypbilder: gungar lite upp och ner
		_sprite.position.y = -2.0 if fart > 10.0 and int(Time.get_ticks_msec() / 140) % 2 == 0 else 0.0
	elif not is_on_floor() and _kvick < 0.0:
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
		_idle()


## Står han still andas han, och då och då (var 3–6:e s) tittar han på oss eller upp i himlen en stund
var _still := 0.0
var _nasta_blick := 4.0
var _blick := ""


func _idle() -> void:
	var dt := get_physics_process_delta_time()
	if _sprite.animation not in ["sta", "titta", "upp"]:
		_still = 0.0
		_nasta_blick = randf_range(3.0, 6.0)
		_blick = ""
	_still += dt
	if _blick != "" and _still > 1.6:
		_blick = ""
		_still = 0.0
		_nasta_blick = randf_range(3.0, 6.0)
	elif _blick == "" and _still > _nasta_blick:
		_blick = "titta" if randf() < 0.5 else "upp"
		_still = 0.0
	_sprite.play(_blick if _blick != "" else "sta")


## Träffad av en fiende (ett hjärta mindre, bana.gd): studsar bakåt bort från den, blinkar 1,5 s
func traffad(fran_x: float) -> void:
	skydd = 1.5
	var bort := signf(position.x - fran_x)
	if bort == 0.0:
		bort = -_vand
	velocity = Vector2(bort * 320.0, -380.0)
	glider = false
	Spel.ljud("aj")


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
	skydd = 0.0
	_sprite.visible = true
	velocity = Vector2(0, -700)
	collision_mask = 0
	_sprite.flip_h = false
	_sprite.play("oj")
	z_index = 10
	Spel.ljud("oj")
	dog.emit()


func rect() -> Rect2:
	return Rect2(position.x - BREDD / 2.0, position.y - hojd_nu, BREDD, hojd_nu)
