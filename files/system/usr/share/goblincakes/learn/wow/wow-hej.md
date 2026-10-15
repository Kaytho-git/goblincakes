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
