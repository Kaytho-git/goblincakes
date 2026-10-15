# Containrar i bakgrunden

En webbserver eller databas ska köra hela tiden – i bakgrunden:

```bash
podman run -d --name web nginx     # -d = i bakgrunden, --name = ett eget namn
podman ps                          # körande containrar
podman ps -a                       # även stoppade
podman logs web                    # vad containern har skrivit
podman stop web                    # stoppa
podman start web                   # starta igen (samma container, samma filer)
podman rm web                      # ta bort (måste vara stoppad, eller rm -f)
```

`--format` väljer vad ps visar: `podman ps --format "{{.Names}} {{.State}}"`.

Två containrar kan inte heta samma sak. Ta bort den gamla först, eller låt Podman göra det med
`--replace`.
