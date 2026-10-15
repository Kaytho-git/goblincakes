# Lua: funktioner

```lua
local function dps(skada, sekunder)
  return skada / sekunder
end
print(dps(9000, 30))   -- 300
```

- `local function` – samma regel som för variabler.
- En funktion kan returnera **flera värden**: `return min, max` och tas emot med `local a, b = f()`.
- Funktioner är vanliga värden: de kan sparas i variabler och skickas till andra funktioner –
  det är så WoW anropar din kod när något händer (`SetScript("OnEvent", function … end)`).
