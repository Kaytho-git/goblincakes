# Git: grenar

En **gren** är en egen linje av versioner – prova något nytt utan att röra det som fungerar:

```bash
git switch -c ny-funktion    # skapa och gå till grenen
# … ändra, add, commit …
git switch main              # tillbaka – ändringarna finns kvar i grenen
git merge ny-funktion        # ta in grenen i main när den är klar
git branch                   # visa grenarna
```

`git init -b main` gör att huvudgrenen heter `main` från början.
