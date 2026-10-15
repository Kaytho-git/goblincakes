# Volymer – data som blir kvar

Allt en container skriver i sina egna filer **försvinner när den tas bort**. Det som ska finnas
kvar (databaser, uppladdningar, inställningar) läggs på en **volym**:

```bash
podman volume create data
podman run --rm -v data:/data alpine sh -c "echo hej > /data/fil.txt"
podman run --rm -v data:/data alpine cat /data/fil.txt     # hej – fast det är en ny container
podman volume ls
```

Eller en **mapp på datorn** (bind mount) – bra för en webbsida du redigerar:

```bash
podman run -d -p 8080:80 -v ./sida:/usr/share/nginx/html:Z nginx
```

`:Z` behövs på Fedora/GOBLINCAKES: SELinux märker mappen så att containern får läsa den.
Utan `:Z` blir det "Permission denied" inne i containern.

Ianseo i GOBLINCAKES har databasen på en volym – därför finns tävlingarna kvar när Ianseo
uppdateras.
