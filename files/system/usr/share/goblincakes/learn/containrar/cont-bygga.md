# Egen image med Containerfile

En **Containerfile** (Docker kallar den Dockerfile) är receptet för en egen image:

```dockerfile
FROM python:3.13-slim        # börja från en färdig image
WORKDIR /app                 # gå till /app (skapas)
COPY app.py .                # kopiera från din mapp in i imagen
RUN pip install requests     # kör ett kommando när imagen byggs
ENV KLASS=Shaman             # standardvärde – kan ändras med -e
EXPOSE 8000                  # dokumentation: tjänsten lyssnar här
CMD ["python3", "app.py"]    # vad som startar när containern körs
```

```bash
podman build -t goblinapp .       # bygg (punkten = den här mappen)
podman run --rm goblinapp
podman run --rm -e KLASS=Mage goblinapp
```

- Varje rad blir ett **lager**; ändrar du bara app.py byggs bara det som kommer efter COPY om.
- Lägg aldrig lösenord i Containerfile – de syns för alla som har imagen. Använd `-e` eller
  `--env-file` när containern startar.

> Övningsdatorn har inget nätverk: `RUN dnf/pip install …` låtsas att paketen kom med.
