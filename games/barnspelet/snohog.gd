extends Node2D
## Snöhögen (bana 2): snöbollar rullar ut ur den mot pojken med jämna mellanrum när han är nära.
## Själv gör den ingen illa. Positionen = mitt under högen.

const VAR := 2.6        ## sekunder mellan snöbollarna
const NARA := 760.0     ## pojken inom så här långt bort
const HOGST := 2        ## så många snöbollar ute samtidigt från den här högen

var bana: Node2D
var platt := false
var trampbar := false
var _tid := 1.6
var _bollar: Array = []


func _ready() -> void:
	var s := Sprite2D.new()
	s.texture = Bilder.textur("snohog")
	var c: Vector2 = Bilder.cell("snohog")
	s.centered = false
	s.offset = Vector2(-c.x / 2.0, -c.y)
	add_child(s)
	z_index = 1  # framför snöbollen när den kommer ut


func _physics_process(dt: float) -> void:
	_bollar = _bollar.filter(func(b): return is_instance_valid(b))
	var dx: float = bana.pojke.position.x - position.x
	if absf(dx) > NARA or bana.pojke.dod or _bollar.size() >= HOGST:
		return
	_tid += dt
	if _tid < VAR:
		return
	_tid = 0.0
	var r := signf(dx) if dx != 0.0 else -1.0
	_bollar.append(bana.ny_fiende("snoboll", position + Vector2(r * 20.0, -2.0), {"riktning": r}))


func rect() -> Rect2:
	return Rect2()
