# PHP: grunder

PHP körs på **servern** och gör HTML som skickas till webbläsaren. Koden står i `<?php … ?>`:

```php
<?php
$namn = "Kaytho";
$nivå = 80;
echo "Hej $namn, du är nivå $nivå\n";      // variabler fungerar inne i "…"
echo 'Enkla citattecken: $namn' . "\n";      // … men inte i '…'
echo "Nästa nivå: " . ($nivå + 1) . "\n";    // . sätter ihop
```

- Variabler börjar med `$`.
- Varje rad slutar med `;`.
- `"\n"` = ny rad (på en hemsida används `<br>` eller nya taggar i stället).
