# Ett litet spel: samla mynt

Nu sätter vi ihop allt: rörelse med tangenter, en lista med mynt, poäng och en signal när spelet
är vunnet.

```gdscript
var mynt := [Vector2(50, 0), Vector2(100, 0)]

func _process(delta):
	position.x += Input.get_axis("ui_left", "ui_right") * 120 * delta
	for i in range(mynt.size() - 1, -1, -1):        # baklänges: säkert att ta bort
		if position.distance_to(mynt[i]) < 16:
			mynt.remove_at(i)
			poang += 1
```

- `distance_to` ger avståndet mellan två punkter.
- Ta bort ur en lista medan du går **baklänges** – annars hoppar loopen över saker.
- I ett riktigt spel är mynten egna noder med en **Area2D** som skickar signalen
  `body_entered` när spelaren nuddar dem. Logiken är densamma.
