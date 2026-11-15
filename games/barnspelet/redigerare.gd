extends Node2D
## Redigeraren (användaren 15 nov: "jag startar editering och lägger in fienderna och plattformar").
## E i spelet → här: spelet står still, rutnät, en meny med bilder längst ner.
##   vänsterklick/dra = lägg ut det valda   högerklick/dra = ta bort   Ctrl+Z = ångra
##   A/D, pilarna, mushjulet = flytta (Shift = fortare), W/S = upp/ner   1–9, 0 = välj i menyn
##   Ctrl+hjulet eller +/− = zooma ut/in (mer av banan syns; 40–100 %)
##   Insert/Delete = tom kolumn in/ut där musen är
##   Tab = visa/göm menyn   E = spela härifrån   Enter = spela från början   Esc = avsluta
## Varje ändring sparas direkt i banor/<namn>.txt och banan byggs om (samma bygge som när man spelar).
## Bara för den vuxne – barnet ser aldrig det här (inga ord i själva spelet).

const RUTA := 48
## [tecken, namn, bild (blad, ruta), (när det visas)] – ordningen = menyn. Det fjärde: ett tema (banans json
## "tema") – bara på de banorna (användaren 15 nov: "jag behöver inte kunna se djungeltema grejer" i snön);
## "bild:<ruta>" = bara när banans markblad har den rutan (vatten, is). Utan = på alla banor.
const VERKTYG := [
	[".", "Sudd – ta bort (eller högerklick)", ["sudd", ""]],
	["G", "Mark", ["mark", "gras"]],
	["=", "Gren", ["mark", "planka"]],
	["X", "Block 1 (följer banans tema)", ["block", "sten"]],
	["L", "Block 2 (följer banans tema)", ["block", "lada"]],
	["W", "Vatten", ["mark", "vattenyta"], "bild:vattenyta"],
	["I", "Is – halt", ["mark", "is"], "bild:is"],
	["/", "Backe upp", ["backe", "1"]],
	["\\", "Backe ner", ["backe", "-1"]],
	["k", "Knapp", ["knapp", ""]],
	["h", "Hjärta", ["hjarta", ""]],
	["r", "Racerbil", ["racerbil", "kor1"]],
	["s", "Orm", ["orm", "orm1"], "djungel"],
	["p", "Papegoja", ["papegoja", "papegoja1"], "djungel"],
	["c", "Krokodil", ["krokodil", "krokodil1"], "djungel"],
	["o", "Palm", ["palm", ""], "djungel"],
	["b", "Banan", ["banan", ""], "djungel"],
	["u", "Bananbuske", ["buske", ""], "djungel"],
	["q", "Pulka", ["pulka", "pulka1"], "sno"],
	["m", "Snöplog (trampa två gånger)", ["plog", "plog1"], "sno"],
	["n", "Snöhög (snöbollar rullar ut)", ["snohog", ""], "sno"],
	["d", "Snöklot (till snögubbens kompis)", ["snoklot", ""], "sno"],
	["Z", "Kvicksand (sjunker, hoppa ur)", ["mark", "kvicksand"], "bild:kvicksand"],
	["a", "Krabba", ["krabba", "krabba1"], "sand"],
	["x", "Skorpion (trampa när svansen är nere)", ["skorpion", "uppe"], "sand"],
	["C", "Kaktus (hoppa över)", ["kaktus", ""], "sand"],
	["g", "Gam (dyker)", ["gam", "gam1"], "sand"],
	["w", "Vindvirvel (tumbleweeds rullar ut)", ["vindvirvel", ""], "sand"],
	["v", "Vind (hela kolumnen, knuffar bakåt)", ["vind", ""], "sand"],
	["t", "Skatt (ducka på glittret)", ["skatt", ""], "sand"],
	["y", "Sanddyna (fyller hinken)", ["sanddyn", ""], "sand"],
	["O", "Boss (följer banan)", ["boss", ""]],
	["F", "Flagga", ["flagga", ""]],
	["B", "Bur", ["bur", ""]],
	["P", "Start", ["pojken", "sta"]],
]
const ENSAM := ["P", "O"]  ## finns bara en gång – den gamla tas bort
## Menyn = en panel till vänster som fälls in/ut (knappen i hörnet eller Tab) och skrollas med hjulet
## (användaren 15 nov: raden längst ner skymde)
const PANEL_BREDD := 156.0

var bana: Node2D
var _knappar: Array[Button] = []
var _synliga: Array[int] = []  ## VERKTYG-index som visas på den här banan (1–9, 0 väljer bland dem)
var _panel: PanelContainer
var _fall: Button


func _ready() -> void:
	z_index = 50
	var lager := CanvasLayer.new()
	lager.layer = 10
	add_child(lager)
	_panel = PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0.08, 0.06, 0.12, 0.9)
	stil.set_content_margin_all(6)
	stil.content_margin_top = 40
	_panel.add_theme_stylebox_override("panel", stil)
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(PANEL_BREDD, 540)
	lager.add_child(_panel)
	var rull := ScrollContainer.new()
	rull.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(rull)
	var rad := GridContainer.new()
	rad.columns = 2
	rad.add_theme_constant_override("h_separation", 4)
	rad.add_theme_constant_override("v_separation", 4)
	rull.add_child(rad)
	for i in VERKTYG.size():
		if _visas(VERKTYG[i]):
			_synliga.append(i)
	for i in VERKTYG.size():
		var v: Array = VERKTYG[i]
		var b := Button.new()
		b.visible = i in _synliga
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(66, 52)
		b.tooltip_text = "%s (%s)" % [v[1], _tangent(_synliga.find(i))]
		b.icon = _ikon(v[2][0], v[2][1])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_valj.bind(i))
		rad.add_child(b)
		_knappar.append(b)
	_fall = Button.new()
	_fall.focus_mode = Control.FOCUS_NONE
	_fall.position = Vector2(6, 6)
	_fall.custom_minimum_size = Vector2(40, 28)
	_fall.icon = _pil()
	_fall.tooltip_text = "Visa/göm menyn (Tab)"
	_fall.pressed.connect(_falla)
	lager.add_child(_fall)
	_visa_panel()
	_valj(Spel.red_verktyg if Spel.red_verktyg in _synliga else 1)  # ett gömt verktyg (annan bana) → marken
	bana.kamera.limit_bottom = int(bana.hojd * RUTA)
	if Spel.red_zoom < 0.0:  # nyss öppnad: som banan ser ut när man spelar
		Spel.red_zoom = bana.zoom()
	_zooma(0.0)
	bana.kamera.reset_smoothing()


func _falla() -> void:
	Spel.red_meny = not Spel.red_meny
	_visa_panel()


func _visa_panel() -> void:
	_panel.visible = Spel.red_meny
	_fall.icon = _pil()


## En liten pil ritad här (◀ när menyn är öppen, ▶ när den är gömd)
func _pil() -> ImageTexture:
	var img := Image.create(12, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		var w := 7 - absi(y - 7) if y < 14 else 0
		for x in range(w):
			var px := (11 - x - 2) if Spel.red_meny else (x + 2)
			img.set_pixel(clampi(px, 0, 11), y, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)


func _tangent(i: int) -> String:
	return str((i + 1) % 10) if i >= 0 and i < 10 else "–"


## Visas verktyget på den här banan? (banor utan "tema" – provbanan – visar allt)
func _visas(v: Array) -> bool:
	if v.size() < 4:
		return true
	var villkor: String = v[3]
	if villkor.begins_with("bild:"):
		var m: String = bana._meta.get("mark", "mark")
		return villkor.substr(5) in Bilder.info(m)["frames"]
	var tema: String = bana._meta.get("tema", "")
	return tema == "" or tema == villkor


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
	if blad == "vind":  # tre streck med pil åt vänster
		var vi := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in [4, 8, 12]:
			for x in range(2, 15):
				vi.set_pixel(x, y, Color(0.98, 0.86, 0.55))
			vi.set_pixel(3, y - 1, Color(0.98, 0.86, 0.55))
			vi.set_pixel(3, y + 1, Color(0.98, 0.86, 0.55))
		return ImageTexture.create_from_image(vi)
	if blad == "skatt":
		return bana._glitter()
	if blad == "backe":
		return bana.backe_bild(int(ruta))
	if blad == "boss":  # banans egen boss (banor/<namn>.json "boss")
		var bs: String = bana._meta.get("boss", "orangutang")
		return Bilder.bild(bs, "") if FileAccess.file_exists("res://bilder/%s.json" % bs) else null
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
		_flytta(dx * fart * dt / Spel.red_zoom)
	var dy := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dy -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dy += 1.0
	if dy != 0.0:
		Spel.red_kamera.y += dy * fart * dt / Spel.red_zoom
		_flytta(0.0)
	# måla
	var mus := _mus()
	var c := Vector2i(floori(mus.x / RUTA), floori(mus.y / RUTA))
	var mp := get_viewport().get_mouse_position()
	var over_menyn := (Spel.red_meny and mp.x < PANEL_BREDD) or (mp.x < 50 and mp.y < 40)
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


## Musen i banan – räknad här ur redigerarens eget kameraläge och zoom, inte ur kameran: efter varje ändring
## byggs banan om, och första bildrutan efter det stod kameran (fysikens mjuka rörelse) någon annanstans –
## med knappen nedtryckt hamnade saken där, banan byggdes om igen … "lägger ut samma sak lite överallt"
## (användaren 15 nov)
func _mus() -> Vector2:
	var vp := get_viewport()
	return Spel.red_kamera + (vp.get_mouse_position() - vp.get_visible_rect().size / 2.0) / Spel.red_zoom


## Kamerans lägsta läge: banans botten precis ovanför menyn
func _lagst() -> float:
	return bana.hojd * RUTA - 270.0 / Spel.red_zoom


## Zooma (steg: −0,1 = ut). Kameran håller sig inom banan; är banan lägre än det som syns ligger den
## i nederkanten och himlen syns ovanför.
func _zooma(steg: float) -> void:
	Spel.red_zoom = clampf(snappedf(Spel.red_zoom + steg, 0.1), 0.4, 1.0)
	var z := Spel.red_zoom
	bana.kamera.zoom = Vector2(z, z)
	bana.kamera.limit_top = mini(0, int(bana.hojd * RUTA - 540.0 / z))
	_flytta(0.0)
	bana.kamera.reset_smoothing()


func _flytta(d: float) -> void:
	var halv := 480.0 / Spel.red_zoom
	Spel.red_kamera.x = clampf(Spel.red_kamera.x + d, halv, maxf(halv, (bana.bredd + 20) * RUTA - halv))
	Spel.red_kamera.y = clampf(Spel.red_kamera.y, minf(270.0 / Spel.red_zoom, _lagst()), _lagst())
	bana.kamera.position = Spel.red_kamera


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.ctrl_pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zooma(0.1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_flytta(-RUTA * 2.0 / Spel.red_zoom)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_flytta(RUTA * 2.0 / Spel.red_zoom)
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_TAB:
			_falla()
		elif e.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_zooma(-0.1)
		elif e.keycode in [KEY_PLUS, KEY_KP_ADD, KEY_EQUAL]:
			_zooma(0.1)
		elif e.keycode == KEY_Z and e.ctrl_pressed:
			_angra()
		elif e.keycode == KEY_INSERT or e.keycode == KEY_DELETE:
			_kolumn(e.keycode == KEY_INSERT, floori(_mus().x / RUTA))
		elif e.keycode >= KEY_0 and e.keycode <= KEY_9:
			var i: int = (e.keycode - KEY_0 + 9) % 10
			if i < _synliga.size():
				_valj(_synliga[i])


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


## Insert: en tom kolumn där musen är (allt till höger flyttas ett steg åt höger); Delete: kolumnen bort
## (allt efter flyttas tillbaka). Så blir banan längre/kortare var som helst. Ctrl+Z ångrar.
func _kolumn(infoga: bool, x: int) -> void:
	var pa_disk := FileAccess.get_file_as_string(bana.fil()).strip_edges(false, true)
	var rader: Array = Array(pa_disk.split("\n")) if pa_disk != "" else Array(bana.rader)
	if x < 0:
		return
	Spel.red_historik.append(pa_disk)
	for y in rader.size():
		var r: String = rader[y].rpad(x + 1, ".")
		rader[y] = (r.substr(0, x) + "." + r.substr(x)) if infoga else (r.substr(0, x) + r.substr(x + 1))
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
	var x0 := floori((kam.x - 480.0 / Spel.red_zoom) / RUTA)
	var x1 := ceili((kam.x + 480.0 / Spel.red_zoom) / RUTA)
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
			elif r[x] == "v":  # vinden: hela kolumnen svagt sandfärgad (syns annars bara när det blåser)
				draw_rect(Rect2(x * RUTA, 0, RUTA, bana.hojd * RUTA), Color(0.98, 0.86, 0.55, 0.18))
			elif r[x] == "P":
				var t := Bilder.bild("pojken", "sta")
				draw_texture(t, Vector2(x * RUTA + 24 - t.get_width() / 2.0, (y + 1) * RUTA - t.get_height()), Color(1, 1, 1, 0.7))
	# rutan under musen
	var mus := _mus()
	var c := Vector2i(floori(mus.x / RUTA), floori(mus.y / RUTA))
	if c.y >= 0 and c.y < bana.hojd:
		draw_rect(Rect2(c * RUTA, Vector2(RUTA, RUTA)), Color(1, 0.85, 0.2, 0.9), false, 2.0)
