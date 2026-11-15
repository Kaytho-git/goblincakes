extends Node2D
## En bana ur banor/<namn>.txt – en rad per rutrad (48 × 48 spelpixlar) – och banor/<namn>.json
## ({"mark": blad med rutorna, "bakgrund": bild}, valfri):
##   .  luft          G  markyta (allt under fylls med jord)    =  planka/gren (hoppa upp underifrån)
##   X  stenblock    L  trälåda   (block: fasta åt alla håll, staplas, fyller inte under sig)
##   W  vattenyta (vatten fylls under – i vattnet blir det "oj")   c  krokodil i vattnet (räknas som W)
##   k  knapp         h  hjärta (ett liv)        b  banan (bärs, kastas med B)   u  bananbuske (nya bananer)
##   r  racerbil      s  orm      p  papegoja    o  palm med kokosnöt             O  bossen (orangutangen)
##   F  flagga (börja om här)    B  buren med gossedjuret (mål; med en boss: öppen först när den sover)
##   P  start
## Snön (bana 2, 15 nov):
##   I  isplatta (halt – man glider; jord under)   /  backe upp åt höger   \\  backe ner åt höger (jord under)
##   q  pulka med ögon    m  snöplog (trampas två gånger)    n  snöhög (snöbollar rullar ut)
##   d  snöklot (bärs till snögubben, lämnas med B)
## Bossen (O) står i banans json "boss" (orangutang, snogubbe); "triumf" = bilden vid målet.

const RUTA := 48
const MARKYTA := 9 * 48.0  ## markens vanliga höjd (rad 9)
## Markrutorna ritas så här mycket högre än där man står: gräset är ~15 px tjockt (rad 5–20 i rutan) och
## fötterna ska stå mitt i det – annars ser allt ut att sväva på grästopparna (användaren 15 nov)
const MARK_UPP := 12.0
const VATTEN_NER := 20.0  ## vattenytan ligger en bit ner i gropen, inte i höjd med gräset (användaren 15 nov)

var bredd := 0
var hojd := 0
var botten := 0.0
var pojke: CharacterBody2D
var kamera: Camera2D
var fiender: Array = []
var boss: Node2D
var saker: Array = []  ## {"typ", "nod", "rect", "y"}
var klar := false
## Vid målet (användaren 15 nov): fiender utslagna av alla som går att slå ut, knappar plockade av alla –
## i det sista försöket (banan laddas om när man dör, och allt kommer tillbaka)
var utslagna := 0
var _alla_fiender := 0
var _alla_knappar := 0
var plockade := 0
var rader: PackedStringArray

var _fast := {}
var _plankor := {}
var _mark := {}    ## bara marken (G och jorden under) – gräset ritas där inget mark ligger ovanför
var _block := {}   ## Vector2i → 0 sten, 1 trälåda
var _vatten := {}  ## Vector2i → true för ytan, false under
var _backar := {}  ## Vector2i → 1 backe upp åt höger (/), -1 ner åt höger (\\)
var _is := {}      ## isplattornas rutor (halt)
var _bar: Sprite2D  ## snöklotet pojken bär (null = inget)
var _meta := {}
var _kastade: Array = []  ## {"nod", "v", "studsad"}
var _buskar: Array = []
var _busk_tid := 0.0
var _start := Vector2.ZERO
var _tid := 0.0


func _ready() -> void:
	if Spel.fran_meny and not Spel.meny_visad:  # -- --meny: banväljaren först
		Spel.meny_visad = true
		set_process(false)
		set_physics_process(false)
		get_tree().change_scene_to_file.call_deferred("res://meny.tscn")
		return
	Spel.bananer = 0
	if not FileAccess.file_exists(fil()):
		_ny_bana()
	var text := FileAccess.get_file_as_string(fil())
	if FileAccess.file_exists("res://banor/%s.json" % Spel.bana):
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://banor/%s.json" % Spel.bana))
	rader = text.strip_edges(false, true).split("\n")
	hojd = rader.size()
	for r in rader:
		bredd = maxi(bredd, r.length())
	botten = hojd * RUTA
	_bakgrund()
	_rutor(rader)
	_figurer(rader)
	_testa_harifran()
	_alla_fiender = fiender.filter(func(f): return f.trampbar).size()
	_alla_knappar = saker.filter(func(x): return x["typ"] == "knapp").size()
	_ny_pojke()
	_ny_kamera()
	_hud()
	if Spel.redigerar:
		_redigera()


func fil() -> String:
	return ProjectSettings.globalize_path("res://banor/%s.txt" % Spel.bana)


## En ny bana (-- --bana <namn> som inte finns): mark hela vägen, start till vänster
func _ny_bana() -> void:
	var r := []
	for y in 12:
		r.append(("..P" + ".".repeat(37)) if y == 8 else ("G".repeat(40) if y == 9 else ".".repeat(40)))
	var f := FileAccess.open(fil(), FileAccess.WRITE)
	f.store_string("\n".join(r) + "\n")
	f.close()


## "Spela härifrån" (E i redigeraren): på marken i den kolumn man tittade på
func _testa_harifran() -> void:
	if Spel.redigerar or Spel.test_start == Vector2.ZERO:
		return
	var x := clampi(floori(Spel.test_start.x / RUTA), 0, bredd - 1)
	for y in hojd:
		if _fast.has(Vector2i(x, y)) or _plankor.has(Vector2i(x, y)):
			_start = Vector2(x * RUTA + RUTA / 2.0, y * RUTA)
			return


func _redigera() -> void:
	pojke.visible = false
	pojke.set_physics_process(false)
	for f in fiender:
		f.process_mode = Node.PROCESS_MODE_DISABLED
	kamera.position_smoothing_enabled = false
	kamera.limit_right += 20 * RUTA
	kamera.position = Spel.red_kamera
	kamera.reset_smoothing()
	for c in get_children():
		if c is CanvasLayer:
			c.visible = false  # inga hjärtan/knappar medan man redigerar
	var r := Node2D.new()
	r.set_script(load("res://redigerare.gd"))
	r.bana = self
	add_child(r)


func fast(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x / RUTA), floori(p.y / RUTA))
	if _backar.has(c):  # under den sneda ytan
		var lx := p.x - c.x * RUTA
		var ly := p.y - c.y * RUTA
		return ly >= (RUTA - lx if _backar[c] > 0 else lx)
	return _fast.has(c)


## En vägg framför det som går på marken: fast, men inte en backe (den går man uppför)
func vagg(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x / RUTA), floori(p.y / RUTA))
	return _fast.has(c) and not _backar.has(c)


## Halt under fötterna (isplattorna)
func halt(p: Vector2) -> bool:
	return _is.has(Vector2i(floori(p.x / RUTA), floori((p.y + 2.0) / RUTA)))


## Lutningen där man står: 1 = backe upp åt höger, -1 = ner åt höger, 0 = plant
func backe(p: Vector2) -> int:
	for dy in [-2.0, 2.0]:
		var c := Vector2i(floori(p.x / RUTA), floori((p.y + dy) / RUTA))
		if _backar.has(c):
			return _backar[c]
	return 0


## För det som går/rullar på marken: tyngden, och står man i marken (backar) lyfts man upp till ytan
func pa_marken(pos: Vector2, vy: float, dt: float) -> Array:
	vy = minf(vy + 3800.0 * dt, 950.0)
	var ny := pos.y + vy * dt
	if fast(Vector2(pos.x, ny)):
		var n := 0
		while fast(Vector2(pos.x, ny)) and n < 60:
			ny = floorf(ny) - 1.0
			n += 1
		ny += 0.999
		vy = 0.0
	return [Vector2(pos.x, ny), vy]


# ── Bygget ───────────────────────────────────────────────────────

func _rutor(rader: PackedStringArray) -> void:
	for y in hojd:
		for x in rader[y].length():
			match rader[y][x]:
				"G", "I":
					for yy in range(y, hojd):
						_fast[Vector2i(x, yy)] = true
						_mark[Vector2i(x, yy)] = true
					if rader[y][x] == "I":
						_is[Vector2i(x, y)] = true
				"/", "\\":
					_backar[Vector2i(x, y)] = 1 if rader[y][x] == "/" else -1
					for yy in range(y + 1, hojd):
						_fast[Vector2i(x, yy)] = true
						_mark[Vector2i(x, yy)] = true
				"X", "L":
					_fast[Vector2i(x, y)] = true
					_block[Vector2i(x, y)] = 0 if rader[y][x] == "X" else 1
				"=":
					_plankor[Vector2i(x, y)] = true
				"W", "c":
					for yy in range(y, hojd):
						_vatten[Vector2i(x, yy)] = yy == y
	var ts := TileSet.new()
	ts.tile_size = Vector2i(RUTA, RUTA)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	var mark: String = _meta.get("mark", "mark")
	src.texture = Bilder.textur(mark)
	var namn: Array = Bilder.info(mark)["frames"]
	var antal := namn.size()
	var nr := func(n: String) -> int:  # rutan med det namnet (snön har is där djungeln har vatten)
		return maxi(0, namn.find(n))
	src.texture_region_size = Vector2i(RUTA, RUTA)
	var sid := ts.add_source(src)
	var h := RUTA / 2.0
	for i in antal:
		src.create_tile(Vector2i(i, 0))
		if namn[i].begins_with("vatten"):
			continue  # vattnet: ingen krock
		var td := src.get_tile_data(Vector2i(i, 0), 0)
		td.add_collision_polygon(0)
		if namn[i].begins_with("planka"):  # plankan: bara överkanten, och bara uppifrån
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 14), Vector2(-h, -h + 14)]))
			td.set_collision_polygon_one_way(0, 0, true)
		else:
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	# två lager: det man står på (osynligt, på rutnätet) och det som syns (MARK_UPP högre, ingen krock)
	var lager := TileMapLayer.new()
	lager.tile_set = ts
	lager.modulate = Color(1, 1, 1, 0)
	add_child(lager)
	var syns := TileMapLayer.new()
	syns.tile_set = ts
	syns.collision_enabled = false
	syns.position.y = -MARK_UPP
	add_child(syns)
	var isyns := TileMapLayer.new()
	isyns.tile_set = ts
	isyns.collision_enabled = false
	add_child(isyns)
	var yta := _mark.duplicate()  # backarna räknas som mark när kanterna väljs (inget kantgräs mot en backe)
	yta.merge(_backar)
	var kantnamn := ["_v", "", "_h"]
	for c in _mark:
		var topp := not _mark.has(c + Vector2i.UP) and not _backar.has(c + Vector2i.UP)
		var ruta := Vector2i(nr.call(("gras" if topp else "jord") + kantnamn[_kant(yta, c)]), 0)
		if _is.has(c) and namn.has("is"):
			# isen syns utan MARK_UPP (ingen snö att sjunka ner i) – i eget lager framför marken
			ruta = Vector2i(nr.call("is" + kantnamn[_kant(_is, c)]), 0)
			lager.set_cell(c, sid, ruta)
			isyns.set_cell(c, sid, ruta)
			continue
		lager.set_cell(c, sid, ruta)
		syns.set_cell(c, sid, ruta)
		if c.y == hojd - 1:  # en rad till under: den synliga marken är MARK_UPP högre och ska nå skärmens nederkant
			syns.set_cell(c + Vector2i.DOWN, sid, ruta)
	for c in _plankor:
		var ruta := Vector2i(nr.call("planka" + kantnamn[_kant(_plankor, c)]), 0)
		lager.set_cell(c, sid, ruta)
		syns.set_cell(c, sid, ruta)
	# blocken följer banans tema (banor/<namn>.json "block" – djungeln: djungel-block), krock i det osynliga lagret,
	# syns utan MARK_UPP (inget gräs att sjunka ner i)
	var bblad: String = _meta.get("block", "")
	if not _block.is_empty() and FileAccess.file_exists("res://bilder/%s.json" % bblad):
		var bsrc := TileSetAtlasSource.new()
		bsrc.texture = Bilder.textur(bblad)
		bsrc.texture_region_size = Vector2i(RUTA, RUTA)
		var bid := ts.add_source(bsrc)
		for i in Bilder.info(bblad)["frames"].size():
			bsrc.create_tile(Vector2i(i, 0))
			var td := bsrc.get_tile_data(Vector2i(i, 0), 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
		var blocksyns := TileMapLayer.new()
		blocksyns.tile_set = ts
		blocksyns.collision_enabled = false
		add_child(blocksyns)
		for c in _block:
			lager.set_cell(c, bid, Vector2i(_block[c], 0))
			blocksyns.set_cell(c, bid, Vector2i(_block[c], 0))
	if not _backar.is_empty():
		_backar_lager(ts, mark, lager, syns)
	if namn.has("vatten"):
		var vatten := TileMapLayer.new()  # framför pojken och krokodilen
		vatten.tile_set = ts
		vatten.position.y = VATTEN_NER
		vatten.collision_enabled = false
		vatten.z_index = 8
		vatten.modulate = Color(1, 1, 1, 0.92)
		add_child(vatten)
		for c in _vatten:
			vatten.set_cell(c, sid, Vector2i(nr.call("vattenyta" if _vatten[c] else "vatten"), 0))


## Backarna: rutorna görs här av banans egna gräs- och jordrutor (varje kolumn flyttas ner så att ytan
## följer diagonalen) – så får alla teman backar utan nya bilder. Krocken = en triangel.
var backe_bilder := {}  ## 1/-1 → ImageTexture (redigerarens meny använder dem också)


func backe_bild(riktning: int) -> Texture2D:
	if backe_bilder.is_empty():
		var mark: String = _meta.get("mark", "mark")
		var namn: Array = Bilder.info(mark)["frames"]
		var blad := Bilder.textur(mark).get_image()
		blad.decompress()
		var gras := blad.get_region(Rect2i(maxi(0, namn.find("gras")) * RUTA, 0, RUTA, RUTA))
		var jord := blad.get_region(Rect2i(maxi(0, namn.find("jord")) * RUTA, 0, RUTA, RUTA))
		for r in [1, -1]:
			var img := Image.create(RUTA, RUTA, false, Image.FORMAT_RGBA8)
			for x in RUTA:
				var ner := (RUTA - 1 - x) if r > 0 else x  # ytans höjd i den här kolumnen
				for y in range(ner, RUTA):
					var k := y - ner
					img.set_pixel(x, y, gras.get_pixel(x, k) if k < RUTA else jord.get_pixel(x, k - RUTA))
			backe_bilder[r] = ImageTexture.create_from_image(img)
	return backe_bilder[riktning]


func _backar_lager(ts: TileSet, mark: String, lager: TileMapLayer, syns: TileMapLayer) -> void:
	var src := TileSetAtlasSource.new()
	var img := Image.create(RUTA * 2, RUTA, false, Image.FORMAT_RGBA8)
	img.blit_rect(backe_bild(1).get_image(), Rect2i(0, 0, RUTA, RUTA), Vector2i(0, 0))
	img.blit_rect(backe_bild(-1).get_image(), Rect2i(0, 0, RUTA, RUTA), Vector2i(RUTA, 0))
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(RUTA, RUTA)
	var id := ts.add_source(src)
	var h := RUTA / 2.0
	for i in 2:
		src.create_tile(Vector2i(i, 0))
		var td := src.get_tile_data(Vector2i(i, 0), 0)
		td.add_collision_polygon(0)
		var tri := PackedVector2Array([Vector2(-h, h), Vector2(h, -h), Vector2(h, h)]) if i == 0 \
				else PackedVector2Array([Vector2(-h, -h), Vector2(h, h), Vector2(-h, h)])
		td.set_collision_polygon_points(0, 0, tri)
	for c in _backar:
		var ruta := Vector2i(0 if _backar[c] > 0 else 1, 0)
		lager.set_cell(c, id, ruta)
		syns.set_cell(c, id, ruta)


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
					_sak("bur", golv, false, _meta.get("bur", "bur"))  # buren med banans gossedjur
				"r":
					ny_fiende("gangare", golv, {"typ": "racerbil"})
				"s":
					ny_fiende("gangare", golv, {"typ": "orm"})
				"p":
					ny_fiende("papegoja", mitt)
				"c":
					ny_fiende("krokodil", Vector2(golv.x, y * RUTA + VATTEN_NER + 6.0))
				"o":
					ny_fiende("kokos", golv)
				"b":
					_sak("banan", golv, false)
				"u":
					var b := Sprite2D.new()
					b.texture = Bilder.textur("buske")
					var c: Vector2 = Bilder.cell("buske")
					b.centered = false
					b.offset = Vector2(-c.x / 2.0, -c.y)
					b.position = golv
					b.z_index = -2
					add_child(b)
					_buskar.append(golv)
				"q":
					ny_fiende("gangare", golv, {"typ": "pulka"})
				"m":
					ny_fiende("gangare", golv, {"typ": "plog"})
				"n":
					ny_fiende("snohog", golv)
				"d":
					_sak("snoklot", golv, false)
				"O":
					boss = ny_fiende(_meta.get("boss", "orangutang"), golv)
					boss.somnade.connect(func(): Spel.ljud("raddad"))


func _sak(typ: String, pos: Vector2, svavar: bool, bild := "") -> Dictionary:
	var s := Sprite2D.new()
	if bild == "" or not FileAccess.file_exists("res://bilder/%s.json" % bild):
		bild = typ
	s.texture = Bilder.textur(bild)
	var c: Vector2 = Bilder.cell(bild)
	s.centered = false
	s.offset = -c / 2.0 if svavar else Vector2(-c.x / 2.0, -c.y)
	s.position = pos
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # guppar i _process
	add_child(s)
	if typ == "snoklot":
		var g := Sprite2D.new()
		g.texture = _glitter()
		g.modulate.a = 0.0
		s.add_child(g)
	var r := Rect2(pos - c / 2.0, c) if svavar else Rect2(pos - Vector2(c.x / 2.0, c.y), c)
	var sak := {"typ": typ, "nod": s, "rect": r, "y": pos.y, "svavar": svavar}
	saker.append(sak)
	return sak


## Ett litet glitter (fyruddig stjärna, ritad här)
var _glitter_bild: ImageTexture


func _glitter() -> ImageTexture:
	if _glitter_bild == null:
		var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
		for i in 9:
			var a := 1.0 - absf(i - 4) / 5.0
			img.set_pixel(i, 4, Color(1, 0.93, 0.45, a))  # ljusgult – vitt syntes inte mot snön
			img.set_pixel(4, i, Color(1, 0.93, 0.45, a))
		img.set_pixel(3, 3, Color(1, 1, 0.8, 0.8))
		img.set_pixel(5, 5, Color(1, 1, 0.8, 0.8))
		img.set_pixel(3, 5, Color(1, 1, 0.8, 0.8))
		img.set_pixel(5, 3, Color(1, 1, 0.8, 0.8))
		_glitter_bild = ImageTexture.create_from_image(img)
	return _glitter_bild


func ny_fiende(skript: String, pos: Vector2, egenskaper := {}) -> Node2D:
	var f := Node2D.new()
	f.set_script(load("res://%s.gd" % skript))
	f.bana = self
	f.position = pos
	for k in egenskaper:
		f.set(k, egenskaper[k])
	add_child(f)
	fiender.append(f)
	return f


func ny_bil(golv: Vector2) -> Node2D:
	return ny_fiende("gangare", golv, {"typ": "racerbil"})


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
	if Spel.redigerar:
		return
	if not klar:
		Spel.tid += _dt
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
	if _vatten.has(Vector2i(floori(pojke.position.x / RUTA), floori((pojke.position.y - 10.0 - VATTEN_NER) / RUTA))):
		pojke.do()  # i vattnet
		return
	var pr: Rect2 = pojke.rect()
	fiender = fiender.filter(func(b): return is_instance_valid(b))
	for b in fiender:
		var r: Rect2 = b.rect()
		if b.platt or not r.has_area() or not pr.intersects(r):
			continue
		# uppifrån och på väg ner = trampa (om den går att trampa på); en glidning slår ut det som går på
		# marken (ormar, bilar); annars "oj"
		# (snöplogen tål ett tramp – den räknas som utslagen först när den är platt)
		if b.trampbar and pojke.glider and b.get_script().resource_path.ends_with("gangare.gd"):
			b.platta()
			utslagna += 1 if b.platt else 0
			Spel.ljud("trampa")
		elif b.trampbar and pojke.velocity.y > 0.0 and pojke.position.y < r.position.y + 22.0:
			b.platta()
			utslagna += 1 if b.platt else 0
			pojke.studsa()
		else:
			pojke.do()
			return
	if boss and not boss.sover:  # den vakna bossen går inte att gå igenom
		var k: Rect2 = boss.kropp()
		if pr.intersects(k):
			pojke.position.x = k.position.x - pojke.BREDD / 2.0 if pojke.position.x < k.get_center().x else k.end.x + pojke.BREDD / 2.0
			pojke.velocity.x = 0.0
	_zooma(_dt)
	_bananer(_dt)
	for s in saker.duplicate():
		if not pr.intersects(s["rect"]):
			continue
		match s["typ"]:
			"knapp":
				Spel.ta_knapp()
				plockade += 1
				_ta_bort(s)
			"hjarta":
				Spel.nytt_liv()
				_ta_bort(s)
			"banan":
				Spel.bananer += 1
				Spel.ljud("knapp")
				_ta_bort(s)
			"snoklot":
				if _bar == null and _special_slapp:  # en i taget; inte samma tryck som nyss släppte den
					_ta_bort(s)
					_bar = Sprite2D.new()
					_bar.texture = Bilder.textur("snoklot")
					_bar.position = Vector2(0, -pojke.HOJD - 20.0)
					pojke.add_child(_bar)
					Spel.ljud("knapp")
			"flagga":
				if not is_equal_approx(Spel.flagga, s["nod"].position.x):
					Spel.flagga = s["nod"].position.x
					s["nod"].modulate = Color(1, 1, 0.6)
					Spel.ljud("flagga")
			"bur":
				if not boss or boss.sover:
					_raddad(s)


## Bananerna: B kastar (i en båge framåt), träff i bossens öppna mun = mat; bananbuskar ger nya
## när man inte har några och inga ligger framme (man ska aldrig kunna fastna)
var _special_forra := false


func _bananer(dt: float) -> void:
	var b := Spel.special_nere()
	_special_slapp = _special_slapp or not b
	if b and not _special_forra and _bar != null:
		_lamna()
	elif b and not _special_forra and Spel.bananer > 0:
		Spel.bananer -= 1
		var n := Sprite2D.new()
		n.texture = Bilder.textur("banan")
		var vand := -1.0 if pojke._vand < 0.0 else 1.0
		n.position = pojke.position + Vector2(vand * 24.0, -64.0)
		n.z_index = 6
		add_child(n)
		_kastade.append({"nod": n, "v": Vector2(vand * 430.0, -420.0), "studsad": false})
		Spel.ljud("kasta")
	_special_forra = b
	for k in _kastade.duplicate():
		var n: Sprite2D = k["nod"]
		k["v"].y += 1400.0 * dt
		n.position += k["v"] * dt
		n.rotation += 12.0 * dt * signf(k["v"].x)
		var r := Rect2(n.position - Vector2(12, 12), Vector2(24, 24))
		var bort := fast(n.position) or n.position.y > botten
		if not bort and boss and not boss.sover and not k["studsad"] and boss.has_method("mun"):
			if boss.mun().has_area() and r.intersects(boss.mun()):
				boss.mata()
				bort = true
			elif r.intersects(boss.kropp()):
				k["v"] = Vector2(-k["v"].x * 0.35, -200.0)  # studsar bort från den stängda munnen
				k["studsad"] = true
		if bort:
			_kastade.erase(k)
			n.queue_free()
	_busk_tid += dt
	if _busk_tid > 3.0 and not _buskar.is_empty() and Spel.bananer == 0 and boss and not boss.sover:
		_busk_tid = 0.0
		if not saker.any(func(s): return s["typ"] == "banan"):
			_sak("banan", _buskar[0] + Vector2(56.0, 0.0), false)


## Snöklotet: B vid snögubbens kompis = en del till; annars läggs det ner framför fötterna (man ska aldrig fastna)
var _special_slapp := true


func _lamna() -> void:
	_bar.queue_free()
	_bar = null
	if boss and boss.has_method("lamna") and not boss.sover and absf(pojke.position.x - boss.kompis_x()) < 130.0:
		boss.lamna()
		return
	var vand := -1.0 if pojke._vand < 0.0 else 1.0
	var x := pojke.position.x + vand * 40.0
	if fast(Vector2(x, pojke.position.y - 20.0)):
		x = pojke.position.x
	_sak("snoklot", Vector2(x, pojke.position.y), false)
	_special_slapp = false  # plockas inte upp igen förrän B har släppts
	Spel.ljud("kasta")


## Vid en boss som vill ha plats (snögubben: man bygger bredvid) zoomar kameran ut lite
func _zooma(dt: float) -> void:
	var mal := 1.0
	if boss and not boss.sover and boss.get("ZOOM") != null and absf(pojke.position.x - boss.position.x) < 700.0:
		mal = boss.ZOOM
	var z := move_toward(kamera.zoom.x, mal, dt * 0.6)
	if is_equal_approx(z, kamera.zoom.x):
		return
	kamera.zoom = Vector2(z, z)
	# banan är bara 540 hög – det som syns ovanför den när man zoomar ut är himlen
	kamera.limit_top = mini(0, int(hojd * RUTA - 540.0 / z))


func Pojke_halv() -> float:
	return pojke.BREDD / 2.0


func _process(dt: float) -> void:
	_tid += dt
	for s in saker:
		if s["svavar"]:  # knappar och hjärtan guppar
			s["nod"].position.y = s["y"] + roundf(sin(_tid * 3.0 + s["nod"].position.x * 0.05) * 2.0)
		elif s["typ"] == "snoklot":  # studsar lite och glittrar – inte samma som de rullande snöbollarna (användaren 15 nov)
			var fas: float = _tid * 3.0 + s["nod"].position.x * 0.05
			s["nod"].position.y = s["y"] - roundf(absf(sin(fas)) * 5.0)
			var g: Sprite2D = s["nod"].get_child(0)
			var blink := fmod(_tid * 1.4 + s["nod"].position.x * 0.013, 1.0)  # ett glitter per varv, på ett nytt ställe
			var n := int(_tid * 1.4 + s["nod"].position.x * 0.013) % 3
			g.position = Vector2([-9.0, 8.0, -2.0][n], [-26.0, -18.0, -10.0][n])
			g.modulate.a = clampf(1.0 - absf(blink - 0.5) * 4.0, 0.0, 1.0)
			g.rotation = blink * 1.5
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
	_visa_tid()
	var t_bild := Sprite2D.new()
	var tb: String = _meta.get("triumf", "triumf")  # pojken med banans gossedjur
	t_bild.texture = Bilder.textur(tb)
	t_bild.centered = false
	var c: Vector2 = Bilder.cell(tb)
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
	await get_tree().create_timer(5.0).timeout
	Spel.flagga = -1.0  # steg 2: tillbaka till kartan
	Spel.test_start = Vector2.ZERO
	Spel.ny_runda()
	get_tree().reload_current_scene()


## Tiden när banan är klar (för den vuxne – siffror, inga ord): tiden stort, bästa tiden under,
## krona vid nytt rekord. Från "spela härifrån" grå och inget rekord.
func _visa_tid() -> void:
	var rekord := Spel.spara_tid(Spel.bana, Spel.tid)
	var basta := Spel.basta_tid(Spel.bana)
	var lager := CanvasLayer.new()
	lager.layer = 5
	add_child(lager)
	var ruta := VBoxContainer.new()
	ruta.position = Vector2(0, 40)
	ruta.size = Vector2(960, 140)
	ruta.alignment = BoxContainer.ALIGNMENT_BEGIN
	lager.add_child(ruta)
	var stor := LabelSettings.new()
	stor.font_size = 44
	stor.outline_size = 8
	stor.outline_color = Color(0.16, 0.1, 0.2)
	stor.font_color = Color(1.0, 0.85, 0.25) if rekord else (Color(1, 1, 1) if Spel.tid_giltig else Color(0.75, 0.75, 0.75))
	ruta.add_child(_tid_rad(Spel.tid, stor, rekord, 4))
	var rad := HBoxContainer.new()
	rad.alignment = BoxContainer.ALIGNMENT_CENTER
	rad.add_theme_constant_override("separation", 36)
	ruta.add_child(rad)
	var mellan := stor.duplicate()
	mellan.font_size = 28
	rad.add_child(_rakning(Bilder.bild("orm", "orm1") if Bilder.info("orm")["frames"].size() > 0 else null, utslagna, _alla_fiender, mellan))
	rad.add_child(_rakning(Bilder.textur("knapp"), plockade, _alla_knappar, mellan))
	if basta >= 0.0 and not rekord:
		var liten := stor.duplicate()
		liten.font_size = 24
		liten.font_color = Color(1.0, 0.85, 0.25)
		ruta.add_child(_tid_rad(basta, liten, true, 2))


## [bild] 8/8 – guld när allt är taget
func _rakning(bild: Texture2D, n: int, av: int, stil: LabelSettings) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if bild:
		var t := TextureRect.new()
		t.texture = bild
		t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(t)
	var l := Label.new()
	l.text = "%d/%d" % [n, av]
	var st := stil.duplicate()
	st.font_color = Color(1.0, 0.85, 0.25) if n >= av else Color(1, 1, 1)
	l.label_settings = st
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


## En rad: [krona] tid, centrerad
func _tid_rad(t: float, stil: LabelSettings, krona: bool, skala: int) -> HBoxContainer:
	var rad := HBoxContainer.new()
	rad.alignment = BoxContainer.ALIGNMENT_CENTER
	rad.add_theme_constant_override("separation", 10)
	if krona:
		var k := TextureRect.new()
		k.texture = _krona(skala)
		k.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		rad.add_child(k)
	var l := Label.new()
	l.text = Spel.tid_text(t)
	l.label_settings = stil
	rad.add_child(l)
	return rad


## En liten pixelkrona (rekord) – ritad här i stället för ett tecken som typsnittet kanske saknar
func _krona(skala: int) -> ImageTexture:
	var m := [
		"..#.....#.....#..",
		".#o#...#o#...#o#.",
		"..##..#####..##..",
		"..###########.#..",
		"..#############..",
		"..##o###o###o##..",
		"..#############..",
		"..#############..",
		".ddddddddddddddd.",
	]
	var img := Image.create(17 * skala, m.size() * skala, false, Image.FORMAT_RGBA8)
	var farg := {"#": Color(1.0, 0.82, 0.2), "o": Color(0.9, 0.25, 0.3), "d": Color(0.7, 0.45, 0.1)}
	for y in m.size():
		for x in 17:
			var c: String = m[y][x]
			if farg.has(c):
				img.fill_rect(Rect2i(x * skala, y * skala, skala, skala), farg[c])
	return ImageTexture.create_from_image(img)


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
	_hud_tid = Label.new()
	var ts := LabelSettings.new()
	ts.font_size = 22
	ts.outline_size = 5
	ts.outline_color = Color(0.16, 0.1, 0.2)
	_hud_tid.label_settings = ts
	_hud_tid.position = Vector2(830, 12)
	_hud_tid.size = Vector2(110, 30)
	_hud_tid.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lager.add_child(_hud_tid)
	_hud_bananer = HBoxContainer.new()
	_hud_bananer.position = Vector2(20, 84)
	_hud_bananer.add_theme_constant_override("separation", 2)
	lager.add_child(_hud_bananer)
	for i in 10:
		var fack := ColorRect.new()
		fack.position = Vector2(4 + i * 12, 4)
		fack.size = Vector2(10, 14)
		ram.add_child(fack)
		_hud_fack.append(fack)


var _hud_tid: Label
var _hud_hjartan: HBoxContainer
var _hud_bananer: HBoxContainer
var _visade_bananer := -1
var _hud_fack: Array[ColorRect] = []
var _visat_liv := -1


func _hud_uppdatera() -> void:
	_hud_tid.visible = Spel.visa_tid and not klar
	if _hud_tid.visible:
		_hud_tid.text = Spel.tid_text(Spel.tid)
	if _visat_liv != Spel.liv:
		_visat_liv = Spel.liv
		for c in _hud_hjartan.get_children():
			c.queue_free()
		for i in mini(Spel.liv, 12):
			var h := TextureRect.new()
			h.texture = Bilder.textur("hjarta")
			_hud_hjartan.add_child(h)
	if _visade_bananer != Spel.bananer:
		_visade_bananer = Spel.bananer
		for c in _hud_bananer.get_children():
			c.queue_free()
		for i in mini(Spel.bananer, 10):
			var b := TextureRect.new()
			b.texture = Bilder.textur("banan")
			_hud_bananer.add_child(b)
	var fulla := Spel.knappar / 10
	for i in 10:
		_hud_fack[i].color = Color(1.0, 0.8, 0.2) if i < fulla else Color(1, 1, 1, 0.15)


## Himmel (klar färg i project.godot), moln och kullar som rör sig långsammare än banan
func _bakgrund() -> void:
	if _meta.has("bakgrund"):
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(0.3, 1.0)
		var tex := Bilder.textur(_meta["bakgrund"])
		# himlen ovanför bilden (syns när kameran zoomar ut) = bildens översta färg
		var topp := tex.get_image()
		topp.decompress()
		RenderingServer.set_default_clear_color(topp.get_pixel(topp.get_width() / 2, 2))
		p.repeat_size = Vector2(tex.get_width() * 2.0, 0)
		p.repeat_times = 3
		p.z_index = -30
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(2, 2)  # bakgrunden ritad grövre (480 × 300 per halva)
		# överkanten i banans överkant (kameran går aldrig högre) och resten så långt ner det går: Kakans
		# blomrad längst ner ska ligga bakom marken (den såg ut som saker att plocka – "halva bananer")
		s.position = Vector2(0, 0)
		p.add_child(s)
		add_child(p)
		return
	RenderingServer.set_default_clear_color(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"))
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
