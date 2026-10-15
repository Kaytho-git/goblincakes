# Inloggning med sessioner

När någon loggat in kommer sidan ihåg det med en **session** – en hemlig nyckel i en cookie:

```php
session_start();
// … kontrollera namn + password_verify …
session_regenerate_id(true);           // ny nyckel efter inloggning
$_SESSION["anvandare"] = $namn;
```

- **`session_regenerate_id(true)` efter inloggning** – annars kan någon som fått tag på en gammal
  nyckel ta över kontot (session fixation).
- Sidor som kräver inloggning kollar `isset($_SESSION["anvandare"])` först.
- Logga ut: `$_SESSION = []; session_destroy();`
- Cookie-inställningar: `httponly` (JavaScript kommer inte åt den), `secure` (bara https),
  `samesite=Lax` (skydd mot att andra sidor skickar formulär i ditt namn).
