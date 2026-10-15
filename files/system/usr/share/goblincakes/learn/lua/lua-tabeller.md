# Lua: tabeller som listor

En **tabell** är Luas enda samlingstyp. Som lista:

```lua
local raid = {"Kaytho", "Bo", "Cia"}
print(raid[1])            -- Kaytho – Lua börjar på 1!
print(#raid)              -- 3
table.insert(raid, "Dan")
for i, namn in ipairs(raid) do
  print(i .. ": " .. namn)
end
```

Bra att ha: `table.sort(t)` sorterar (med en funktion för egen ordning:
`table.sort(t, function(a, b) return a > b end)`), `table.concat(t, ", ")` gör en sträng.
