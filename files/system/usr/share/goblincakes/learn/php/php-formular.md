# PHP: ta emot formulär

Det formuläret skickar finns i `$_POST` (eller `$_GET` för sökningar i adressen):

```php
<?php
if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $namn = trim($_POST["namn"] ?? "");
    if ($namn === "") {
        echo "Skriv ditt namn\n";
    } else {
        echo "Tack " . htmlspecialchars($namn) . "!\n";
    }
}
```

- `?? ""` ger ett standardvärde om fältet saknas.
- **Lita aldrig på det som skickas in** – kontrollera längd, format, tillåtna värden.
- Allt som skrivs tillbaka till sidan går genom `htmlspecialchars()` (mer i spåret Säkerhet).

Här i lärläget fyller vi `$_POST` själva överst i koden, som om formuläret skickats.
