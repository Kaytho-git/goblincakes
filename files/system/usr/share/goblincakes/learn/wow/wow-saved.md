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
