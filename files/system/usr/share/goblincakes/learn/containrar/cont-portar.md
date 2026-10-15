# Portar – nå tjänsten

En container har sitt eget nätverk. För att nå nginx inifrån datorn **publicerar** du en port:

```bash
podman run -d --name web -p 8080:80 nginx     # datorns 8080 → containerns 80
curl localhost:8080                            # hämtar sidan
podman port web                                # 80/tcp -> 0.0.0.0:8080
```

- Första talet är **datorns** port, andra är **containerns**.
- `0.0.0.0` = alla nätverk: andra datorer i nätverket når den också (om brandväggen släpper
  igenom). `-p 127.0.0.1:8180:80` = **bara den här datorn** – så kör GOBLINCAKES Ianseo tills du
  slår på nätverksläget.
- Rootless Podman får inte använda portar under 1024 (t.ex. 80). Ta 8080, 8180 …
- Två containrar kan inte dela samma port på datorn.
