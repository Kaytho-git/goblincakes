# PHP: databaser med PDO

**PDO** är PHP:s sätt att prata med databaser (MariaDB/MySQL, SQLite …):

```php
<?php
$db = new PDO("mysql:host=localhost;dbname=ianseo", "ianseo", "ianseo",
              [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
foreach ($db->query("SELECT namn, poang FROM skyttar ORDER BY poang DESC") as $rad) {
    echo $rad["namn"] . " " . $rad["poang"] . "\n";
}
```

Här i lärläget används SQLite: `new PDO("sqlite::memory:")` (en databas i minnet) – SQL:en är
densamma. **Så fort något användaren skrivit ska in i frågan: `prepare` + `execute`**, aldrig att
sätta ihop strängar (se Säkerhet).
