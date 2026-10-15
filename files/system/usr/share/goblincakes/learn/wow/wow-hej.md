# Ett tillägg som hälsar

Ett WoW-tillägg är en mapp i `Interface/AddOns` med en **.toc-fil** (vad tillägget heter
och vilka filer som ska laddas) och en eller flera **Lua-filer**.

```
## Interface: 120001
## Title: Mitt tillägg
main.lua
```

WoW berättar saker som händer med **events** – t.ex. `PLAYER_LOGIN` när du loggat in.
För att höra dem gör man en **frame** som lyssnar:

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
  print("Inloggad!")
end)
```

**Här i lärläget** körs koden mot en liten låtsasversion av WoW:s API – grunderna går att
prova direkt. Slutprovet gör du i spelet (`/reload` laddar om tilläggen).
