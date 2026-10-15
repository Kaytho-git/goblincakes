# Git: ångra

| Vill du … | Kommando |
|---|---|
| slänga ändringar i en fil sedan senaste commit | `git restore fil` |
| ta bort en fil från nästa commit (efter add) | `git restore --staged fil` |
| ångra en gammal commit (säkert, även efter push) | `git revert <id>` |
| se gamla versioner | `git log --oneline`, `git show <id>` |

`revert` gör en **ny** commit som tar bort ändringen – historiken finns kvar, så inget försvinner.
Det finns farligare kommandon (`reset --hard`) – använd dem inte förrän du vet exakt vad de gör.
