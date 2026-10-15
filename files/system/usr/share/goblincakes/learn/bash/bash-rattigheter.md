# Rättigheter

`ls -l` visar t.ex. `-rwxr-xr--`: tre grupper om tre – **ägaren**, **gruppen**, **alla andra** –
med **r**ead (läsa), **w**rite (skriva) och e**x**ecute (köra).

Som tal: r = 4, w = 2, x = 1, ihop per grupp:

| Tal | Betyder | Används för |
|---|---|---|
| `644` | rw-r--r-- | vanliga filer |
| `755` | rwxr-xr-x | skript och mappar |
| `600` | rw------- | hemligheter (nycklar, lösenord) |

```bash
chmod +x skript.sh      # gör körbar
chmod 600 nyckel.txt    # bara du får läsa
stat -c %a nyckel.txt   # visar 600
```

`sudo` kör ett kommando som administratör – bara när det verkligen behövs.
