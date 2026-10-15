# PHP: funktioner

```php
<?php
function snitt(array $poang): float {
    return array_sum($poang) / count($poang);
}
echo snitt([8, 9, 10, 9]) . "\n";     // 9
```

Skriv gärna **typer** (`int`, `float`, `string`, `array`, `bool`) – då säger PHP till direkt när fel
sorts värde skickas in. `declare(strict_types=1);` överst gör kontrollen ännu noggrannare.
