# Git: spara versioner

**Git** sparar versioner av dina filer – du kan alltid se vad som ändrats och gå tillbaka.

```bash
git init                         # gör mappen till ett Git-förråd
git config user.name "Kaytho"    # vem du är (en gång)
git config user.email "kaytho@example.com"
git add main.lua                 # välj vad som ska med i nästa version
git commit -m "Första versionen" # spara versionen med en beskrivning
git log --oneline                # visa versionerna
```

Tänk: **add** = lägg i påsen, **commit** = försegla påsen med en lapp. Skriv meddelanden som
säger *varför*: "Lägg till /hej-kommandot", inte "ändringar".

Här i lärläget: lägg till `-q` (tyst) på `init` och `commit` så att utskriften blir ren.
