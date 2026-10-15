# Quadlets – containrar som startar själva

Med `podman run` måste du starta containern själv efter varje omstart. En **quadlet** är en
liten fil som låter systemd sköta den – starta vid inloggning, starta om om den kraschar:

```ini
# ~/.config/containers/systemd/web.container
[Unit]
Description=Min webbsida

[Container]
Image=docker.io/library/nginx:latest
PublishPort=127.0.0.1:8090:80
Volume=%h/sida:/usr/share/nginx/html:Z

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload     # läs in filerna (gör om efter varje ändring)
systemctl --user start web         # enheten heter som filen
systemctl --user status web
```

- `%h` = din hemmapp.
- `WantedBy=default.target` = startar vid inloggning. `systemctl --user enable` fungerar
  **inte** för quadlets – det är [Install]-raden som gäller.
- `.pod`-filer (`[Pod]` med `PodName=` och `PublishPort=`) och `.volume`-filer finns också.
  En container går med i poden med `Pod=ianseo.pod` och använder volymen med
  `Volume=ianseo-db.volume:/var/lib/mysql`.

GOBLINCAKES Ianseo är precis det här: titta i `~/.config/containers/systemd/` om du har det.
