# Funktioner, arrayer och ordböcker

## Egna funktioner

```gdscript
func skada(bas: int, kritisk: bool) -> int:
	if kritisk:
		return bas * 2
	return bas
```

`-> int` säger vad funktionen ger tillbaka. Anropa: `print(skada(10, true))`.

## Arrayer – listor

```gdscript
var loot := ["Svärd", "Sköld"]
loot.append("Dryck")      # lägg till sist
print(loot.size())        # 3
print(loot[0])            # Svärd (första = 0)
if loot.has("Sköld"):
	print("Har sköld")
```

## Ordböcker (Dictionary) – namn → värde

```gdscript
var poang := {"Kaytho": 10, "Bo": 25}
poang["Ann"] = 18
for namn in poang:         # går igenom nycklarna
	print(namn, ": ", poang[namn])
```
