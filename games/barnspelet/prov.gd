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
	if "--fran" in args:  # börja vid ruta x (för skärmbilder mitt i en bana)
		await get_tree().process_frame
		var b: Node2D = get_tree().current_scene
		b.pojke.position.x = float(args[args.find("--fran") + 1]) * 48.0 + 24.0
		b.pojke.position.y = 300.0
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
	_koll("djungelns fiender finns", finns.call("gangare.gd").size() == 5 and finns.call("papegoja.gd").size() == 3
			and finns.call("krokodil.gd").size() == 2 and finns.call("kokos.gd").size() == 3 and bana.boss != null)
	# vattnet
	await _flytta(77 * R + 24.0, 300.0)
	await _rutor(60)
	_koll("oj i vattnet", pojke.dod)
	# krokodilen hoppar upp inom 3 s när man är nära
	await _flytta(74 * R, 432.0)
	var krok: Node2D = finns.call("krokodil.gd")[0]
	var sett := false
	for i in 200:
		await get_tree().physics_frame
		if krok.rect().has_area():
			sett = true
			break
	_koll("krokodilen hoppar upp ur vattnet", sett)
	# kokosnöten faller när man går under palmen
	await _flytta(35 * R, 432.0)
	var kokos: Node2D = finns.call("kokos.gd")[0]
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
