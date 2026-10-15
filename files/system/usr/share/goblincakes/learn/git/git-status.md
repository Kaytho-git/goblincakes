# Git: vad har ändrats?

```bash
git status            # vilka filer är ändrade, nya, tillagda?
git status --short    # kort:  M = ändrad,  ?? = ny (inte med i Git än)
git diff              # exakt vilka rader som ändrats (- borta, + nya)
```

Filer som **aldrig** ska med (lösenord, stora filer, byggresultat) skriver man i `.gitignore`:

```
*.log
hemligt.txt
```

Kolla alltid `git status` innan du gör commit – då kommer inget hemligt med av misstag.
