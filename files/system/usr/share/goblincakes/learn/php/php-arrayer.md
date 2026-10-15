# PHP: arrayer

```php
<?php
$raid = ["Kaytho", "Bo"];
$raid[] = "Cia";                       // lägg till sist
echo count($raid) . "\n";             // 3

$skytt = ["namn" => "Bo", "poang" => 655];
echo $skytt["namn"] . "\n";

foreach ($skytt as $nyckel => $värde) {
    echo "$nyckel: $värde\n";
}
echo implode(", ", $raid) . "\n";     // Kaytho, Bo, Cia
```

Sortera: `sort($a)` / `rsort($a)` (störst först), egen ordning med
`usort($a, fn($x, $y) => $y["poang"] <=> $x["poang"])`.
