extends Node
## Det som gäller hela spelet: kontrollen, liven, knapparna, var man börjar om, ljuden.
## Kontrollen (användarens val 15 nov, Xbox): A hoppa, håll X springa, Y kraft (senare), B special (senare).

const LIV_START := 5
const KNAPPAR_PER_LIV := 100

var liv := LIV_START
var knappar := 0
var bana := "1"  ## banor/<namn>.txt – "prov" = provbanan; välj med -- --bana <namn>
var flagga := -1.0  ## x där man börjar om efter flaggan (-1 = från start)
var bananer := 0  ## som pojken bär (kastas med B)

## Redigeraren (redigerare.gd) – E växlar
var redigerar := false
var red_kamera := Vector2(480, 270)
var red_verktyg := 0
var red_senast := Vector3i(-1, -1, 0)
var red_historik: Array[String] = []
var test_start := Vector2.ZERO  ## "spela härifrån" – gäller tills man spelar från början

## Proven (prov.gd) styr pojken i stället för kontrollen
var prov := false
var prov_x := 0.0
var prov_hopp := false
var prov_spring := false
var prov_special := false

var _ljud := {}
var _spelare: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if "--bana" in args and args.find("--bana") + 1 < args.size():
		bana = args[args.find("--bana") + 1]
	if "--redigera" in args:  # börja i redigeraren
		redigerar = true
	_knappar()
	_gor_ljud()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_spelare.append(p)


func _knappar() -> void:
	var tangent := func(action: String, keys: Array) -> void:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.4)
		for k in keys:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	var knapp := func(action: String, buttons: Array) -> void:
		for b in buttons:
			var e := InputEventJoypadButton.new()
			e.button_index = b
			e.device = -1
			InputMap.action_add_event(action, e)
	var spak := func(action: String, axis: int, value: float) -> void:
		var e := InputEventJoypadMotion.new()
		e.axis = axis
		e.axis_value = value
		e.device = -1
		InputMap.action_add_event(action, e)
	tangent.call("vanster", [KEY_LEFT, KEY_A])
	tangent.call("hoger", [KEY_RIGHT, KEY_D])
	tangent.call("upp", [KEY_UP, KEY_W])
	tangent.call("ner", [KEY_DOWN, KEY_S])
	tangent.call("hopp", [KEY_SPACE, KEY_Z, KEY_K])
	tangent.call("spring", [KEY_SHIFT, KEY_X, KEY_J])
	tangent.call("kraft", [KEY_C, KEY_I])
	tangent.call("special", [KEY_V, KEY_L])
	tangent.call("sluta", [KEY_ESCAPE])
	knapp.call("vanster", [JOY_BUTTON_DPAD_LEFT])
	knapp.call("hoger", [JOY_BUTTON_DPAD_RIGHT])
	knapp.call("upp", [JOY_BUTTON_DPAD_UP])
	knapp.call("ner", [JOY_BUTTON_DPAD_DOWN])
	knapp.call("hopp", [JOY_BUTTON_A])
	knapp.call("spring", [JOY_BUTTON_X])
	knapp.call("kraft", [JOY_BUTTON_Y])
	knapp.call("special", [JOY_BUTTON_B])
	spak.call("vanster", JOY_AXIS_LEFT_X, -1.0)
	spak.call("hoger", JOY_AXIS_LEFT_X, 1.0)
	spak.call("upp", JOY_AXIS_LEFT_Y, -1.0)
	spak.call("ner", JOY_AXIS_LEFT_Y, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sluta"):
		get_tree().quit()
	if prov or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var bana := get_tree().current_scene
	if event.keycode == KEY_E:
		if redigerar:  # spela härifrån
			redigerar = false
			test_start = Vector2(red_kamera.x, -1.0)
		else:
			redigerar = true
			red_kamera = bana.kamera.get_screen_center_position()
		get_tree().reload_current_scene()
	elif event.keycode == KEY_ENTER and redigerar:
		redigerar = false
		test_start = Vector2.ZERO
		flagga = -1.0
		get_tree().reload_current_scene()


# ── Det pojken frågar efter (proven kan ta över) ─────────────────

func styr_x() -> float:
	if prov:
		return prov_x
	var x := Input.get_axis("vanster", "hoger")
	return 0.0 if absf(x) < 0.3 else signf(x)  # hel fart – små barn trycker spaken halvvägs


func hopp_nere() -> bool:
	return prov_hopp if prov else Input.is_action_pressed("hopp")


func spring_nere() -> bool:
	return prov_spring if prov else Input.is_action_pressed("spring")


func special_nere() -> bool:
	return prov_special if prov else Input.is_action_pressed("special")


# ── Liv och knappar ──────────────────────────────────────────────

func ta_knapp() -> void:
	knappar += 1
	ljud("knapp")
	if knappar >= KNAPPAR_PER_LIV:
		knappar -= KNAPPAR_PER_LIV
		nytt_liv()


func nytt_liv() -> void:
	liv += 1
	ljud("liv")


## Efter "oj": ett liv mindre. Slut på liv → alla liv tillbaka och banan från början
## (beslut 15 nov: tillbaka till kartan, klarade banor kvar – kartan kommer i steg 2).
func forlorat() -> bool:
	liv -= 1
	if liv <= 0:
		liv = LIV_START
		knappar = 0
		flagga = -1.0
		return true
	return false


# ── Ljuden: små fyrkantsvågor, gjorda här (inga filer) ──────────

func ljud(namn: String) -> void:
	if prov or not _ljud.has(namn):
		return
	for p in _spelare:
		if not p.playing:
			p.stream = _ljud[namn]
			p.play()
			return


func _gor_ljud() -> void:
	_ljud["hopp"] = _ton([[330.0, 660.0, 0.12]], 0.18)
	_ljud["knapp"] = _ton([[988.0, 988.0, 0.05], [1319.0, 1319.0, 0.12]], 0.16)
	_ljud["trampa"] = _ton([[520.0, 180.0, 0.12]], 0.22)
	_ljud["oj"] = _ton([[660.0, 620.0, 0.12], [520.0, 480.0, 0.12], [400.0, 200.0, 0.35]], 0.22)
	_ljud["liv"] = _ton([[523.0, 523.0, 0.08], [659.0, 659.0, 0.08], [784.0, 784.0, 0.08], [1047.0, 1047.0, 0.2]], 0.18)
	_ljud["kasta"] = _ton([[500.0, 900.0, 0.1]], 0.14)
	_ljud["mums"] = _ton([[220.0, 260.0, 0.08], [200.0, 240.0, 0.08], [240.0, 280.0, 0.1]], 0.2)
	_ljud["flagga"] = _ton([[659.0, 659.0, 0.08], [880.0, 880.0, 0.16]], 0.16)
	_ljud["raddad"] = _ton([[523.0, 523.0, 0.12], [659.0, 659.0, 0.12], [784.0, 784.0, 0.12],
			[1047.0, 1047.0, 0.12], [784.0, 784.0, 0.12], [1047.0, 1047.0, 0.4]], 0.18)


## toner = [[från Hz, till Hz, sekunder], …] i följd, fyrkantsvåg som tonar ut i slutet av varje ton
func _ton(toner: Array, styrka: float) -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	var fas := 0.0
	for t in toner:
		var n := int(t[2] * rate)
		for i in n:
			var f: float = lerpf(t[0], t[1], float(i) / n)
			fas = fmod(fas + f / rate, 1.0)
			var env := minf(1.0, (n - i) / (0.02 * rate))
			var v := int((1.0 if fas < 0.5 else -1.0) * styrka * env * 32767.0)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s
