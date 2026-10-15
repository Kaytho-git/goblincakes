# Tangenter och styrning

Godot tänker i **handlingar** (actions) i stället för tangenter: `ui_left`, `ui_right`, `ui_up`,
`ui_down` och `ui_accept` (Enter/mellanslag) finns från början. Egna gör du i
**Project → Project Settings → Input Map** (t.ex. "hoppa" = mellanslag + A på handkontrollen).

```gdscript
func _process(delta):
	if Input.is_action_pressed("ui_right"):      # hålls nere
		position.x += 200 * delta
	if Input.is_action_just_pressed("ui_accept"):  # bara bildrutan den trycktes
		print("Hopp!")
```

Kortare: `Input.get_axis("ui_left", "ui_right")` ger −1 (vänster), 0 eller 1 (höger).
För fyra riktningar: `Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")` ger en Vector2.

> I övningen trycker en låtsasspelare på tangenterna vid bestämda bildrutor – uppgiften säger när.
