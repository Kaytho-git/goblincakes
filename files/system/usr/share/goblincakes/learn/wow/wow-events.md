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
