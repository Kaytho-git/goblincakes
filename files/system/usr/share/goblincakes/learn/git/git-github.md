# Git: GitHub

GitHub är ett ställe på nätet där förråd kan ligga – som backup och för att samarbeta.

```bash
git remote add origin https://github.com/dittnamn/mitt-tillagg.git
git push -u origin main      # skicka upp (första gången med -u)
git pull                     # hämta det som ändrats där
git clone <url>              # hämta ett helt förråd
```

I GOBLINCAKES finns `gh` (GitHub CLI): `gh auth login` loggar in en gång, `gh repo create`
skapar ett förråd. Lägg **aldrig** lösenord eller nycklar i ett publikt förråd.

(Övningsdatorn har inget nät – här provar du kopplingen, uppladdningen gör du på riktigt.)
