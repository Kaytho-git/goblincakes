# Villkor och felkoder

Varje kommando avslutas med en **felkod**: `0` = gick bra, annat = fel. Den finns i `$?`.

```bash
if [ -f inställningar.txt ]; then
  echo "Filen finns"
else
  echo "Filen saknas"
fi
```

| Test | Betyder |
|---|---|
| `-f fil` / `-d mapp` | finns filen / mappen? |
| `-z "$x"` | är texten tom? |
| `"$a" = "$b"` | samma text |
| `$a -eq $b`, `-lt`, `-gt` | tal: lika, mindre, större |

Kortare: `mkdir backup && echo "klart"` (bara om det gick) och `cd mapp || exit 1` (om det inte gick).
Mellanslagen inne i `[ … ]` är **obligatoriska**.
