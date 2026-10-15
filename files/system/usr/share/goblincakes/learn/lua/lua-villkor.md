# Lua: villkor

```lua
local liv = 30
if liv < 20 then
  print("Läk mig!")
elseif liv < 50 then
  print("Halvt liv")
else
  print("Allt lugnt")
end
```

- `if … then`, avslutas med `end`.
- Inte lika med skrivs `~=` (inte `!=`).
- `and`, `or`, `not`. I Lua räknas **bara `nil` och `false` som falskt** – även `0` är sant.
- Vanligt knep: `local namn = valt or "okänd"` ger ett standardvärde.
