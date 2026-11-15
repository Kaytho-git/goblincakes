extends Node2D
## Redigeraren (användaren 15 nov: "jag startar editering och lägger in fienderna och plattformar").
## E i spelet → här: spelet står still, rutnät, en meny med bilder längst ner.
##   vänsterklick/dra = lägg ut det valda   högerklick/dra = ta bort   Ctrl+Z = ångra
##   A/D, pilarna, mushjulet = flytta (Shift = fortare), W/S = upp/ner   1–9, 0 = välj i menyn
##   E = spela härifrån   Enter = spela från början   Esc = avsluta
## Varje ändring sparas direkt i banor/<namn>.txt och banan byggs om (samma bygge som när man spelar).
## Bara för den vuxne – barnet ser aldrig det här (inga ord i själva spelet).

const RUTA := 48
## [tecken, namn, bild (blad, ruta)] – ordningen = menyn
const VERKTYG := [
	[".", "Sudd – ta bort (eller högerklick)", ["sudd", ""]],
	["G", "Mark", ["mark", "gras"]],
	["=", "Gren", ["mark", "planka"]],
	["X", "Block 1 (följer banans tema)", ["block", "sten"]],
	["L", "Block 2 (följer banans tema)", ["block", "lada"]],
	["W", "Vatten", ["mark", "vattenyta"]],
	["k", "Knapp", ["knapp", ""]],
	["h", "Hjärta", ["hjarta", ""]],
	["r", "Racerbil", ["racerbil", "kor1"]],
	["s", "Orm", ["orm", "orm1"]],
	["p", "Papegoja", ["papegoja", "papegoja1"]],
	["c", "Krokodil", ["krokodil", "krokodil1"]],
	["o", "Palm", ["palm", ""]],
	["b", "Banan", ["banan", ""]],
	["u", "Bananbuske", ["buske", ""]],
	["O", "Boss", ["orangutang", "hungrig"]],
	["F", "Flagga", ["flagga", ""]],
	["B", "Bur", ["bur", ""]],
	["P", "Start", ["pojken", "sta"]],
]
const ENSAM := ["P", "O"]
const PER_RAD := 10       ## menyn i två rader – allt syns utan att skrolla (användaren 15 nov)
const MENY_HOJD := 112.0  ## finns bara en gång – den gamla tas bort

var bana: Node2D
var _knappar: Array[Button] = []
var _meny: PanelContainer


func _ready() -> void:
	z_index = 50
	var lager := CanvasLayer.new()
	lager.layer = 10
	add_child(lager)
	_meny = PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0.08, 0.06, 0.12, 0.88)
	stil.set_content_margin_all(6)
	_meny.add_theme_stylebox_override("panel", stil)
	_meny.position = Vector2(0, 540 - MENY_HOJD)
	_meny.size = Vector2(960, MENY_HOJD)
	lager.add_child(_meny)
	var rad := GridContainer.new()
	rad.columns = PER_RAD
	rad.add_theme_constant_override("h_separation", 4)
	rad.add_theme_constant_override("v_separation", 4)
	_meny.add_child(rad)
	for i in VERKTYG.size():
		var v: Array = VERKTYG[i]
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 46)
		b.tooltip_text = "%s (%s)" % [v[1], _tangent(i)]
		b.icon = _ikon(v[2][0], v[2][1])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_valj.bind(i))
		rad.add_child(b)
		_knappar.append(b)
	_valj(Spel.red_verktyg)
	# hela banans nederkant ovanför menyn (annars gick markraden inte att klicka på)
	bana.kamera.limit_bottom = int(bana.hojd * RUTA + MENY_HOJD)
	Spel.red_kamera.y = clampf(Spel.red_kamera.y, 270.0, _lagst()) if Spel.red_kamera.y > 270.0 else _lagst()
	bana.kamera.position = Spel.red_kamera
	bana.kamera.reset_smoothing()


func _tangent(i: int) -> String:
	return str((i + 1) % 10) if i < 10 else "–"


func _ikon(blad: String, ruta: String) -> Texture2D:
	if blad == "sudd":  # ett rött kryss
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for i in 16:
			for d in [-1, 0, 1]:
				img.set_pixel(clampi(i + d, 0, 15), i, Color(0.95, 0.3, 0.3))
				img.set_pixel(clampi(15 - i + d, 0, 15), i, Color(0.95, 0.3, 0.3))
		return ImageTexture.create_from_image(img)
	if blad == "block":  # banans egna block (banor/<namn>.json "block"), första/andra rutan
		var bb: String = bana._meta.get("block", "")
		if bb == "" or not FileAccess.file_exists("res://bilder/%s.json" % bb):
			return null
		var bf: Array = Bilder.info(bb)["frames"]
		return Bilder.bild(bb, bf[0 if ruta == "sten" else mini(1, bf.size() - 1)])
	if blad == "mark":
		var m: String = bana._meta.get("mark", "mark")
		var frames: Array = Bilder.info(m)["frames"]
		if ruta not in frames:
			ruta = "gras"
		return Bilder.bild(m, ruta)
	if not FileAccess.file_exists("res://bilder/%s.json" % blad):
		return null
	return Bilder.bild(blad, ruta)


func _valj(i: int) -> void:
	Spel.red_verktyg = i
	for j in _knappar.size():
		_knappar[j].button_pressed = j == i


func _process(dt: float) -> void:
	# flytta runt
	var fart := 900.0 if Input.is_key_pressed(KEY_SHIFT) else 450.0
	var dx := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dx -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dx += 1.0
	if dx != 0.0:
		_flytta(dx * fart * dt)
	var dy := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dy -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dy += 1.0
	if dy != 0.0:
		Spel.red_kamera.y = clampf(Spel.red_kamera.y + dy * fart * dt, 270.0, _lagst())
		bana.kamera.position = Spel.red_kamera
	# måla
	var mus := get_global_mouse_position()
	var c := Vector2i(floori(mus.x / RUTA), floori(mus.y / RUTA))
	var over_menyn := get_viewport().get_mouse_position().y > 540 - MENY_HOJD
	if not over_menyn and c.y >= 0 and c.y < bana.hojd and c.x >= 0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Spel.red_senast != Vector3i(c.x, c.y, 1):
			Spel.red_senast = Vector3i(c.x, c.y, 1)
			_satt(c, VERKTYG[Spel.red_verktyg][0])
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Spel.red_senast != Vector3i(c.x, c.y, 2):
			Spel.red_senast = Vector3i(c.x, c.y, 2)
			_satt(c, ".")
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		Spel.red_senast = Vector3i(-1, -1, 0)
	queue_redraw()


## Kamerans lägsta läge: banans botten precis ovanför menyn
func _lagst() -> float:
	return bana.hojd * RUTA - (540.0 - MENY_HOJD) + 270.0


func _flytta(d: float) -> void:
	Spel.red_kamera.x = clampf(Spel.red_kamera.x + d, 480.0, (bana.bredd + 20) * RUTA - 480.0)
	bana.kamera.position = Spel.red_kamera


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_flytta(-RUTA * 2.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_flytta(RUTA * 2.0)
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_Z and e.ctrl_pressed:
			_angra()
		elif e.keycode >= KEY_0 and e.keycode <= KEY_9:
			var i: int = (e.keycode - KEY_0 + 9) % 10
			if i < VERKTYG.size():
				_valj(i)


## Lägg tecknet i rutan, spara, bygg om banan
func _satt(c: Vector2i, tecken: String) -> void:
	# utgå från filen på disken, inte från banan i minnet: ändrades filen utanför spelet (återställd från git)
	# skrev annars nästa klick tillbaka den gamla versionen (hände 15 nov)
	var pa_disk := FileAccess.get_file_as_string(bana.fil()).strip_edges(false, true)
	var rader: Array = Array(pa_disk.split("\n")) if pa_disk != "" else Array(bana.rader)
	var bredd0 := 0
	for r in rader:
		bredd0 = maxi(bredd0, r.length())
	var bredd := maxi(bredd0, c.x + 1)
	for y in rader.size():
		rader[y] = rader[y].rpad(bredd, ".")
	if rader[c.y][c.x] == tecken:
		return
	if tecken in ENSAM:
		for y in rader.size():
			rader[y] = rader[y].replace(tecken, ".")
	Spel.red_historik.append(pa_disk)
	if Spel.red_historik.size() > 200:
		Spel.red_historik.pop_front()
	var r: String = rader[c.y]
	rader[c.y] = r.substr(0, c.x) + tecken + r.substr(c.x + 1)
	_spara("\n".join(rader))


func _angra() -> void:
	if Spel.red_historik.is_empty():
		return
	_spara(Spel.red_historik.pop_back())


func _spara(text: String) -> void:
	# tomma kolumner längst till höger tas bort
	var rader := text.split("\n")
	var bredd := 0
	for r in rader:
		bredd = maxi(bredd, r.rstrip(".").length())
	for i in rader.size():
		rader[i] = rader[i].rpad(bredd, ".").substr(0, maxi(bredd, 20))
	var f := FileAccess.open(bana.fil(), FileAccess.WRITE)
	if f == null:
		push_error("Kan inte spara %s" % bana.fil())
		return
	f.store_string("\n".join(rader) + "\n")
	f.close()
	get_tree().reload_current_scene.call_deferred()


func _draw() -> void:
	var kam: Vector2 = bana.kamera.get_screen_center_position()
	var x0 := floori((kam.x - 480.0) / RUTA)
	var x1 := ceili((kam.x + 480.0) / RUTA)
	var linje := Color(1, 1, 1, 0.22)
	for x in range(x0, x1 + 1):
		draw_line(Vector2(x * RUTA, 0), Vector2(x * RUTA, bana.hojd * RUTA), linje)
	for y in bana.hojd + 1:
		draw_line(Vector2(x0 * RUTA, y * RUTA), Vector2(x1 * RUTA, y * RUTA), linje)
	# banans slut
	draw_line(Vector2(bana.bredd * RUTA, 0), Vector2(bana.bredd * RUTA, bana.hojd * RUTA), Color(1, 0.4, 0.4, 0.6), 2.0)
	# krokodiler och start syns inte annars (under vattnet / pojken gömd)
	for y in bana.hojd:
		var r: String = bana.rader[y]
		for x in range(maxi(0, x0), mini(r.length(), x1 + 1)):
			if r[x] == "c":
				var t := Bilder.bild("krokodil", "krokodil1")
				draw_texture(t, Vector2(x * RUTA + 24 - t.get_width() / 2.0, y * RUTA - t.get_height() + 30), Color(1, 1, 1, 0.6))
			elif r[x] == "P":
				var t := Bilder.bild("pojken", "sta")
				draw_texture(t, Vector2(x * RUTA + 24 - t.get_width() / 2.0, (y + 1) * RUTA - t.get_height()), Color(1, 1, 1, 0.7))
	# rutan under musen
	var mus := get_global_mouse_position()
	var c := Vector2i(floori(mus.x / RUTA), floori(mus.y / RUTA))
	if c.y >= 0 and c.y < bana.hojd:
		draw_rect(Rect2(c * RUTA, Vector2(RUTA, RUTA)), Color(1, 0.85, 0.2, 0.9), false, 2.0)
