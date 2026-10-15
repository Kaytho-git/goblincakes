# SQL-injektion och prepared statements

Det här är farligt:

```php
$db->query("SELECT * FROM anvandare WHERE namn = '" . $_POST["namn"] . "'");
```

Skriver någon `' OR '1'='1` som namn blir frågan `… WHERE namn = '' OR '1'='1'` – alla användare.
Med `'; DROP TABLE anvandare; --` kan tabellen försvinna. Det kallas **SQL-injektion** och är en av
de vanligaste attackerna.

**Lösningen är alltid prepared statements** – frågan och värdena skickas var för sig, så värdet kan
aldrig bli SQL:

```php
$st = $db->prepare("SELECT namn, poang FROM skyttar WHERE namn = ?");
$st->execute([$_POST["namn"]]);
$rad = $st->fetch(PDO::FETCH_ASSOC);
```

Det här momentet går inte att hoppa över – det gäller i varje rad PHP som rör en databas.
