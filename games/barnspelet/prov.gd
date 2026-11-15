extends Node
## Prov utan fönster: godot --headless --path games/barnspelet -- --prov
## Styr pojken med låtsade knapptryck (Spel.prov_*) och mäter. Slutkod 0 = allt klarat.
## Med -- --bild <fil.png> [sekunder] i ett vanligt fönster: en skärmbild efter en stund (pojken går åt höger).

var _fel := 0
var bana: Node2D
var pojke: CharacterBody2D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--prov" in args:
		Spel.prov = true
		Spel.bana = "prov"
		_kor.call_deferred()
	elif "--prov-red" in args:
		Spel.prov = true
		Spel.bana = "provred-tillfallig"
		Spel.redigerar = true
		_kor_red.call_deferred()
	elif "--prov-klick" in args:
		Spel.prov = true
		Spel.redigerar = true
		Spel.bana = "provklick-tillfallig"
		var f := FileAccess.open(ProjectSettings.globalize_path("res://banor/provklick-tillfallig.txt"), FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string("res://banor/1.txt"))
		f.close()
		_kor_klick.call_deferred()
	elif "--prov-meny" in args:
		Spel.prov = true
		_kor_meny.call_deferred()
	elif "--prov-sno" in args:
		Spel.prov = true
		Spel.bana = "provsno-tillfallig"
		_sno_bana()
		_kor_sno.call_deferred()
	elif "--prov-djungel" in args:
		Spel.prov = true
		Spel.bana = "1"
		_kor_djungel.call_deferred()
	elif "--bild" in args:
		var i := args.find("--bild")
		var vanta := float(args[i + 2]) if args.size() > i + 2 else 3.0
		_bild.call_deferred(args[i + 1], vanta)


func _bild(fil: String, vanta: float) -> void:
	Spel.prov = true
	Spel.prov_x = 1.0
	var args := OS.get_cmdline_user_args()
	if "--zoom" in args:  # redigerarens zoom (skärmbild av en utzoomad redigerare)
		Spel.red_zoom = float(args[args.find("--zoom") + 1])
		get_tree().reload_current_scene()
	if "--fran" in args:  # börja vid ruta x (för skärmbilder mitt i en bana)
		await get_tree().process_frame
		var b: Node2D = get_tree().current_scene
		b.pojke.position.x = float(args[args.find("--fran") + 1]) * 48.0 + 24.0
		b.pojke.position.y = float(args[args.find("--hojd") + 1]) if "--hojd" in args else 300.0
		b.kamera.position = b.pojke.position
		b.kamera.reset_smoothing()
		if "--stilla" in args:
			Spel.prov_x = 0.0
	await get_tree().create_timer(vanta).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(fil)
	get_tree().quit()


func _rutor(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _koll(namn: String, ok: bool, detalj := "") -> void:
	print(("  ✓ " if ok else "  ✗ ") + namn + ("  (" + detalj + ")" if detalj != "" else ""))
	if not ok:
		_fel += 1


func _flytta(x: float, y: float) -> void:
	pojke.position = Vector2(x, y)
	pojke.velocity = Vector2.ZERO
	pojke.dod = false
	pojke.collision_mask = 1
	pojke.visible = true
	pojke.ducker = false
	pojke.glider = false
	Spel.prov_ner = false
	Spel.prov_x = 0.0
	Spel.prov_hopp = false
	Spel.prov_spring = false
	await _rutor(20)


func _kor() -> void:
	await _rutor(2)
	bana = get_tree().current_scene
	pojke = bana.pojke
	for b in bana.fiender:
		b.queue_free()
	bana.fiender.clear()
	await _rutor(30)
	_koll("står på marken vid start", pojke.is_on_floor() and absf(pojke.position.y - 9 * 48.0) < 0.5,
			"y = %.1f" % pojke.position.y)

	# knapparna på rad 8, kolumn 6–8
	var fore := Spel.knappar
	Spel.prov_x = 1.0
	await _rutor(80)
	Spel.prov_x = 0.0
	_koll("plockar knapparna", Spel.knappar - fore == 3, "%d knappar" % (Spel.knappar - fore))

	# hopphöjd med A nedtryckt
	await _flytta(900.0, 432.0)
	var y0 := pojke.position.y
	var topp := y0
	Spel.prov_hopp = true
	for i in 70:
		await get_tree().physics_frame
		topp = minf(topp, pojke.position.y)
	Spel.prov_hopp = false
	var hogt := y0 - topp
	_koll("högt hopp (A hålls) ≈ 3,6 rutor", hogt > 150.0 and hogt < 190.0, "%.0f px = %.1f rutor" % [hogt, hogt / 48.0])

	# kort tryck
	await _flytta(900.0, 432.0)
	topp = y0
	Spel.prov_hopp = true
	await _rutor(2)
	Spel.prov_hopp = false
	for i in 60:
		await get_tree().physics_frame
		topp = minf(topp, pojke.position.y)
	var lagt := y0 - topp
	_koll("lågt hopp (kort tryck) ≈ 2 rutor", lagt > 70.0 and lagt < 115.0, "%.0f px" % lagt)

	# gång och spring
	await _flytta(840.0, 432.0)
	Spel.prov_x = 1.0
	await _rutor(40)
	var x0 := pojke.position.x
	await _rutor(20)
	var ga := (pojke.position.x - x0) * 3.0
	_koll("gångfart ≈ 250", absf(ga - 250.0) < 10.0, "%.0f px/s" % ga)
	await _flytta(840.0, 432.0)
	Spel.prov_x = 1.0
	Spel.prov_spring = true
	await _rutor(40)
	x0 = pojke.position.x
	await _rutor(20)
	var spring := (pojke.position.x - x0) * 3.0
	_koll("springfart ≈ 400", absf(spring - 400.0) < 15.0, "%.0f px/s" % spring)

	# hopp över gropen 15–16 från vänster i gångfart
	await _flytta(500.0, 432.0)
	Spel.prov_x = 1.0
	await _rutor(30)
	while pojke.position.x < 690.0:
		await get_tree().physics_frame
	Spel.prov_hopp = true
	await _rutor(25)
	Spel.prov_hopp = false
	await _rutor(60)
	Spel.prov_x = 0.0
	_koll("hoppar över gropen (2 rutor) i gångfart", not pojke.dod and pojke.is_on_floor() and pojke.position.x > 816.0,
			"x = %.0f" % pojke.position.x)

	# kant-tiden: hopp 4 rutor efter kanten (≈ 0,07 s)
	await _flytta(600.0, 432.0)
	Spel.prov_x = 1.0
	while pojke.position.x < 720.0 + 17.0 + 16.0:
		await get_tree().physics_frame
	Spel.prov_hopp = true
	await _rutor(3)
	_koll("hopp strax efter kanten räknas", pojke.velocity.y < -500.0, "vy = %.0f" % pojke.velocity.y)
	Spel.prov_hopp = false
	Spel.prov_x = 0.0

	# vända i luften: hopp åt höger i gångfart, spaken åt vänster direkt → ska landa till vänster om starten
	await _flytta(900.0, 432.0)
	Spel.prov_x = 1.0
	await _rutor(30)
	var x_hopp := pojke.position.x
	Spel.prov_hopp = true
	await _rutor(2)
	Spel.prov_x = -1.0
	await _rutor(60)
	Spel.prov_hopp = false
	Spel.prov_x = 0.0
	_koll("vänder i luften (för kort hopp går att rädda)", pojke.position.x < x_hopp, "%.0f px bakåt" % (x_hopp - pojke.position.x))

	# ducka: står still, låg
	await _flytta(900.0, 432.0)
	Spel.prov_ner = true
	await _rutor(10)
	_koll("ducka: låg och still", pojke.ducker and pojke.rect().size.y < 60.0 and absf(pojke.velocity.x) < 1.0)
	Spel.prov_ner = false
	await _rutor(5)
	_koll("reser sig när man släpper", not pojke.ducker and pojke.rect().size.y > 80.0)
	# glida i fart: glider en bit, farten avtar, slår ut en bil
	await _flytta(860.0, 432.0)
	Spel.prov_x = 1.0
	Spel.prov_spring = true
	await _rutor(40)
	var glidbil: Node2D = bana.ny_bil(Vector2(pojke.position.x + 150.0, 432.0))
	glidbil.vaken = true
	Spel.prov_ner = true
	await _rutor(3)
	var glid_start := pojke.position.x
	_koll("glida i fart", pojke.glider and pojke.rect().size.y < 60.0)
	await _rutor(30)
	_koll("glidningen slår ut racerbilen", (not is_instance_valid(glidbil) or glidbil.platt) and not pojke.dod,
			"%.0f px glidning" % (pojke.position.x - glid_start))
	Spel.prov_ner = false
	Spel.prov_spring = false
	Spel.prov_x = 0.0
	await _rutor(40)

	# trampa på en racerbil
	await _flytta(900.0, 432.0)
	var bil: Node2D = bana.ny_bil(Vector2(1320.0, 432.0))  # ingen planka ovanför
	bil.vaken = true
	pojke.position = Vector2(bil.position.x, 200.0)
	pojke.velocity = Vector2.ZERO
	await _rutor(40)
	_koll("trampar på racerbilen", is_instance_valid(bil) and bil.platt and not pojke.dod)
	await _rutor(40)

	# gå in i en racerbil från sidan
	await _flytta(900.0, 432.0)
	bil = bana.ny_bil(Vector2(1060.0, 432.0))
	Spel.prov_x = 1.0
	await _rutor(60)
	_koll("oj när man går in i racerbilen", pojke.dod)
	await _rutor(30)
	bil.queue_free()

	# gropen
	await _flytta(744.0, 300.0)
	await _rutor(90)
	_koll("oj i gropen", pojke.dod)

	# flaggan och buren
	await _flytta(2200.0, 432.0)
	Spel.prov_x = 1.0
	await _rutor(30)
	_koll("flaggan sparar var man börjar om", is_equal_approx(Spel.flagga, 47 * 48 + 24.0), "flagga = %.0f" % Spel.flagga)
	await _flytta(92 * 48 - 100.0, 432.0)
	Spel.prov_x = 1.0
	await _rutor(40)
	_koll("buren = Björnen räddad", bana.klar)

	# liven
	Spel.liv = 1
	var slut := Spel.forlorat()
	_koll("sista livet → alla liv tillbaka", slut and Spel.liv == Spel.LIV_START and Spel.flagga < 0.0)

	print("PROV: %s" % ("allt klarat" if _fel == 0 else "%d fel" % _fel))
	get_tree().quit(1 if _fel else 0)


## Djungeln (bana 1): -- --prov-djungel
func _kor_djungel() -> void:
	await _rutor(2)
	bana = get_tree().current_scene
	pojke = bana.pojke
	var R := 48.0
	var finns := func(skript: String) -> Array:
		return bana.fiender.filter(func(f): return is_instance_valid(f) and f.get_script().resource_path.ends_with(skript))
	# (banan byggs av användaren i redigeraren – proven får inte bero på exakt var saker ligger)
	_koll("djungeln i 100 % (banans egen zoom)", is_equal_approx(bana.kamera.zoom.x, 1.0))
	_koll("djungelns fiender finns", finns.call("gangare.gd").size() >= 1 and finns.call("papegoja.gd").size() >= 1
			and finns.call("krokodil.gd").size() >= 1 and finns.call("kokos.gd").size() >= 1 and bana.boss != null)
	# vattnet (vid den första krokodilen)
	var krok0: Node2D = finns.call("krokodil.gd")[0]
	await _flytta(krok0.position.x, 300.0)
	await _rutor(60)
	_koll("oj i vattnet", pojke.dod)
	# krokodilen hoppar upp inom 3 s när man är nära
	var krok: Node2D = finns.call("krokodil.gd")[0]
	await _flytta(krok.position.x - 3.0 * R, 300.0)
	var sett := false
	for i in 200:
		await get_tree().physics_frame
		if krok.rect().has_area():
			sett = true
			break
	_koll("krokodilen hoppar upp ur vattnet", sett)
	# kokosnöten faller när man går under palmen
	var kokos: Node2D = finns.call("kokos.gd")[0]
	await _flytta(kokos.position.x - 4.0 * R, 300.0)
	Spel.prov_x = 1.0
	await _rutor(25)
	Spel.prov_x = 0.0
	var foll := false
	for i in 90:
		await get_tree().physics_frame
		if kokos._lage in ["faller", "sprucken"]:
			foll = true
	_koll("kokosnöten ramlar när man kommer nära", foll, kokos._lage)
	# trampa på en papegoja
	var pap: Node2D = finns.call("papegoja.gd")[0]
	await _flytta(pap.position.x, 432.0)
	pojke.position = pap.position + Vector2(0, -90)
	pojke.velocity = Vector2(0, 300)
	await _rutor(20)
	_koll("trampar på papegojan", not is_instance_valid(pap) or pap.platt)
	# bossen: buren låst, bananer i munnen, somnar, buren öppen
	var boss: Node2D = bana.boss
	await _flytta(boss.position.x + 7.0 * R - 10.0 + 0.0, 432.0)
	pojke.position.x = 125 * R + 24.0 - 30.0
	await _rutor(20)
	_koll("buren är låst medan bossen är vaken", not bana.klar)
	await _flytta(boss.position.x - 4.0 * R, 432.0)
	Spel.bananer = 5
	pojke._vand = 1.0
	var kast := 0
	for forsok in 12:
		while boss._lage != "gapar" and not boss.sover:
			await get_tree().physics_frame
		if boss.sover:
			break
		Spel.prov_special = true
		await _rutor(2)
		Spel.prov_special = false
		kast += 1
		await _rutor(30)
		await _rutor(40)
	_koll("bananer i munnen → bossen somnar", boss.sover, "%d kast, mätt %d" % [kast, boss.mattnad])
	# bananbusken: inga bananer kvar och inga på marken → en ny dyker upp (bossen vaken) – provas på en ny boss
	await _flytta(boss.position.x + 4.0 * R, 432.0)
	Spel.prov_x = 1.0
	await _rutor(60)
	Spel.prov_x = 0.0
	_koll("buren öppnas när bossen sover", bana.klar)
	print("PROV DJUNGELN: %s" % ("allt klarat" if _fel == 0 else "%d fel" % _fel))
	get_tree().quit(1 if _fel else 0)


## Redigeraren: -- --prov-red (en tillfällig bana som tas bort efteråt)
func _kor_red() -> void:
	await _rutor(3)
	var b: Node2D = get_tree().current_scene
	var fil: String = b.fil()
	_koll("ny bana skapas", FileAccess.file_exists(fil) and b.rader.size() == 12)
	var red: Node2D = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	red._satt(Vector2i(10, 8), "s")
	await _rutor(5)
	b = get_tree().current_scene
	_koll("lägga ut en orm sparas och syns", b.rader[8][10] == "s" and b.fiender.size() == 1, b.rader[8])
	red = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	red._satt(Vector2i(50, 9), "G")
	await _rutor(5)
	b = get_tree().current_scene
	_koll("banan blir längre när man lägger till höger", b.bredd == 51, "bredd %d" % b.bredd)
	red = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	red._satt(Vector2i(5, 8), "P")
	await _rutor(5)
	b = get_tree().current_scene
	_koll("bara en start", "\n".join(b.rader).count("P") == 1 and b.rader[8][5] == "P")
	red = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	red._angra()
	await _rutor(5)
	b = get_tree().current_scene
	_koll("ångra", b.rader[8][2] == "P" and b.rader[8][5] != "P")
	_koll("pojken står still i redigeraren", not b.pojke.visible and not b.pojke.is_physics_processing())
	# filen ändras utanför spelet (t.ex. återställd från git) → nästa klick ska utgå från filen
	var text := FileAccess.get_file_as_string(fil)
	var f := FileAccess.open(fil, FileAccess.WRITE)
	f.store_string(text.replace("..P", "..P" if false else "..P").replace("G".repeat(40), "G".repeat(39) + "W", ))
	f.close()
	red = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	red._satt(Vector2i(12, 8), "k")
	await _rutor(5)
	b = get_tree().current_scene
	_koll("ändring utanför spelet skrivs inte över", b.rader[8][12] == "k" and b.rader[9][39] == "W", b.rader[9].substr(30, 12))
	# block: fast, fyller inte under sig
	red = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	red._satt(Vector2i(15, 6), "X")
	await _rutor(5)
	b = get_tree().current_scene
	_koll("block är fast men fyller inte under sig", b.fast(Vector2(15 * 48 + 24, 6 * 48 + 24)) and not b.fast(Vector2(15 * 48 + 24, 7 * 48 + 24)))
	# Insert/Delete: en tom kolumn in vid x 3 (allt efter flyttas ett steg), sedan bort igen
	red = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	var fore: String = b.rader[8]
	red._kolumn(true, 3)
	await _rutor(5)
	b = get_tree().current_scene
	_koll("Insert = tom kolumn, resten flyttas åt höger", b.rader[8][3] == "." and b.rader[8][13] == "k" and b.rader[9][3] == ".", b.rader[8].substr(0, 16))
	red = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	red._kolumn(false, 3)
	await _rutor(5)
	b = get_tree().current_scene
	_koll("Delete = kolumnen bort, resten tillbaka", b.rader[8] == fore, b.rader[8].substr(0, 16))
	# zooma ut: kameran visar mer, och zoomen finns kvar när banan byggs om efter en ändring
	red = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	Spel.red_zoom = 1.0
	for i in 4:
		red._zooma(-0.1)
	red._satt(Vector2i(14, 8), "k")
	await _rutor(5)
	b = get_tree().current_scene
	_koll("zooma ut (och zoomen finns kvar efter en ändring)", is_equal_approx(b.kamera.zoom.x, 0.6) and b.kamera.limit_top < 0,
			"zoom %.2f, överkant %d" % [b.kamera.zoom.x, b.kamera.limit_top])
	red = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	for i in 9:
		red._zooma(-0.1)
	_koll("zoomen stannar på 40 %", is_equal_approx(Spel.red_zoom, 0.4))
	Spel.red_zoom = -1.0
	DirAccess.remove_absolute(fil)
	print("PROV REDIGERAREN: %s" % ("allt klarat" if _fel == 0 else "%d fel" % _fel))
	get_tree().quit(1 if _fel else 0)


# ── Snön (bana 2) – en egen tillfällig bana, så proven inte beror på hur användaren bygger bana 2 ──

const SNO_BANA := [
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......................................................................",
	"......LL..............................................................",
	"..P.................../GGGG\\......m.....q.......n.....d.d.d.......O..B..",
	"GGGGGGGGGGIIIIIIGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
	"GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
	"GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG",
]


func _sno_fil(slut: String) -> String:
	return ProjectSettings.globalize_path("res://banor/provsno-tillfallig." + slut)


func _sno_bana() -> void:
	var f := FileAccess.open(_sno_fil("txt"), FileAccess.WRITE)
	f.store_string("\n".join(SNO_BANA) + "\n")
	f.close()
	var meta := FileAccess.open(ProjectSettings.globalize_path("res://banor/2.json"), FileAccess.READ)
	f = FileAccess.open(_sno_fil("json"), FileAccess.WRITE)
	f.store_string(meta.get_as_text())
	f.close()


func _kor_sno() -> void:
	await _rutor(2)
	bana = get_tree().current_scene
	pojke = bana.pojke
	var R := 48.0
	var U: float = (bana.hojd - SNO_BANA.size()) * R  # tomma rader överst (utzoomad bana)
	var finns := func(skript: String) -> Array:
		return bana.fiender.filter(func(f): return is_instance_valid(f) and f.get_script().resource_path.ends_with(skript))
	var gangare: Array = finns.call("gangare.gd")
	var plog: Array = gangare.filter(func(g): return g.typ == "plog")
	var pulka: Array = gangare.filter(func(g): return g.typ == "pulka")
	_koll("snön i 60 % (banans egen zoom)", is_equal_approx(bana.kamera.zoom.x, 0.6), "zoom %.2f" % bana.kamera.zoom.x)
	_koll("tomma rader överst ända upp till skärmens kant", bana.hojd * R >= 540.0 / 0.6 and U > 0.0, "%d rader" % bana.hojd)
	_koll("snöns saker finns", plog.size() == 1 and pulka.size() == 1 and finns.call("snohog.gd").size() == 1
			and bana.boss != null and bana.boss.get_script().resource_path.ends_with("snogubbe.gd"))
	# halkan: samma fart på marken och på isen, släpp spaken – på isen glider han långt
	await _flytta(5.0 * R, (9.0 * R + U))
	pojke.velocity.x = 250.0
	await _rutor(20)
	var mark_fart := pojke.velocity.x
	await _flytta(10.5 * R, (9.0 * R + U))
	pojke.velocity.x = 250.0
	await _rutor(20)
	_koll("halt på isen (glider vidare)", mark_fart < 1.0 and pojke.velocity.x > 150.0, "marken %.0f, isen %.0f px/s" % [mark_fart, pojke.velocity.x])
	# backen upp (kolumn 22, toppen rad 8) och ner igen
	await _flytta(19.0 * R, (9.0 * R + U))
	Spel.prov_x = 1.0
	var uppe := false
	for i in 90:
		await get_tree().physics_frame
		if pojke.position.x > 23.0 * R and pojke.position.x < 27.0 * R and absf(pojke.position.y - (8.0 * R + U)) < 3.0 and pojke.is_on_floor():
			uppe = true
	_koll("går uppför backen", uppe, "x %.0f y %.0f" % [pojke.position.x, pojke.position.y])
	for i in 60:
		await get_tree().physics_frame
	_koll("och ner igen", pojke.position.x > 28.0 * R and absf(pojke.position.y - (9.0 * R + U)) < 3.0 and pojke.is_on_floor() and not pojke.dod,
			"x %.0f y %.0f" % [pojke.position.x, pojke.position.y])
	Spel.prov_x = 0.0
	# pulkan går uppför backen
	var p: Node2D = pulka[0]
	p.position = Vector2(20.5 * R, (9.0 * R + U))
	p.riktning = 1.0
	p.vaken = true
	await _flytta(10.0 * R, (9.0 * R + U))
	var p_hogst: float = (9.0 * R + U)
	for i in 80:
		await get_tree().physics_frame
		p_hogst = minf(p_hogst, p.position.y)
	_koll("pulkan går uppför backen", absf(p_hogst - (8.0 * R + U)) < 3.0, "högst y %.0f" % p_hogst)
	# pulkan åker nerför backen (\\ vid kolumn 27) – fortare än på plan mark
	p.position = Vector2(26.5 * R, 8.0 * R + U)
	p.riktning = 1.0
	var p_x0: float = p.position.x
	await _rutor(30)
	_koll("pulkan åker nerför backen (fort)", p.riktning > 0.0 and p.position.x - p_x0 > 110.0 * 0.5 * 1.5,
			"%.0f px på 0,5 s, riktning %d" % [p.position.x - p_x0, p.riktning])
	await _rutor(30)
	_koll("och kommer ner till marken", absf(p.position.y - (9.0 * R + U)) < 3.0 and p.position.x > 28.0 * R, "x %.0f y %.0f" % [p.position.x, p.position.y])
	p.queue_free()
	# glida under blocken (rad 7, kolumn 6–7: 48 px luft) och ut på andra sidan
	await _flytta(2.5 * R, 9.0 * R + U)
	pojke.velocity.x = 400.0
	Spel.prov_ner = true
	await _rutor(2)
	Spel.prov_ner = false
	var under := false
	for i in 120:
		await get_tree().physics_frame
		under = under or (pojke.position.x > 6.2 * R and pojke.position.x < 7.8 * R)
	_koll("glider under blocken och ut", under and pojke.position.x > 8.0 * R and not pojke.glider and not pojke.ducker and pojke.is_on_floor(),
			"x %.0f, glider %s duckar %s" % [pojke.position.x, pojke.glider, pojke.ducker])
	# duckar under blocken: kryper ut
	await _flytta(6.5 * R, 9.0 * R + U)
	pojke.ducker = true
	Spel.prov_x = 1.0
	await _rutor(60)
	Spel.prov_x = 0.0
	_koll("kryper ut under blocken", pojke.position.x > 8.0 * R, "x %.0f" % pojke.position.x)
	# glidningen stannar under blocken (t.ex. mot en vägg): duckar då, och kryper ut – fastnade förut i glidläget
	await _flytta(6.5 * R, 9.0 * R + U)
	pojke.glider = true
	pojke._glid_tid = 0.0
	await _rutor(5)
	_koll("glidning som stannar under block = duckar", not pojke.glider and pojke.ducker, "glider %s duckar %s" % [pojke.glider, pojke.ducker])
	Spel.prov_x = -1.0
	await _rutor(60)
	Spel.prov_x = 0.0
	_koll("och kryper ut åt andra hållet", pojke.position.x < 5.6 * R, "x %.0f" % pojke.position.x)
	# kryper på öppen mark (ner + åt sidan)
	await _flytta(30.0 * R, 9.0 * R + U)
	Spel.prov_ner = true
	await _rutor(5)
	Spel.prov_x = 1.0
	await _rutor(30)
	_koll("kryper på öppen mark", pojke.ducker and not pojke.glider and pojke.position.x > 30.0 * R + 40.0 and absf(pojke.velocity.x) <= pojke.KRYP + 1.0,
			"x +%.0f, %.0f px/s" % [pojke.position.x - 30.0 * R, pojke.velocity.x])
	Spel.prov_x = 0.0
	Spel.prov_ner = false
	# snöplogen tål ett tramp
	var pl: Node2D = plog[0]
	pl.platta()
	_koll("snöplogen: ett tramp räcker inte", not pl.platt and pl.liv == 1)
	await _rutor(70)
	pl.platta()
	_koll("snöplogen: två tramp", pl.platt)
	# snöhögen: en snöboll rullar ut mot pojken
	var hog: Node2D = finns.call("snohog.gd")[0]
	await _flytta(hog.position.x - 6.0 * R, (9.0 * R + U))
	var boll: Node2D = null
	for i in 240:
		await get_tree().physics_frame
		var bb: Array = finns.call("snoboll.gd")
		if not bb.is_empty():
			boll = bb[0]
			break
	var x0 := boll.position.x if boll else 0.0
	await _rutor(30)
	_koll("snöhögen: en snöboll rullar mot pojken", boll != null and is_instance_valid(boll) and boll.position.x < x0 - 40.0)
	# snöbollen rullar fortare nerför backen (\\ vid kolumn 27, upp åt vänster = nerför åt höger)
	var ner: Node2D = bana.ny_fiende("snoboll", Vector2(27.2 * R, (8.3 * R + U)), {"riktning": 1.0})
	await _rutor(12)
	_koll("snöbollen rullar fortare nerför", is_instance_valid(ner) and ner._vx > 230.0, "%.0f px/s" % (ner._vx if is_instance_valid(ner) else 0.0))
	# trampa på en snöboll: den spricker, pojken studsar
	var tb: Node2D = bana.ny_fiende("snoboll", Vector2(12.0 * R, 9.0 * R + U), {"riktning": 1.0})
	await _flytta(12.0 * R, 9.0 * R + U - 60.0)
	pojke.velocity.y = 300.0
	await _rutor(10)
	_koll("trampa på en snöboll", (not is_instance_valid(tb) or tb.platt) and not pojke.dod and bana.utslagna == 0,
			"utslagna %d" % bana.utslagna)
	for f in bana.fiender:
		if is_instance_valid(f) and f.get_script().resource_path.ends_with("snoboll.gd"):
			f.queue_free()
	hog.process_mode = Node.PROCESS_MODE_DISABLED
	# bära: ta ett snöklot, B långt från snögubben = läggs ner igen
	var klot := func() -> Array:
		return bana.saker.filter(func(s): return s["typ"] == "snoklot")
	await _flytta(klot.call()[0]["nod"].position.x, (9.0 * R + U))
	_koll("tar upp ett snöklot", bana._bar != null and klot.call().size() == 2)
	pojke.position.x -= 3.0 * R
	Spel.prov_special = true
	await _rutor(2)
	Spel.prov_special = false
	await _rutor(2)
	_koll("B långt från snögubben: klotet läggs ner", bana._bar == null and klot.call().size() == 3)
	# bygga kompisen: tre klot, ett i taget
	var boss: Node2D = bana.boss
	_koll("buren är låst medan snögubben är ledsen", not boss.sover)
	for i in 3:
		await _flytta(klot.call()[0]["nod"].position.x, (9.0 * R + U))
		await _flytta(boss.kompis_x(), (9.0 * R + U))
		Spel.prov_special = true
		await _rutor(2)
		Spel.prov_special = false
		await _rutor(2)
	_koll("tre klot = kompisen klar, snögubben glad", boss.delar == 3 and boss.sover, "%d delar" % boss.delar)
	_koll("kameran utzoomad vid snögubben (minst snögubbens 80 %)", bana.kamera.zoom.x <= 0.81, "zoom %.2f" % bana.kamera.zoom.x)
	await _flytta(boss.position.x + 3.0 * R, (9.0 * R + U))
	await _rutor(10)
	_koll("buren öppnas", bana.klar)
	DirAccess.remove_absolute(_sno_fil("txt"))
	DirAccess.remove_absolute(_sno_fil("json"))
	print("PROV SNÖN: %s" % ("allt klarat" if _fel == 0 else "%d fel" % _fel))
	get_tree().quit(1 if _fel else 0)


# ── Banväljaren (-- --meny) ──

func _kor_meny() -> void:
	await _rutor(2)
	get_tree().change_scene_to_file("res://meny.tscn")
	await _rutor(5)
	var m: Control = get_tree().current_scene
	_koll("banväljaren visar tio banor", m.name == "Meny" and m.kort.size() == 10)
	var med_grund: Array = m.kort.filter(func(k): return k["grund"])
	_koll("bara banor med grund går att välja", med_grund.size() >= 2 and m.kort[0]["grund"] and m.kort[1]["grund"]
			and not m.kort[9]["grund"] and m.kort[9]["redigera"] == null, "%d med grund" % med_grund.size())
	m.kort[0]["spela"].pressed.emit()
	await _rutor(10)
	var b: Node = get_tree().current_scene
	_koll("Spela startar banan", b.name != "Meny" and Spel.bana == "1" and not Spel.redigerar and b.pojke.visible)
	Spel.till_menyn()
	await _rutor(5)
	m = get_tree().current_scene
	_koll("tillbaka till banväljaren", m.name == "Meny")
	m.kort[0]["redigera"].pressed.emit()
	await _rutor(10)
	b = get_tree().current_scene
	_koll("Redigera öppnar redigeraren", Spel.bana == "1" and Spel.redigerar and not b.pojke.visible)
	# verktygen följer temat: djungeln visar ormen, inte pulkan; ingen is (djungelns markblad har ingen)
	var red: Node = b.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("redigerare.gd"))[0]
	var tecken: Array = red._synliga.map(func(i): return red.VERKTYG[i][0])
	_koll("redigeraren visar bara banans tema", "s" in tecken and "W" in tecken and not "q" in tecken and not "I" in tecken
			and "G" in tecken and "O" in tecken, "".join(tecken))
	print("PROV BANVÄLJAREN: %s" % ("allt klarat" if _fel == 0 else "%d fel" % _fel))
	get_tree().quit(1 if _fel else 0)


# ── Ett riktigt musklick i redigeraren (användaren 15 nov: "lägger ut samma sak lite överallt") ──
# Knappen hålls nere i 20 bildrutor (banan byggs om efter första rutan) – bara en ruta får ändras,
# med och utan zoom, längst till vänster och längre in i banan.

func _kor_klick() -> void:
	await _rutor(3)
	var fil := ProjectSettings.globalize_path("res://banor/provklick-tillfallig.txt")
	for fall in [[1.0, 480.0], [1.0, 2400.0], [0.6, 2400.0], [0.4, 3000.0]]:
		Spel.red_zoom = fall[0]
		Spel.red_kamera = Vector2(fall[1], 9999.0)
		Spel.red_verktyg = 10  # knappen
		get_tree().reload_current_scene()
		await _rutor(5)
		var fore := FileAccess.get_file_as_string(fil)
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = Vector2(600, 470)
		e.global_position = e.position
		get_viewport().warp_mouse(e.position)
		Input.parse_input_event(e)
		for i in 20:
			await get_tree().process_frame
		var u: InputEventMouseButton = e.duplicate()
		u.pressed = false
		Input.parse_input_event(u)
		await _rutor(5)
		var efter := FileAccess.get_file_as_string(fil)
		var n := absi(efter.length() - fore.length())
		for i in mini(fore.length(), efter.length()):
			if fore[i] != efter[i]:
				n += 1
		_koll("ett klick = en ruta (zoom %d %%, x %d)" % [int(fall[0] * 100), int(fall[1])], n == 1, "%d rutor ändrade" % n)
	DirAccess.remove_absolute(fil)
	print("PROV KLICKET: %s" % ("allt klarat" if _fel == 0 else "%d fel" % _fel))
	get_tree().quit(1 if _fel else 0)
