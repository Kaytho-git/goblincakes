# _process och rörelse

`_ready` körs en gång. `_process(delta)` körs **varje bildruta** – oftast 60 gånger per sekund.
`delta` är hur lång tid som gått sedan förra bildrutan (ungefär 0.0167 sekunder).

```gdscript
extends Node2D

var fart := 120.0      # pixlar per sekund

func _process(delta):
	position.x += fart * delta
```

Multiplicera alltid med `delta`! Annars rör sig spelet snabbare på en dator med 144 Hz än på en
med 60 Hz.

## Gå snett

```gdscript
var riktning := Vector2(1, 1).normalized()   # längd 1 → samma fart snett som rakt
position += riktning * fart * delta
```

## Räkna bildrutor

Övningen kör ett bestämt antal bildrutor (uppgiften säger hur många) med exakt 60 bilder per
sekund. Vill du skriva något vid en viss tid kan du räkna själv:

```gdscript
var bilder := 0

func _process(delta):
	bilder += 1
	if bilder == 60:       # efter en sekund
		print(int(round(position.x)))
```
