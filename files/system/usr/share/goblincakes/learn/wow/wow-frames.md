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
