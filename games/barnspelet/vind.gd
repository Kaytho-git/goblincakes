extends Node2D
## Vindpusten (Sanden, v i banan): sandstrimmor som flyger bakåt (åt vänster) i kolumnerna med vind när det
## blåser (bana.blaser()). Knuffen själv sitter i pojke.gd (bana.vind()).

const ANTAL := 26  ## strimmor per vindsträcka

var bana: Node2D
var _strackor: Array = []  ## [x0, x1] i px
var _strimmor: Array = []  ## {"p": Vector2, "s": sträckans index, "l": längd}


func _ready() -> void:
	z_index = 9
	var kol: Array = bana._vind.keys()
	kol.sort()
	for x in kol:
		if not _strackor.is_empty() and _strackor[-1][1] == x * bana.RUTA:
			_strackor[-1][1] = (x + 1) * bana.RUTA
		else:
			_strackor.append([x * bana.RUTA, (x + 1) * bana.RUTA])
	for i in _strackor.size():
		for n in ANTAL:
			_strimmor.append({"p": _ny_plats(i, true), "s": i, "l": randf_range(10.0, 26.0)})


func _ny_plats(i: int, var_som_helst: bool) -> Vector2:
	var s: Array = _strackor[i]
	var x: float = randf_range(s[0], s[1]) if var_som_helst else s[1] + randf_range(0.0, 60.0)
	return Vector2(x, randf_range(bana.botten - 9.0 * bana.RUTA, bana.botten - bana.RUTA))


func _process(dt: float) -> void:
	visible = bana.blaser()
	if not visible:
		return
	for st in _strimmor:
		st["p"].x -= (420.0 + st["l"] * 6.0) * dt
		if st["p"].x < _strackor[st["s"]][0] - 40.0:
			st["p"] = _ny_plats(st["s"], false)
	queue_redraw()


func _draw() -> void:
	for st in _strimmor:
		var p: Vector2 = st["p"]
		draw_line(p, p + Vector2(st["l"], 0), Color(0.98, 0.86, 0.55, 0.7), 2.0)
