extends Control
## Banväljaren för den vuxne (användaren 15 nov: "ett fönster till redigeraren som jag startar och väljer bana
## i"): -- --meny (menyposten "A Boy to the Rescue – Redigera"). De tio banorna i rutor; de som har en grund
## (banor/<nr>.json – bilderna, fienderna och bossen gjorda) går att redigera och spela, de andra syns gråa
## med sitt tema. Esc i banan/redigeraren kommer tillbaka hit. Aldrig i barnläget.

const TEMAN := ["Djungeln", "Snön", "Sanden", "Vattnet", "Lavan", "Molnen", "Rymden", "Spökhuset",
		"Mörka skogen", "Slottet"]
const RUTA := Vector2(172, 196)

var kort: Array = []  ## {"nr", "grund", "redigera", "spela"} – proven trycker på knapparna


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.1, 0.08, 0.15))
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var titel := Label.new()
	titel.text = "A Boy to the Rescue – välj bana"
	titel.label_settings = _stil(30, Color(1.0, 0.85, 0.25))
	titel.position = Vector2(0, 18)
	titel.size = Vector2(960, 44)
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(titel)
	var nat := GridContainer.new()
	nat.columns = 5
	nat.add_theme_constant_override("h_separation", 12)
	nat.add_theme_constant_override("v_separation", 12)
	nat.position = Vector2((960 - 5 * RUTA.x - 4 * 12) / 2.0, 76)
	add_child(nat)
	for i in TEMAN.size():
		nat.add_child(_kort(i + 1, TEMAN[i]))
	var hjalp := Label.new()
	hjalp.text = "I redigeraren: E = spela härifrån · Enter = från början · Esc = tillbaka hit"
	hjalp.label_settings = _stil(14, Color(0.75, 0.72, 0.82))
	hjalp.position = Vector2(0, 506)
	hjalp.size = Vector2(960, 24)
	hjalp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hjalp)


func _stil(storlek: int, farg: Color) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = storlek
	s.font_color = farg
	s.outline_size = 4
	s.outline_color = Color(0.1, 0.06, 0.14)
	return s


func _kort(nr: int, tema: String) -> Control:
	var meta = null
	var jf := "res://banor/%d.json" % nr
	if FileAccess.file_exists(jf):
		meta = JSON.parse_string(FileAccess.get_file_as_string(jf))
	var grund: bool = meta is Dictionary
	var ram := PanelContainer.new()
	ram.custom_minimum_size = RUTA
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0.2, 0.17, 0.27) if grund else Color(0.15, 0.14, 0.18)
	stil.border_color = Color(1.0, 0.85, 0.25) if grund else Color(0.3, 0.28, 0.34)
	stil.set_border_width_all(2)
	stil.set_content_margin_all(6)
	ram.add_theme_stylebox_override("panel", stil)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override("separation", 4)
	ram.add_child(kol)
	# bilden: banans bakgrund (vänstra halvan), annars en grå ruta
	var bild := TextureRect.new()
	bild.custom_minimum_size = Vector2(RUTA.x - 12, 84)
	bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bild.clip_contents = true
	if grund and meta.has("bakgrund") and FileAccess.file_exists("res://bilder/%s.json" % meta["bakgrund"]):
		var a := AtlasTexture.new()
		a.atlas = Bilder.textur(meta["bakgrund"])
		a.region = Rect2(0, 0, 300, 140)
		bild.texture = a
	else:
		bild.modulate = Color(1, 1, 1, 0)
	kol.add_child(bild)
	var namn := Label.new()
	namn.text = "%d  %s" % [nr, tema]
	namn.label_settings = _stil(18, Color(1, 1, 1) if grund else Color(0.5, 0.48, 0.55))
	namn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kol.add_child(namn)
	var k := {"nr": nr, "grund": grund, "redigera": null, "spela": null}
	if grund:
		var tid := Spel.basta_tid(str(nr))
		var info := Label.new()
		var finns := FileAccess.file_exists("res://banor/%d.txt" % nr)
		info.text = ("bästa " + Spel.tid_text(tid)) if tid >= 0.0 else ("" if finns else "inte byggd än")
		info.label_settings = _stil(12, Color(0.8, 0.78, 0.86))
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kol.add_child(info)
		var rad := HBoxContainer.new()
		rad.add_theme_constant_override("separation", 6)
		kol.add_child(rad)
		k["redigera"] = _knapp(rad, "Redigera", _starta.bind(nr, true))
		k["spela"] = _knapp(rad, "Spela", _starta.bind(nr, false))
		k["spela"].disabled = not finns
	else:
		var info := Label.new()
		info.text = "kommer sen"
		info.label_settings = _stil(12, Color(0.45, 0.43, 0.5))
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kol.add_child(info)
	kort.append(k)
	return ram


func _knapp(rad: HBoxContainer, text: String, gor: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(gor)
	rad.add_child(b)
	return b


## Banan börjar från början – i redigeraren längst till vänster och längst ner
func _starta(nr: int, redigera: bool) -> void:
	Spel.bana = str(nr)
	Spel.redigerar = redigera
	Spel.red_kamera = Vector2(480, 9999.0)
	Spel.red_historik.clear()
	Spel.test_start = Vector2.ZERO
	Spel.flagga = -1.0
	Spel.liv = Spel.LIV_START
	Spel.knappar = 0
	Spel.ny_runda()
	get_tree().change_scene_to_file("res://bana.tscn")
