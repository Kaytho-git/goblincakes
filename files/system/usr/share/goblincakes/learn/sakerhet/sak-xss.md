# XSS: skriv ut användarens text säkert

Om någon skriver `<script>stjäl(document.cookie)</script>` som sitt namn, och sidan skriver ut
namnet som det är, så **körs** skriptet hos alla som tittar. Det kallas **XSS** (cross-site scripting).

Skydd: gör om specialtecknen till ofarlig text när du skriver ut:

```php
echo "<p>Anmäld: " . htmlspecialchars($namn, ENT_QUOTES, "UTF-8") . "</p>";
```

`<` blir `&lt;` och visas som tecknet i stället för att bli en tagg. Gör det **vid utskriften** –
varje gång, för allt som kommer utifrån (formulär, databasen, adressen). I JavaScript:
`element.textContent = text` (aldrig `innerHTML` med användarens text).
