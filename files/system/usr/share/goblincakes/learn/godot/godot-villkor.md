# Villkor och loopar

```gdscript
if hp <= 0:
	print("Död")
elif hp < 30:
	print("Låg hälsa!")
else:
	print("Mår bra")
```

Jämförelser: `==`, `!=`, `<`, `<=`, `>`, `>=`. Kombinera med `and`, `or`, `not`.

## Loopar

```gdscript
for i in range(3):          # 0, 1, 2
	print(i)
for i in range(1, 4):       # 1, 2, 3
	print("Våg ", i)
for namn in ["Bo", "Ann"]:  # varje sak i en lista
	print(namn)
while hp > 0:
	hp -= 10
```

## match – många val

```gdscript
match klass:
	"mage":
		print("Frostbolt")
	"warrior":
		print("Charge")
	_:
		print("Attack")    # _ = allt annat
```
