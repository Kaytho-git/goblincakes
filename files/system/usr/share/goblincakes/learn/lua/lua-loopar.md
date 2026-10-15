# Lua: loopar

```lua
for i = 1, 3 do
  print("Våg " .. i)
end

for i = 3, 1, -1 do   -- räkna ner: start, slut, steg
  print(i)
end

local n = 0
while n < 3 do
  n = n + 1
end
```

I Lua räknar `for` med **både start och slut** (1, 2, 3). Det finns ingen `+=` – skriv `n = n + 1`.
