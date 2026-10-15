# PHP: villkor och loopar

```php
<?php
$poang = 612;
if ($poang >= 600) {
    echo "Bra!\n";
} elseif ($poang >= 500) {
    echo "Okej\n";
} else {
    echo "Träna mer\n";
}

for ($i = 1; $i <= 3; $i++) {
    echo "Serie $i\n";
}
```

Jämför med `===` (samma värde **och** typ) – `==` gör om typer och kan överraska.
