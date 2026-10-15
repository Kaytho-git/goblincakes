# Lua: tabeller med nycklar

Samma tabell kan ha **nycklar** – som en ordbok:

```lua
local spelare = {namn = "Kaytho", klass = "Präst", nivå = 80}
print(spelare.namn)          -- eller spelare["namn"]
spelare.guild = "GOBLINCAKES"
for nyckel, värde in pairs(spelare) do
  print(nyckel, värde)
end
```

`pairs` går igenom alla nycklar men **i ingen bestämd ordning** – sortera nycklarna själv om
ordningen spelar roll. Tabeller kan ligga i tabeller: `raid[1].namn`.
