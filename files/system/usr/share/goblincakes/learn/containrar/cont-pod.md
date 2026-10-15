# Pods – containrar som hör ihop

En webbsida med databas är två containrar som måste prata med varandra. En **pod** är en grupp
containrar som delar nätverk – de når varandra på `localhost`, precis som på en vanlig server.

```bash
podman pod create --name ianseo -p 8180:80          # portarna sätts på poden
podman run -d --pod ianseo --name ianseo-db -e MARIADB_ROOT_PASSWORD=… mariadb:11
podman run -d --pod ianseo --name ianseo-web php:8.3-apache
podman pod ps
podman pod rm -f ianseo                              # tar bort allt i poden
```

- `-p` går **bara** på poden, inte på containrarna i den.
- Webbcontainern når databasen på `localhost:3306`.
- Så är Ianseo uppbyggt i GOBLINCAKES: poden `ianseo` med `ianseo-db` och `ianseo-web`.
