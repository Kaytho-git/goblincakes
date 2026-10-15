# En egen export

En vanlig egen modul: ta ut data ur Ianseo i ett format någon annan vill ha – CSV till ett
kalkylark, en lista till klubbens hemsida.

```php
$st = $db->prepare("SELECT … WHERE EnDivision = ? ORDER BY …");
$st->execute([$division]);
$ut = fopen("php://output", "w");
fputcsv($ut, ["Namn", "Klubb", "Poäng"]);
foreach ($st as $r) {
    fputcsv($ut, [$r["EnFirstName"] . " " . $r["EnName"], $r["CoName"], $r["QuScore"]]);
}
```

`fputcsv` sköter citattecken och kommatecken i namnen åt dig. På en riktig sida skickar man
först `header("Content-Type: text/csv; charset=utf-8");` så att webbläsaren laddar ner filen.
