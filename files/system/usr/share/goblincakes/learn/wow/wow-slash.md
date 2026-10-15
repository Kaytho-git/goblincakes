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
