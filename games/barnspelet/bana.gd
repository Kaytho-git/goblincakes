extends Node2D
## En bana ur banor/<namn>.txt – en rad per rutrad (48 × 48 spelpixlar):
##   .  luft          G  gräsyta (allt under fylls med jord)    =  planka (hoppa upp underifrån)
##   k  knapp         h  hjärta (ett liv)                       r  racerbil
##   F  flagga (börja om här)    B  buren med gossedjuret (mål)    P  start

const RUTA := 48
const KAKEL := ["gras_v", "gras", "gras_h", "jord_v", "jord", "jord_h", "planka_v", "planka", "planka_h"]

var bredd := 0
var hojd := 0
var botten := 0.0
var pojke: CharacterBody2D
var kamera: Camera2D
var bilar: Array = []
var saker: Array = []  ## {"typ", "nod", "rect", "y"}
var klar := false

var _fast := {}
var _plankor := {}
var _start := Vector2.ZERO
var _tid := 0.0


func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://banor/%s.txt" % Spel.bana)
	var rader := text.strip_edges(false, true).split("\n")
	hojd = rader.size()
	for r in rader:
		bredd = maxi(bredd, r.length())
	botten = hojd * RUTA
	_bakgrund()
	_rutor(rader)
	_figurer(rader)
	_ny_pojke()
	_ny_kamera()
	_hud()


func fast(p: Vector2) -> bool:
	return _fast.has(Vector2i(floori(p.x / RUTA), floori(p.y / RUTA)))


# ── Bygget ───────────────────────────────────────────────────────

func _rutor(rader: PackedStringArray) -> void:
	for y in hojd:
		for x in rader[y].length():
			match rader[y][x]:
				"G":
					for yy in range(y, hojd):
						_fast[Vector2i(x, yy)] = true
				"=":
					_plankor[Vector2i(x, y)] = true
	var ts := TileSet.new()
	ts.tile_size = Vector2i(RUTA, RUTA)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = Bilder.textur("mark")
	src.texture_region_size = Vector2i(RUTA, RUTA)
	var sid := ts.add_source(src)
	var h := RUTA / 2.0
	for i in KAKEL.size():
		src.create_tile(Vector2i(i, 0))
		var td := src.get_tile_data(Vector2i(i, 0), 0)
		td.add_collision_polygon(0)
		if i >= 6:  # plankan: bara överkanten, och bara uppifrån
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 14), Vector2(-h, -h + 14)]))
			td.set_collision_polygon_one_way(0, 0, true)
		else:
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	var lager := TileMapLayer.new()
	lager.tile_set = ts
	add_child(lager)
	for c in _fast:
		var topp := not _fast.has(c + Vector2i.UP)
		lager.set_cell(c, sid, Vector2i((0 if topp else 3) + _kant(_fast, c), 0))
	for c in _plankor:
		lager.set_cell(c, sid, Vector2i(6 + _kant(_plankor, c), 0))


## 0 = vänsterkant, 1 = mitten, 2 = högerkant
func _kant(rutor: Dictionary, c: Vector2i) -> int:
	var v := not rutor.has(c + Vector2i.LEFT)
	var hg := not rutor.has(c + Vector2i.RIGHT)
	return 0 if v and not hg else (2 if hg and not v else 1)


func _figurer(rader: PackedStringArray) -> void:
	for y in hojd:
		for x in rader[y].length():
			var mitt := Vector2(x * RUTA + RUTA / 2.0, y * RUTA + RUTA / 2.0)
			var golv := Vector2(x * RUTA + RUTA / 2.0, (y + 1) * RUTA)
			match rader[y][x]:
				"P":
					_start = golv
				"k":
					_sak("knapp", mitt, true)
				"h":
					_sak("hjarta", mitt, true)
				"F":
					var f := _sak("flagga", golv, false)
					if Spel.flagga >= 0.0 and is_equal_approx(Spel.flagga, golv.x):
						_start = golv
						f["nod"].modulate = Color(1, 1, 0.6)
				"B":
					_sak("bur", golv, false)
				"r":
					ny_bil(golv)


func _sak(typ: String, pos: Vector2, svavar: bool) -> Dictionary:
	var s := Sprite2D.new()
	s.texture = Bilder.textur(typ)
	var c: Vector2 = Bilder.cell(typ)
	s.centered = false
	s.offset = -c / 2.0 if svavar else Vector2(-c.x / 2.0, -c.y)
	s.position = pos
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # guppar i _process
	add_child(s)
	var r := Rect2(pos - c / 2.0, c) if svavar else Rect2(pos - Vector2(c.x / 2.0, c.y), c)
	var sak := {"typ": typ, "nod": s, "rect": r, "y": pos.y, "svavar": svavar}
	saker.append(sak)
	return sak


func ny_bil(golv: Vector2) -> Node2D:
	var b := Node2D.new()
	b.set_script(load("res://racerbil.gd"))
	b.bana = self
	b.position = golv
	add_child(b)
	bilar.append(b)
	return b


func _ny_pojke() -> void:
	pojke = CharacterBody2D.new()
	pojke.set_script(load("res://pojke.gd"))
	pojke.position = _start
	pojke.z_index = 5
	add_child(pojke)
	pojke.dog.connect(_dog)


func _ny_kamera() -> void:
	kamera = Camera2D.new()
	kamera.limit_left = 0
	kamera.limit_top = 0
	kamera.limit_right = bredd * RUTA
	kamera.limit_bottom = hojd * RUTA
	kamera.position_smoothing_enabled = true
	kamera.position_smoothing_speed = 7.0
	kamera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS  # i takt med pojken (fysikinterpoleringen)
	kamera.position = pojke.position
	add_child(kamera)
	kamera.reset_smoothing()


# ── Varje bildruta ───────────────────────────────────────────────

func _physics_process(_dt: float) -> void:
	if not pojke.dod:
		kamera.position = Vector2(pojke.position.x, pojke.position.y - 90.0)
	if pojke.dod or klar:
		return
	if pojke.position.x < Pojke_halv():
		pojke.position.x = Pojke_halv()
		pojke.velocity.x = maxf(0.0, pojke.velocity.x)
	if pojke.position.y > botten + 60.0:
		pojke.do()
		return
	var pr: Rect2 = pojke.rect()
	bilar = bilar.filter(func(b): return is_instance_valid(b))
	for b in bilar:
		if b.platt or not pr.intersects(b.rect()):
			continue
		# uppifrån och på väg ner = trampa; annars "oj"
		if pojke.velocity.y > 0.0 and pojke.position.y < b.rect().position.y + 22.0:
			b.platta()
			pojke.studsa()
		else:
			pojke.do()
			return
	for s in saker.duplicate():
		if not pr.intersects(s["rect"]):
			continue
		match s["typ"]:
			"knapp":
				Spel.ta_knapp()
				_ta_bort(s)
			"hjarta":
				Spel.nytt_liv()
				_ta_bort(s)
			"flagga":
				if not is_equal_approx(Spel.flagga, s["nod"].position.x):
					Spel.flagga = s["nod"].position.x
					s["nod"].modulate = Color(1, 1, 0.6)
					Spel.ljud("flagga")
			"bur":
				_raddad(s)


func Pojke_halv() -> float:
	return pojke.BREDD / 2.0


func _process(dt: float) -> void:
	_tid += dt
	for s in saker:
		if s["svavar"]:  # knappar och hjärtan guppar
			s["nod"].position.y = s["y"] + roundf(sin(_tid * 3.0 + s["nod"].position.x * 0.05) * 2.0)
	_hud_uppdatera()


func _ta_bort(s: Dictionary) -> void:
	saker.erase(s)
	s["nod"].queue_free()


func _dog() -> void:
	if Spel.prov:
		return
	await get_tree().create_timer(2.0).timeout
	Spel.forlorat()  # sista livet: alla liv tillbaka, från början (steg 2: tillbaka till kartan)
	get_tree().reload_current_scene()


## Målet – ingen text (användaren 15 nov): buren försvinner och pojken håller upp gossedjuret
func _raddad(s: Dictionary) -> void:
	klar = true
	pojke.set_physics_process(false)
	pojke.visible = false
	s["nod"].visible = false
	Spel.ljud("raddad")
	var t_bild := Sprite2D.new()
	t_bild.texture = Bilder.textur("triumf")
	t_bild.centered = false
	var c: Vector2 = Bilder.cell("triumf")
	t_bild.offset = Vector2(-c.x / 2.0, -c.y)
	t_bild.position = Vector2(s["nod"].position.x, s["y"])
	t_bild.z_index = 5
	t_bild.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # studsar med en tween
	add_child(t_bild)
	var t := create_tween().set_loops(5)
	t.tween_property(t_bild, "position:y", s["y"] - 24.0, 0.2).set_ease(Tween.EASE_OUT)
	t.tween_property(t_bild, "position:y", s["y"], 0.2).set_ease(Tween.EASE_IN)
	if Spel.prov:
		return
	await get_tree().create_timer(4.0).timeout
	Spel.flagga = -1.0  # steg 2: tillbaka till kartan
	get_tree().reload_current_scene()


# ── Skärmen ──────────────────────────────────────────────────────

## Ingen text (användaren 15 nov): liven = hjärtan i rad, knapparna = en mätare med tio fack
## (ett fack per tio knappar, full mätare = ett liv till)
func _hud() -> void:
	var lager := CanvasLayer.new()
	add_child(lager)
	_hud_hjartan = HBoxContainer.new()
	_hud_hjartan.position = Vector2(20, 14)
	_hud_hjartan.add_theme_constant_override("separation", 4)
	lager.add_child(_hud_hjartan)
	var rad := HBoxContainer.new()
	rad.position = Vector2(20, 50)
	rad.add_theme_constant_override("separation", 6)
	lager.add_child(rad)
	var k := TextureRect.new()
	k.texture = Bilder.textur("knapp")
	rad.add_child(k)
	var ram := Panel.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0.16, 0.1, 0.2, 0.55)
	stil.border_color = Color(0.16, 0.1, 0.2)
	stil.set_border_width_all(2)
	ram.add_theme_stylebox_override("panel", stil)
	ram.custom_minimum_size = Vector2(10 * 12 + 6, 22)
	ram.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rad.add_child(ram)
	for i in 10:
		var fack := ColorRect.new()
		fack.position = Vector2(4 + i * 12, 4)
		fack.size = Vector2(10, 14)
		ram.add_child(fack)
		_hud_fack.append(fack)


var _hud_hjartan: HBoxContainer
var _hud_fack: Array[ColorRect] = []
var _visat_liv := -1


func _hud_uppdatera() -> void:
	if _visat_liv != Spel.liv:
		_visat_liv = Spel.liv
		for c in _hud_hjartan.get_children():
			c.queue_free()
		for i in mini(Spel.liv, 12):
			var h := TextureRect.new()
			h.texture = Bilder.textur("hjarta")
			_hud_hjartan.add_child(h)
	var fulla := Spel.knappar / 10
	for i in 10:
		_hud_fack[i].color = Color(1.0, 0.8, 0.2) if i < fulla else Color(1, 1, 1, 0.15)


## Himmel (klar färg i project.godot), moln och kullar som rör sig långsammare än banan
func _bakgrund() -> void:
	var kullar := Parallax2D.new()
	kullar.scroll_scale = Vector2(0.45, 0.2)
	kullar.repeat_size = Vector2(960, 0)
	kullar.repeat_times = 3
	kullar.z_index = -20
	var k := Sprite2D.new()
	k.texture = ImageTexture.create_from_image(_kullar_bild())
	k.centered = false
	k.position = Vector2(0, 230)
	kullar.add_child(k)
	add_child(kullar)
	var moln := Parallax2D.new()
	moln.scroll_scale = Vector2(0.25, 0.1)
	moln.repeat_size = Vector2(960, 0)
	moln.repeat_times = 3
	moln.z_index = -30
	for m in [[60, 60, 1.0], [380, 120, 0.7], [700, 40, 1.2]]:
		var s := Sprite2D.new()
		s.texture = ImageTexture.create_from_image(_moln_bild(m[2]))
		s.centered = false
		s.position = Vector2(m[0], m[1])
		moln.add_child(s)
	add_child(moln)


func _moln_bild(k: float) -> Image:
	var w := int(150 * k)
	var h := int(56 * k)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var klot := [[0.25, 0.62, 0.24], [0.45, 0.42, 0.3], [0.68, 0.55, 0.26], [0.85, 0.7, 0.16]]
	for y in h:
		for x in w:
			for c in klot:
				var dx: float = (x - c[0] * w) / (c[2] * w)
				var dy: float = (y - c[1] * h) / (c[2] * w)
				if dx * dx + dy * dy < 1.0:
					img.set_pixel(x, y, Color(0.86, 0.93, 1.0) if y > h * 0.7 else Color(1, 1, 1))
					break
	return img


func _kullar_bild() -> Image:
	var w := 960
	var h := 330
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var t := x / float(w) * TAU
		var topp := 70.0 + sin(t) * 40.0 + sin(t * 3.0 + 1.0) * 18.0
		for y in range(int(topp), h):
			var ljus := y < topp + 4.0
			img.set_pixel(x, y, Color(0.55, 0.8, 0.5) if ljus else Color(0.45, 0.7, 0.45))
	return img
