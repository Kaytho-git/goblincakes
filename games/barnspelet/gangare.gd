extends Node2D
## Fiender som går/kör/ringlar längs marken: racerbilen, ormen, pulkan, snöplogen. Vänder vid väggar och
## kanter, går upp och ner för backar. "liv" 2 = tål ett tramp (snöplogen: buckla, står still en stund).
## Positionen = mitt under fötterna/hjulen. Vaknar först när pojken är nära (annars hinner den gå iväg).
## Sätt typ innan den läggs in i banan.

const TYPER := {
	"racerbil": {"fart": 90.0, "halv": 38.0, "hojd": 40.0, "rutor": ["kor1", "kor2"], "fps": 6.0},
	"orm": {"fart": 125.0, "halv": 36.0, "hojd": 24.0, "rutor": ["orm1", "orm2"], "fps": 5.0},
	"pulka": {"fart": 110.0, "halv": 42.0, "hojd": 38.0, "rutor": ["pulka1", "pulka2"], "fps": 5.0},
	"plog": {"fart": 70.0, "halv": 44.0, "hojd": 60.0, "rutor": ["plog1"], "fps": 1.0, "liv": 2, "skadad": "plog2"},
	# Sanden (bana 3): krabban går i sidled; skorpionen kan trampas bara när svansen är nere; kaktusen står still
	"krabba": {"fart": 75.0, "halv": 28.0, "hojd": 30.0, "rutor": ["krabba1", "krabba2"], "fps": 6.0},
	"skorpion": {"fart": 45.0, "halv": 30.0, "hojd": 34.0, "rutor": ["uppe"], "fps": 1.0, "svans": "nere"},
	"kaktus": {"fart": 0.0, "halv": 20.0, "hojd": 52.0, "rutor": ["kaktus"], "fps": 1.0, "trampbar": false},
}

var bana: Node2D
var typ := "racerbil"
var riktning := -1.0
var vaken := false
var platt := false
var trampbar := true
var liv := 1
var _stum := 0.0  ## efter första trampet: står still (och tål inget nytt tramp) en kort stund
var _vy := 0.0
var _t: Dictionary
var _sprite: AnimatedSprite2D
var _svans_tid := 0.0  ## skorpionen: uppe 1,8 s, nere 1,4 s


func _ready() -> void:
	_t = TYPER[typ]
	var blad: String = typ
	_sprite = AnimatedSprite2D.new()
	liv = _t.get("liv", 1)
	var anims := {"ga": [_t["rutor"], _t["fps"], true]}
	if _t.has("skadad"):
		anims["skadad"] = [[_t["skadad"]], 1.0, false]
	if _t.has("svans"):
		anims["nere"] = [[_t["svans"]], 1.0, false]
	trampbar = _t.get("trampbar", true)
	_sprite.sprite_frames = Bilder.ramar(blad, anims)
	_sprite.centered = false
	var cell: Vector2 = Bilder.cell(blad)
	_sprite.offset = Vector2(-cell.x / 2.0, -cell.y)
	_sprite.play("ga")
	add_child(_sprite)


func _physics_process(dt: float) -> void:
	if platt:
		return
	if not vaken:
		if absf(bana.pojke.position.x - position.x) > 640.0:
			return
		vaken = true
	_stum = maxf(0.0, _stum - dt)
	if _t.has("svans"):  # svansen upp (farlig) och ner (gå att trampa på)
		_svans_tid = fmod(_svans_tid + dt, 3.2)
		trampbar = _svans_tid >= 1.8
		_sprite.play("nere" if trampbar else "ga")
	if _t["fart"] == 0.0:  # kaktusen: står still
		var mk: Array = bana.pa_marken(position, _vy, dt)
		position = mk[0]
		_vy = mk[1]
		return
	var halv: float = _t["halv"]
	var fart: float = 0.0 if _stum > 0.0 else _t["fart"]
	if typ == "pulka":  # pulkan åker fort nerför backar, sakta uppför (användaren 15 nov)
		var b: int = bana.backe(position)
		if b != 0:
			fart *= 2.6 if b == -int(riktning) else 0.6
	var nx: float = position.x + riktning * fart * dt
	var fram: float = nx + riktning * halv
	# vägg = fast i knähöjd en bit fram (en backe är lägre där – den går man uppför);
	# kant = inget att stå på en bit ner (en backe nedåt är 36 px, en avsats 48)
	var vagg: bool = bana.vagg(Vector2(fram, position.y - 44.0))
	# (i en backe ligger marken framför längre ner – där räknas 64 px, och en backe framför är ingen kant)
	var djup := 64.0 if bana.backe(position) != 0 else 40.0
	var kant: bool = bana.fast(Vector2(position.x, position.y + 2.0)) and not bana.fast(Vector2(fram, position.y + djup)) \
			and not bana.backe_under(Vector2(fram, position.y), 60.0)
	if vagg or kant:
		riktning = -riktning
	else:
		position.x = nx
	var m: Array = bana.pa_marken(position, _vy, dt)
	position = m[0]
	_vy = m[1]
	_sprite.flip_h = riktning > 0.0  # ritade åt vänster
	if position.y > bana.botten + 200.0:
		queue_free()


func rect() -> Rect2:
	return Rect2(position.x - _t["halv"], position.y - _t["hojd"], _t["halv"] * 2.0, _t["hojd"])


## Pojken trampade på den: platt, sedan borta (har den fler liv: en buckla och står still en stund)
func platta() -> void:
	if _stum > 0.0:
		return
	liv -= 1
	if liv > 0:
		_stum = 1.0
		_sprite.play("skadad")  # bucklig resten av tiden – ett tramp kvar
		return
	platt = true
	_sprite.stop()
	scale = Vector2(1.15, 0.4)
	await get_tree().create_timer(0.6).timeout
	queue_free()
