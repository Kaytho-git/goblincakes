from lib import write_track, T
M = []
M.append({"id": "lua-grunder", "title": "Lua: utskrift och variabler", "requires": [],
 "summary": "`print(...)`; `local x = 5`; strängar sätts ihop med `..`; `--` kommentar; `nil` = inget värde.",
 "lesson_md": """
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
""", "tasks": [
 T("lua-grunder-1", 1, "Hälsa", "Skapa local namn = \"Kaytho\" och skriv ut: Hej Kaytho!",
   'local namn = "Kaytho"\nprint("Hej " .. namn .. "!")', {"expect": "Hej Kaytho!"},
   ["Sätt ihop strängar med ..", 'print("Hej " .. namn .. "!")'], 'local namn = "Kaytho"\n'),
 T("lua-grunder-2", 2, "Räkna mana", "Du har 5000 mana och en besvärjelse kostar 350. Räkna hur många hela gånger du kan kasta den och skriv ut: 14 gånger",
   'local mana = 5000\nlocal kostnad = 350\nlocal ganger = math.floor(mana / kostnad)\nprint(ganger .. " gånger")', {"expect": "14 gånger"},
   ["/ ger decimaltal i Lua.", "math.floor() rundar nedåt."]),
]})
M.append({"id": "lua-villkor", "title": "Lua: villkor", "requires": ["lua-grunder"],
 "summary": "`if x then … elseif … else … end`; inte-lika är `~=`; `and`/`or`/`not`; bara `nil` och `false` är falska.",
 "lesson_md": """
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
""", "tasks": [
 T("lua-villkor-1", 1, "Läk?", "local liv = 15. Skriv ut Läk mig! om liv är under 20, annars Allt lugnt.",
   'local liv = 15\nif liv < 20 then\n  print("Läk mig!")\nelse\n  print("Allt lugnt")\nend', {"expect": "Läk mig!"},
   ["if liv < 20 then … else … end", "Glöm inte end."], "local liv = 15\n"),
 T("lua-villkor-2", 2, "Standardvärde", "local vald = nil. Skriv ut värdet av vald, eller Ingen vald om den är nil – med ett or-knep på en rad.",
   'local vald = nil\nprint(vald or "Ingen vald")', {"expect": "Ingen vald"},
   ["x or y ger y när x är nil.", 'print(vald or "Ingen vald")'], "local vald = nil\n"),
]})
M.append({"id": "lua-loopar", "title": "Lua: loopar", "requires": ["lua-villkor"],
 "summary": "`for i = 1, 5 do … end` (steg: `for i = 10, 1, -1`); `while x do … end`; `break`.",
 "lesson_md": """
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
""", "tasks": [
 T("lua-loopar-1", 1, "Vågor", "Skriv ut Våg 1, Våg 2 och Våg 3 på var sin rad med en for-loop.",
   'for i = 1, 3 do\n  print("Våg " .. i)\nend', {"expect": "Våg 1\nVåg 2\nVåg 3"},
   ["for i = 1, 3 do … end", 'print("Våg " .. i)']),
 T("lua-loopar-2", 2, "Summa", "Räkna ihop talen 1 till 100 med en loop och skriv ut: 5050",
   'local summa = 0\nfor i = 1, 100 do\n  summa = summa + i\nend\nprint(summa)', {"expect": "5050"},
   ["Börja med local summa = 0.", "summa = summa + i i loopen."]),
]})
M.append({"id": "lua-tabeller", "title": "Lua: tabeller som listor", "requires": ["lua-loopar"],
 "summary": "`{\"a\", \"b\"}`, index från **1**, `#t` = längd, `table.insert`, `ipairs`, `table.sort`, `table.concat`.",
 "lesson_md": """
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
""", "tasks": [
 T("lua-tabeller-1", 1, "Första och antal", 'local raid = {"Kaytho", "Bo", "Cia"}. Skriv ut första namnet och sedan antalet: Kaytho och 3 på var sin rad.',
   'local raid = {"Kaytho", "Bo", "Cia"}\nprint(raid[1])\nprint(#raid)', {"expect": "Kaytho\n3"},
   ["Index börjar på 1.", "#raid ger antalet."], 'local raid = {"Kaytho", "Bo", "Cia"}\n'),
 T("lua-tabeller-2", 2, "Sorterat", 'local skada = {120, 300, 95}. Sortera störst först och skriv ut: 300, 120, 95',
   'local skada = {120, 300, 95}\ntable.sort(skada, function(a, b) return a > b end)\nprint(table.concat(skada, ", "))', {"expect": "300, 120, 95"},
   ["table.sort med en jämförelsefunktion.", 'table.concat(skada, ", ")'], "local skada = {120, 300, 95}\n"),
]})
M.append({"id": "lua-ordbocker", "title": "Lua: tabeller med nycklar", "requires": ["lua-tabeller"],
 "summary": "`{namn = \"Kaytho\", nivå = 80}`, `t.namn` / `t[\"namn\"]`, `pairs` (ingen ordning), nästlade tabeller.",
 "lesson_md": """
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
""", "tasks": [
 T("lua-ordbocker-1", 1, "Karaktärsblad", 'Skapa local k = {namn = "Kaytho", klass = "Präst"} och skriv ut: Kaytho (Präst)',
   'local k = {namn = "Kaytho", klass = "Präst"}\nprint(k.namn .. " (" .. k.klass .. ")")', {"expect": "Kaytho (Präst)"},
   ["k.namn och k.klass", 'print(k.namn .. " (" .. k.klass .. ")")']),
 T("lua-ordbocker-2", 2, "Räkna klasser", 'local raid = {"Präst", "Krigare", "Präst"}. Räkna hur många av varje i en tabell och skriv ut Krigare 1 och Präst 2 (i bokstavsordning).',
   'local raid = {"Präst", "Krigare", "Präst"}\nlocal antal = {}\nfor _, k in ipairs(raid) do\n  antal[k] = (antal[k] or 0) + 1\nend\nlocal namn = {}\nfor k in pairs(antal) do table.insert(namn, k) end\ntable.sort(namn)\nfor _, k in ipairs(namn) do print(k .. " " .. antal[k]) end',
   {"expect": "Krigare 1\nPräst 2"}, ["(antal[k] or 0) + 1 räknar upp.", "Lägg nycklarna i en lista och sortera den innan du skriver ut."],
   'local raid = {"Präst", "Krigare", "Präst"}\n'),
]})
M.append({"id": "lua-funktioner", "title": "Lua: funktioner", "requires": ["lua-ordbocker"],
 "summary": "`local function namn(a, b) return … end`; flera returvärden; funktioner är värden (callbacks); `...`.",
 "lesson_md": """
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
""", "tasks": [
 T("lua-funktioner-1", 1, "DPS", "Skriv local function dps(skada, sekunder) som returnerar skadan per sekund, och skriv ut dps(9000, 30): 300",
   'local function dps(skada, sekunder)\n  return skada / sekunder\nend\nprint(dps(9000, 30))', {"expect": "300"},
   ["return skada / sekunder", "print(dps(9000, 30))"]),
 T("lua-funktioner-2", 2, "Min och max", 'Skriv local function minmax(t) som returnerar både minsta och största talet. Skriv ut minmax({4, 9, 1}) som: 1 9',
   'local function minmax(t)\n  local lo, hi = t[1], t[1]\n  for _, v in ipairs(t) do\n    if v < lo then lo = v end\n    if v > hi then hi = v end\n  end\n  return lo, hi\nend\nlocal a, b = minmax({4, 9, 1})\nprint(a .. " " .. b)',
   {"expect": "1 9"}, ["Börja med första värdet som både min och max.", "return lo, hi – och ta emot med local a, b = minmax(…)"]),
]})
write_track("lua", M)

W = []
W.append({"id": "wow-hej", "title": "Ett tillägg som hälsar", "requires": ["lua-funktioner"],
 "summary": "Ett tillägg = en mapp i Interface/AddOns med en .toc och Lua-filer; en frame lyssnar på events: `RegisterEvent` + `SetScript(\"OnEvent\", …)`.",
 "lesson_md": """
# Ett tillägg som hälsar

Ett WoW-tillägg är en mapp i `World of Warcraft/_retail_/Interface/AddOns` (i GOBLINCAKES:
`~/Games/WoW/Retail/AddOns`) med en **.toc-fil** och en eller flera **Lua-filer**. Mappen och
.toc-filen ska heta samma sak:

```
## Interface: 120001
## Title: Mitt tillägg
## SavedVariables: MittTillaggDB
main.lua
```

`## Interface` är spelets version – står det fel visas tillägget som "inaktuellt".

WoW berättar saker som händer med **events**, t.ex. `PLAYER_LOGIN` när du loggat in. En **frame**
lyssnar:

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
  print("Inloggad!")
end)
```

**Här i lärläget** körs koden mot en liten låtsasversion av WoW:s API (ditt namn är Kaytho).
Slutprovet gör du i spelet – `/reload` laddar om tilläggen, och BugSack visar fel.
""", "tasks": [
 T("wow-hej-1", 1, "Hälsa när du loggar in", 'Gör så att tillägget skriver ut "Välkommen, Kaytho!" när PLAYER_LOGIN kommer. Använd UnitName("player") för namnet.',
   'local f = CreateFrame("Frame")\nf:RegisterEvent("PLAYER_LOGIN")\nf:SetScript("OnEvent", function(self, event)\n  print("Välkommen, " .. UnitName("player") .. "!")\nend)\n',
   {"expect": "Välkommen, Kaytho!"},
   ['UnitName("player") ger ditt namn.', 'print("Välkommen, " .. UnitName("player") .. "!")'],
   'local f = CreateFrame("Frame")\nf:RegisterEvent("PLAYER_LOGIN")\nf:SetScript("OnEvent", function(self, event)\n  -- skriv här\nend)\n'),
]})
W.append({"id": "wow-slash", "title": "Egna slash-kommandon", "requires": ["wow-hej"],
 "summary": "`SLASH_NAMN1 = \"/kort\"` + `SlashCmdList[\"NAMN\"] = function(text) … end`; texten efter kommandot kommer in som sträng – dela med `strsplit` eller `text:match`.",
 "lesson_md": """
# Egna slash-kommandon

Ett eget kommando (`/hej`) skapas med två rader:

```lua
SLASH_HEJ1 = "/hej"          -- fler namn: SLASH_HEJ2 = "/h"
SlashCmdList["HEJ"] = function(text)
  print("Du skrev: " .. text)
end
```

Namnet efter `SLASH_` och nyckeln i `SlashCmdList` måste vara **samma** (versaler). Det som skrivs
efter kommandot kommer in som en sträng. Vanliga sätt att läsa den:

```lua
local kommando, rest = text:match("^(%S+)%s*(.*)$")   -- första ordet + resten
```

Testa i spelet med `/hej något`. Här i lärläget körs kommandona från uppgiften automatiskt.
""", "tasks": [
 T("wow-slash-1", 1, "/hej", 'Lägg till kommandot /hej som skriver ut "Hej <text>!" – /hej Raid ger: Hej Raid!',
   'SLASH_HEJ1 = "/hej"\nSlashCmdList["HEJ"] = function(text)\n  print("Hej " .. text .. "!")\nend\n',
   {"expect": "Hej Raid!"}, ["Det man skriver efter kommandot kommer in som text.", 'print("Hej " .. text .. "!")'],
   'SLASH_HEJ1 = "/hej"\nSlashCmdList["HEJ"] = function(text)\n  -- skriv här\nend\n', files={"slash.txt": "/hej Raid\n"}),
 T("wow-slash-2", 2, "Underkommandon", 'Gör /gc med två underkommandon: "/gc pull 10" skriver Pull om 10 s och "/gc ready" skriver Ready check! – allt annat skriver Okänt.',
   'SLASH_GC1 = "/gc"\nSlashCmdList["GC"] = function(text)\n  local cmd, rest = text:match("^(%S+)%s*(.*)$")\n  if cmd == "pull" then\n    print("Pull om " .. rest .. " s")\n  elseif cmd == "ready" then\n    print("Ready check!")\n  else\n    print("Okänt")\n  end\nend\n',
   {"expect": "Pull om 10 s\nReady check!\nOkänt"},
   ['text:match("^(%S+)%s*(.*)$") ger första ordet och resten.', "if cmd == \"pull\" then … elseif cmd == \"ready\" then … else … end"],
   'SLASH_GC1 = "/gc"\nSlashCmdList["GC"] = function(text)\nend\n', files={"slash.txt": "/gc pull 10\n/gc ready\n/gc dans\n"}),
]})
W.append({"id": "wow-events", "title": "Events med argument", "requires": ["wow-slash"],
 "summary": "OnEvent får `(self, event, ...)`; `ADDON_LOADED` har tilläggets namn – kolla att det är ditt; en tabell med en funktion per event håller koden snygg.",
 "lesson_md": """
# Events med argument

Många events skickar med **argument**. `ADDON_LOADED` kommer en gång per tillägg som laddas,
med tilläggets namn – ditt tillägg ska bara reagera på sitt eget:

```lua
local ADDON = ...                 -- den första raden i varje fil: tilläggets namn
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, name)
  if name == ADDON then
    print(ADDON .. " laddat")
    self:UnregisterEvent("ADDON_LOADED")
  end
end)
```

Med många events blir det snyggare med en tabell – en funktion per event:

```lua
local events = {}
function events.PLAYER_LOGIN() print("Inloggad") end
f:SetScript("OnEvent", function(self, event, ...) events[event](...) end)
for event in pairs(events) do f:RegisterEvent(event) end
```

Tillägget heter **MittTillagg** här i lärläget – och precis som i spelet laddas ett annat tillägg
(Blizzard_Kalender) först.
""", "tasks": [
 T("wow-events-1", 2, "Bara mitt tillägg", 'Lyssna på ADDON_LOADED och skriv ut "MittTillagg laddat" när det är ditt eget tillägg som laddats. Ta tilläggets namn från ... (första raden).',
   'local ADDON = ...\nlocal f = CreateFrame("Frame")\nf:RegisterEvent("ADDON_LOADED")\nf:SetScript("OnEvent", function(self, event, name)\n  if name == ADDON then\n    print(ADDON .. " laddat")\n  end\nend)\n',
   {"expect": "MittTillagg laddat"},
   ["local ADDON = ... ger tilläggets namn.", "OnEvent får (self, event, name) – jämför name med ADDON."]),
 T("wow-events-2", 3, "En tabell med events", 'Skriv tillägget med en tabell events: events.ADDON_LOADED(name) skriver "Laddat: <name>" och events.PLAYER_LOGIN() skriver "Inloggad". Registrera alla events i tabellen med en loop.',
   'local f = CreateFrame("Frame")\nlocal events = {}\nfunction events.ADDON_LOADED(name) print("Laddat: " .. name) end\nfunction events.PLAYER_LOGIN() print("Inloggad") end\nf:SetScript("OnEvent", function(self, event, ...) events[event](...) end)\nfor event in pairs(events) do f:RegisterEvent(event) end\n',
   {"expect": "Laddat: Blizzard_Kalender\nLaddat: MittTillagg\nInloggad"},
   ["function events.PLAYER_LOGIN() … end", "for event in pairs(events) do f:RegisterEvent(event) end"]),
]})
W.append({"id": "wow-saved", "title": "Spara inställningar (SavedVariables)", "requires": ["wow-events"],
 "summary": "`## SavedVariables: MittDB` i .toc; tabellen finns först vid ADDON_LOADED; `MittDB = MittDB or {}` + standardvärden; sparas vid utloggning/`/reload`.",
 "lesson_md": """
# Spara inställningar (SavedVariables)

Vill tillägget komma ihåg något mellan inloggningar skriver man i .toc-filen:

```
## SavedVariables: MittTillaggDB
```

WoW sparar då den **globala** tabellen `MittTillaggDB` när du loggar ut eller gör `/reload`, och
laddar tillbaka den **innan `ADDON_LOADED`** för ditt tillägg. Första gången finns den inte –
därför:

```lua
f:SetScript("OnEvent", function(self, event, name)
  if name ~= "MittTillagg" then return end
  MittTillaggDB = MittTillaggDB or {}
  if MittTillaggDB.antal == nil then MittTillaggDB.antal = 0 end   -- standardvärde
  MittTillaggDB.antal = MittTillaggDB.antal + 1
end)
```

Läs aldrig sparade värden direkt när filen laddas – vänta på `ADDON_LOADED`.
""", "tasks": [
 T("wow-saved-1", 2, "Räkna inloggningar", 'Använd den sparade tabellen MittTillaggDB: vid ADDON_LOADED för "MittTillagg", skapa den om den saknas, öka MittTillaggDB.antal med 1 (standard 0) och skriv ut "Inloggning nummer 1".',
   'local f = CreateFrame("Frame")\nf:RegisterEvent("ADDON_LOADED")\nf:SetScript("OnEvent", function(self, event, name)\n  if name ~= "MittTillagg" then return end\n  MittTillaggDB = MittTillaggDB or {}\n  MittTillaggDB.antal = (MittTillaggDB.antal or 0) + 1\n  print("Inloggning nummer " .. MittTillaggDB.antal)\nend)\n',
   {"expect": "Inloggning nummer 1"},
   ["MittTillaggDB = MittTillaggDB or {}", "MittTillaggDB.antal = (MittTillaggDB.antal or 0) + 1"]),
]})
W.append({"id": "wow-frames", "title": "Något som syns: frames och text", "requires": ["wow-saved"],
 "summary": "`CreateFrame(\"Frame\", \"Namn\", UIParent, \"BackdropTemplate\")`, `SetSize`, `SetPoint`, `CreateFontString(nil, \"OVERLAY\", \"GameFontNormal\")`, `SetText`; flytta: `SetMovable`/`RegisterForDrag`.",
 "lesson_md": """
# Något som syns: frames och text

Frames är också det man ser på skärmen:

```lua
local ruta = CreateFrame("Frame", "MinRuta", UIParent, "BackdropTemplate")
ruta:SetSize(200, 60)
ruta:SetPoint("CENTER")
local text = ruta:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER")
text:SetText("Hej!")
```

- `SetPoint("CENTER")` = mitt på föräldern. Andra: `"TOPLEFT"`, `"BOTTOM"` … och avstånd:
  `SetPoint("TOP", UIParent, "TOP", 0, -100)`.
- `SetText` byter text, `GetText` läser den.
- Göra den flyttbar: `SetMovable(true)`, `EnableMouse(true)`, `RegisterForDrag("LeftButton")`
  och skripten `OnDragStart`/`OnDragStop` med `self:StartMoving()`/`self:StopMovingOrSizing()`.

Här i lärläget syns inget – kontrollen läser rutans storlek och text. Slutprovet: i spelet.
""", "tasks": [
 T("wow-frames-1", 2, "En ruta med text", 'Skapa en frame som heter GoblinRuta (namn som andra argument) med storleken 200 × 60, och en fontstring med texten "Pull om 10". Skriv till sist ut rutans storlek och text: 200 60 Pull om 10',
   'local ruta = CreateFrame("Frame", "GoblinRuta", UIParent)\nruta:SetSize(200, 60)\nlocal text = ruta:CreateFontString(nil, "OVERLAY", "GameFontNormal")\ntext:SetPoint("CENTER")\ntext:SetText("Pull om 10")\nlocal w, h = GoblinRuta:GetSize()\nprint(w .. " " .. h .. " " .. text:GetText())\n',
   {"expect": "200 60 Pull om 10"},
   ['CreateFrame("Frame", "GoblinRuta", UIParent)', "ruta:GetSize() ger bredd och höjd; text:GetText() ger texten."]),
]})
write_track("wow", W)
