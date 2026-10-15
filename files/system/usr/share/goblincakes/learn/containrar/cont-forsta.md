# Vad är en container?

En **container** är ett program som körs i en egen liten låda: egna filer, egen nätverksadress,
men samma Linux-kärna som datorn. Den kan inte röra resten av systemet om du inte ger den lov.
GOBLINCAKES kör Ianseo så – webbservern och databasen i varsin container.

- **Image** = mallen: alla filer som behövs + vad som ska startas. Hämtas från ett register
  (Docker Hub, Quay, Fedoras register …).
- **Container** = en körning av en image. Du kan starta många från samma image.

```bash
podman pull alpine                         # hämta en image
podman images                              # visa hämtade images
podman run --rm alpine echo "Hej"          # starta, kör echo, ta bort efteråt (--rm)
podman run --rm alpine cat /etc/os-release # filen INNE i containern – Alpine, inte Fedora!
```

GOBLINCAKES använder **Podman** (Docker gör samma sak och kommandona är nästan likadana).
Podman körs **rootless** – som ditt eget konto, utan lösenord och utan root.

> Övningsdatorn har inget nätverk, så här finns en övnings-podman med de här imagerna:
> alpine, fedora, nginx, mariadb, python och php. Kommandona och svaren är som de riktiga.
