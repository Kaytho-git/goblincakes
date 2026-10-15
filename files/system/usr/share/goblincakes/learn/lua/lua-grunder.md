# Lua: utskrift och variabler

Lua är ett litet, lättläst språk – det WoW-tillägg skrivs i.

```lua
print("Hej från Lua!")
local namn = "Kaytho"
local nivå = 80
print(namn .. " är nivå " .. nivå)
```

- `local` skapar en variabel som bara finns där den skapades. **Använd alltid `local`** – i WoW
  krockar annars dina variabler med andra tilläggs.
- Strängar sätts ihop med **två punkter** `..` (inte `+`).
- `--` startar en kommentar.
- En variabel som inte fått något värde är `nil` (= ingenting).
