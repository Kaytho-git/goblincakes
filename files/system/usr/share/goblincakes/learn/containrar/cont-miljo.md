# Miljövariabler och hemligheter

Images ställs in med **miljövariabler** i stället för att man ändrar filer i dem:

```bash
podman run --rm -e KLASS=Druid alpine sh -c 'echo "Klass: $KLASS"'
```

(Enkla citattecken: `$KLASS` ska läsas **inne i containern**, inte av din egen terminal.)

MariaDB-imagen läser t.ex. `MARIADB_ROOT_PASSWORD`, `MARIADB_DATABASE`, `MARIADB_USER` och
`MARIADB_PASSWORD`. Utan något lösenordsval vägrar den starta – läs `podman logs`!

## Hemligheter

Skriv inte lösenord direkt i kommandon som hamnar i historiken eller i Git. Lägg dem i en fil som
bara du får läsa:

```bash
printf 'MARIADB_ROOT_PASSWORD=%s\n' "$(openssl rand -hex 12)" > db.env
chmod 600 db.env                 # bara du
podman run -d --env-file db.env mariadb:11
```

Lägg `db.env` i `.gitignore`. GOBLINCAKES gör så med Ianseo (`~/.config/goblincakes/ianseo.env`).
