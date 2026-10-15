# Lösenord: hasha, spara aldrig

Spara **aldrig** lösenord som de är – läcker databasen har någon allas lösenord (och folk använder
samma på flera ställen). Spara en **hash**: ett envägsavtryck som inte går att räkna tillbaka.

```php
// när kontot skapas
$hash = password_hash($losenord, PASSWORD_DEFAULT);     // spara $hash i databasen

// vid inloggning
if (password_verify($losenord, $hashFranDatabasen)) {
    // rätt lösenord
}
```

`password_hash` tar hand om salt och en långsam, säker algoritm. Använd **inte** `md5()` eller
`sha1()` för lösenord – de är snabba och knäcks på sekunder. Samma felmeddelande för fel namn och
fel lösenord ("Fel namn eller lösenord") – annars avslöjas vilka konton som finns.
