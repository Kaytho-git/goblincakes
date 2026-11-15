extends Node
## Bilderna från tools/barnspelet-bilder.py: bilder/<namn>.png (rutorna sida vid sida) + <namn>.json
## ({"cell": [b, h], "frames": [namn …]}).

var _info := {}


func info(namn: String) -> Dictionary:
	if not _info.has(namn):
		var f := FileAccess.open("res://bilder/%s.json" % namn, FileAccess.READ)
		_info[namn] = JSON.parse_string(f.get_as_text()) if f else {"cell": [48, 48], "frames": []}
	return _info[namn]


func cell(namn: String) -> Vector2:
	var c: Array = info(namn)["cell"]
	return Vector2(c[0], c[1])


func textur(namn: String) -> Texture2D:
	return load("res://bilder/%s.png" % namn)


## En ruta ur bladet
func bild(namn: String, ruta := "") -> Texture2D:
	var i: Dictionary = info(namn)
	var frames: Array = i["frames"]
	var n := maxi(0, frames.find(ruta)) if ruta != "" else 0
	var c := cell(namn)
	var a := AtlasTexture.new()
	a.atlas = textur(namn)
	a.region = Rect2(c.x * n, 0, c.x, c.y)
	return a


## anims = {"namn": [[rutor …], fps, loop], …}
func ramar(namn: String, anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in anims:
		sf.add_animation(a)
		sf.set_animation_speed(a, anims[a][1])
		sf.set_animation_loop(a, anims[a][2])
		for r in anims[a][0]:
			sf.add_frame(a, bild(namn, r))
	return sf
