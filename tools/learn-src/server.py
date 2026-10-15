from lib import write_track, T
SKYTTAR = "CREATE TABLE skyttar (id INTEGER PRIMARY KEY, namn TEXT, klubb TEXT, poang INTEGER);\nINSERT INTO skyttar (namn, klubb, poang) VALUES ('Anna', 'Lund', 612), ('Bo', 'Malmö', 655), ('Cia', 'Lund', 590), ('Dan', 'Malmö', 601);\n"
P = []
P.append({"id": "php-grunder", "title": "PHP: grunder", "requires": ["html-forsta"],
 "summary": "`<?php … ?>`; `echo`; `$variabler`; `.` sätter ihop strängar; `\"Hej $namn\"` (dubbla citattecken); `;` efter varje rad.",
 "lesson_md": """
# PHP: grunder

PHP körs på **servern** och gör HTML som skickas till webbläsaren. Koden står i `<?php … ?>`:

```php
<?php
$namn = "Kaytho";
$nivå = 80;
echo "Hej $namn, du är nivå $nivå\\n";      // variabler fungerar inne i "…"
echo 'Enkla citattecken: $namn' . "\\n";      // … men inte i '…'
echo "Nästa nivå: " . ($nivå + 1) . "\\n";    // . sätter ihop
```

- Variabler börjar med `$`.
- Varje rad slutar med `;`.
- `"\\n"` = ny rad (på en hemsida används `<br>` eller nya taggar i stället).
""", "tasks": [
 T("php-grunder-1", 1, "Hej", 'Sätt $namn = "Kaytho" och skriv ut: Hej Kaytho!',
   '<?php\n$namn = "Kaytho";\necho "Hej $namn!\\n";', {"expect": "Hej Kaytho!"},
   ['echo "Hej $namn!";', "Glöm inte $ och ;"], '<?php\n$namn = "Kaytho";\n'),
 T("php-grunder-2", 2, "Pilar", "Med $pilar = 6 och $serier = 12: skriv ut Totalt 72 pilar",
   '<?php\n$pilar = 6;\n$serier = 12;\necho "Totalt " . ($pilar * $serier) . " pilar\\n";', {"expect": "Totalt 72 pilar"},
   ["Räkna inom parentes och sätt ihop med .", 'echo "Totalt " . ($pilar * $serier) . " pilar";']),
]})
P.append({"id": "php-villkor", "title": "PHP: villkor och loopar", "requires": ["php-grunder"],
 "summary": "`if () {} elseif () {} else {}`; `===`; `for ($i = 1; $i <= 3; $i++)`; `foreach ($lista as $x)`; `while`.",
 "lesson_md": """
# PHP: villkor och loopar

```php
<?php
$poang = 612;
if ($poang >= 600) {
    echo "Bra!\\n";
} elseif ($poang >= 500) {
    echo "Okej\\n";
} else {
    echo "Träna mer\\n";
}

for ($i = 1; $i <= 3; $i++) {
    echo "Serie $i\\n";
}
```

Jämför med `===` (samma värde **och** typ) – `==` gör om typer och kan överraska.
""", "tasks": [
 T("php-villkor-1", 1, "Serier", "Skriv ut Serie 1 till Serie 3 med en for-loop.",
   '<?php\nfor ($i = 1; $i <= 3; $i++) {\n    echo "Serie $i\\n";\n}', {"expect": "Serie 1\nSerie 2\nSerie 3"},
   ["for ($i = 1; $i <= 3; $i++) { … }", 'echo "Serie $i\\n";']),
 T("php-villkor-2", 2, "Godkänd", "Med $poang = 480: skriv ut Godkänd om minst 500, annars Underkänd.",
   '<?php\n$poang = 480;\nif ($poang >= 500) {\n    echo "Godkänd\\n";\n} else {\n    echo "Underkänd\\n";\n}', {"expect": "Underkänd"},
   ["if ($poang >= 500) { … } else { … }", "Glöm inte $ framför variabeln."], "<?php\n$poang = 480;\n"),
]})
P.append({"id": "php-arrayer", "title": "PHP: arrayer", "requires": ["php-villkor"],
 "summary": "`[\"a\", \"b\"]`, `$a[] = x`, `count()`; nycklar `[\"namn\" => \"Bo\"]`; `foreach ($a as $k => $v)`; `sort`/`rsort`/`usort`; `implode`.",
 "lesson_md": """
# PHP: arrayer

```php
<?php
$raid = ["Kaytho", "Bo"];
$raid[] = "Cia";                       // lägg till sist
echo count($raid) . "\\n";             // 3

$skytt = ["namn" => "Bo", "poang" => 655];
echo $skytt["namn"] . "\\n";

foreach ($skytt as $nyckel => $värde) {
    echo "$nyckel: $värde\\n";
}
echo implode(", ", $raid) . "\\n";     // Kaytho, Bo, Cia
```

Sortera: `sort($a)` / `rsort($a)` (störst först), egen ordning med
`usort($a, fn($x, $y) => $y["poang"] <=> $x["poang"])`.
""", "tasks": [
 T("php-arrayer-1", 2, "Resultatlista", 'Med $skyttar = [["namn" => "Anna", "poang" => 612], ["namn" => "Bo", "poang" => 655]]: sortera högst först och skriv ut "Bo 655" och "Anna 612" på var sin rad.',
   '<?php\n$skyttar = [["namn" => "Anna", "poang" => 612], ["namn" => "Bo", "poang" => 655]];\nusort($skyttar, fn($a, $b) => $b["poang"] <=> $a["poang"]);\nforeach ($skyttar as $s) {\n    echo $s["namn"] . " " . $s["poang"] . "\\n";\n}',
   {"expect": "Bo 655\nAnna 612"}, ['usort($skyttar, fn($a, $b) => $b["poang"] <=> $a["poang"]);', "foreach ($skyttar as $s) { echo … }"],
   '<?php\n$skyttar = [["namn" => "Anna", "poang" => 612], ["namn" => "Bo", "poang" => 655]];\n'),
]})
P.append({"id": "php-funktioner", "title": "PHP: funktioner", "requires": ["php-arrayer"],
 "summary": "`function namn(int $a): int { return …; }`; typer på parametrar och svar; standardvärden.",
 "lesson_md": """
# PHP: funktioner

```php
<?php
function snitt(array $poang): float {
    return array_sum($poang) / count($poang);
}
echo snitt([8, 9, 10, 9]) . "\\n";     // 9
```

Skriv gärna **typer** (`int`, `float`, `string`, `array`, `bool`) – då säger PHP till direkt när fel
sorts värde skickas in. `declare(strict_types=1);` överst gör kontrollen ännu noggrannare.
""", "tasks": [
 T("php-funktioner-1", 2, "Totalpoäng", "Skriv function total(array $serier): int som returnerar summan, och skriv ut total([54, 52, 57]).",
   '<?php\nfunction total(array $serier): int {\n    return array_sum($serier);\n}\necho total([54, 52, 57]) . "\\n";', {"expect": "163"},
   ["array_sum() summerar.", "echo total([54, 52, 57]);"]),
]})
P.append({"id": "php-formular", "title": "PHP: ta emot formulär", "requires": ["php-funktioner", "html-formular"],
 "summary": "`$_POST[\"namn\"] ?? \"\"`, `trim()`, kontrollera alltid på servern; skriv ut med `htmlspecialchars()`; `$_SERVER[\"REQUEST_METHOD\"] === \"POST\"`.",
 "lesson_md": """
# PHP: ta emot formulär

Det formuläret skickar finns i `$_POST` (eller `$_GET` för sökningar i adressen):

```php
<?php
if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $namn = trim($_POST["namn"] ?? "");
    if ($namn === "") {
        echo "Skriv ditt namn\\n";
    } else {
        echo "Tack " . htmlspecialchars($namn) . "!\\n";
    }
}
```

- `?? ""` ger ett standardvärde om fältet saknas.
- **Lita aldrig på det som skickas in** – kontrollera längd, format, tillåtna värden.
- Allt som skrivs tillbaka till sidan går genom `htmlspecialchars()` (mer i spåret Säkerhet).

Här i lärläget fyller vi `$_POST` själva överst i koden, som om formuläret skickats.
""", "tasks": [
 T("php-formular-1", 2, "Anmälan", 'Överst finns $_SERVER["REQUEST_METHOD"] = "POST" och $_POST = ["namn" => "  Bo ", "roll" => "Tank"]. Skriv ut "Bo anmäld som Tank" (namnet utan mellanslag, båda genom htmlspecialchars), eller "Fel roll" om rollen inte är Tank, Healer eller DPS.',
   '<?php\n$_SERVER["REQUEST_METHOD"] = "POST";\n$_POST = ["namn" => "  Bo ", "roll" => "Tank"];\n\n$namn = trim($_POST["namn"] ?? "");\n$roll = $_POST["roll"] ?? "";\nif (!in_array($roll, ["Tank", "Healer", "DPS"], true)) {\n    echo "Fel roll\\n";\n} else {\n    echo htmlspecialchars($namn) . " anmäld som " . htmlspecialchars($roll) . "\\n";\n}',
   {"type": "script", "script": "check_formular.py"},
   ["trim() tar bort mellanslagen; in_array($roll, [\"Tank\", \"Healer\", \"DPS\"], true) kollar rollen.", "echo htmlspecialchars($namn) . \" anmäld som \" . htmlspecialchars($roll);"],
   '<?php\n$_SERVER["REQUEST_METHOD"] = "POST";\n$_POST = ["namn" => "  Bo ", "roll" => "Tank"];\n\n'),
]})
P.append({"id": "php-pdo", "title": "PHP: databaser med PDO", "requires": ["php-formular", "sql-select"],
 "summary": "`new PDO($dsn, $user, $pass, [ERRMODE_EXCEPTION])`; `$db->query(\"SELECT …\")->fetchAll(PDO::FETCH_ASSOC)`; med användardata: alltid `prepare` + `execute` (spåret Säkerhet).",
 "lesson_md": """
# PHP: databaser med PDO

**PDO** är PHP:s sätt att prata med databaser (MariaDB/MySQL, SQLite …):

```php
<?php
$db = new PDO("mysql:host=localhost;dbname=ianseo", "ianseo", "ianseo",
              [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
foreach ($db->query("SELECT namn, poang FROM skyttar ORDER BY poang DESC") as $rad) {
    echo $rad["namn"] . " " . $rad["poang"] . "\\n";
}
```

Här i lärläget används SQLite: `new PDO("sqlite::memory:")` (en databas i minnet) – SQL:en är
densamma. **Så fort något användaren skrivit ska in i frågan: `prepare` + `execute`**, aldrig att
sätta ihop strängar (se Säkerhet).
""", "tasks": [
 T("php-pdo-1", 2, "Topplistan", "Koden skapar en SQLite-databas med tabellen skyttar. Hämta namn och poang för alla, högst först, och skriv ut \"namn poang\" per rad.",
   '<?php\n$db = new PDO("sqlite::memory:", null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);\n$db->exec(file_get_contents("setup.sql"));\n\nforeach ($db->query("SELECT namn, poang FROM skyttar ORDER BY poang DESC") as $rad) {\n    echo $rad["namn"] . " " . $rad["poang"] . "\\n";\n}',
   {"expect": "Bo 655\nAnna 612\nDan 601\nCia 590"}, ['$db->query("SELECT namn, poang FROM skyttar ORDER BY poang DESC")', 'foreach (… as $rad) { echo $rad["namn"] . " " . $rad["poang"] . "\\n"; }'],
   '<?php\n$db = new PDO("sqlite::memory:", null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);\n$db->exec(file_get_contents("setup.sql"));\n\n', files={"setup.sql": SKYTTAR}),
]})
write_track("php", P)

S = []
S.append({"id": "sql-select", "title": "Hämta data med SELECT", "requires": [],
 "summary": "`SELECT kolumner FROM tabell ORDER BY kolumn DESC LIMIT n;`, `*` = alla kolumner.",
 "lesson_md": """
# Hämta data med SELECT

En databas har **tabeller** med rader och kolumner – som ett kalkylark.

```sql
SELECT namn, poang FROM skyttar;
SELECT * FROM skyttar ORDER BY poang DESC LIMIT 3;
```

- `*` = alla kolumner (bra när man tittar, men skriv ut kolumnerna i riktig kod).
- `ORDER BY poang DESC` = högst först (`ASC` = lägst först).
- `LIMIT 3` = bara tre rader. Avsluta med `;`.

Här i lärläget används SQLite – samma SQL som MariaDB/MySQL (Ianseo) för allt det här.
""", "tasks": [
 T("sql-select-1", 1, "Alla bågskyttar", "Hämta namn och poang för alla i tabellen skyttar, med högst poäng först.",
   "SELECT namn, poang FROM skyttar ORDER BY poang DESC;", {"expect": "namn | poang\nBo | 655\nAnna | 612\nDan | 601\nCia | 590"},
   ["SELECT namn, poang FROM skyttar …", "ORDER BY poang DESC sorterar högst först."], "SELECT ", files={"setup.sql": SKYTTAR}),
 T("sql-select-2", 2, "Pallen", "Hämta bara namnen på de tre bästa, högst först.",
   "SELECT namn FROM skyttar ORDER BY poang DESC LIMIT 3;", {"expect": "namn\nBo\nAnna\nDan"},
   ["LIMIT 3 ger tre rader.", "SELECT namn FROM skyttar ORDER BY poang DESC LIMIT 3;"], files={"setup.sql": SKYTTAR}),
]})
S.append({"id": "sql-where", "title": "Välja rader med WHERE", "requires": ["sql-select"],
 "summary": "`WHERE poang > 600 AND klubb = 'Lund'`; `OR`, `NOT`, `IN (…)`, `BETWEEN`, `LIKE 'A%'`, `IS NULL`.",
 "lesson_md": """
# Välja rader med WHERE

```sql
SELECT namn FROM skyttar WHERE klubb = 'Lund';
SELECT namn FROM skyttar WHERE poang > 600 AND klubb = 'Malmö';
SELECT namn FROM skyttar WHERE namn LIKE 'A%';      -- börjar på A
SELECT namn FROM skyttar WHERE klubb IN ('Lund', 'Ystad');
```

Text står inom **enkla** citattecken. `%` i `LIKE` betyder "vad som helst". Tom kolumn testas med
`IS NULL` (inte `= NULL`).
""", "tasks": [
 T("sql-where-1", 1, "En klubb", "Hämta namnen på skyttarna från Lund, i bokstavsordning.",
   "SELECT namn FROM skyttar WHERE klubb = 'Lund' ORDER BY namn;", {"expect": "namn\nAnna\nCia"},
   ["WHERE klubb = 'Lund'", "ORDER BY namn ger bokstavsordning."], files={"setup.sql": SKYTTAR}),
 T("sql-where-2", 2, "Malmö över 600", "Hämta namn och poang för dem från Malmö som har mer än 600 poäng, högst först.",
   "SELECT namn, poang FROM skyttar WHERE klubb = 'Malmö' AND poang > 600 ORDER BY poang DESC;", {"expect": "namn | poang\nBo | 655\nDan | 601"},
   ["Två villkor binds ihop med AND.", "WHERE klubb = 'Malmö' AND poang > 600"], files={"setup.sql": SKYTTAR}),
]})
S.append({"id": "sql-andra", "title": "Ändra data: INSERT, UPDATE, DELETE", "requires": ["sql-where"],
 "summary": "`INSERT INTO t (a, b) VALUES (…);` `UPDATE t SET a = … WHERE …;` `DELETE FROM t WHERE …;` – glöm aldrig WHERE.",
 "lesson_md": """
# Ändra data: INSERT, UPDATE, DELETE

```sql
INSERT INTO skyttar (namn, klubb, poang) VALUES ('Eva', 'Ystad', 640);
UPDATE skyttar SET poang = 660 WHERE namn = 'Bo';
DELETE FROM skyttar WHERE namn = 'Cia';
```

**Varning:** `UPDATE` och `DELETE` utan `WHERE` ändrar/tar bort **alla** rader. Gör gärna en
`SELECT` med samma `WHERE` först och se vilka rader det gäller – och ha en backup (Ianseo i
GOBLINCAKES gör backup var 30:e minut).
""", "tasks": [
 T("sql-andra-1", 2, "Ny skytt och rättning", "Lägg till Eva från Ystad med 640 poäng, ändra Bos poäng till 660, ta bort Cia, och visa sedan namn och poang för alla, högst först.",
   "INSERT INTO skyttar (namn, klubb, poang) VALUES ('Eva', 'Ystad', 640);\nUPDATE skyttar SET poang = 660 WHERE namn = 'Bo';\nDELETE FROM skyttar WHERE namn = 'Cia';\nSELECT namn, poang FROM skyttar ORDER BY poang DESC;",
   {"expect": "namn | poang\nBo | 660\nEva | 640\nAnna | 612\nDan | 601"},
   ["En sats per rad, var och en avslutad med ;", "UPDATE … SET poang = 660 WHERE namn = 'Bo';"], files={"setup.sql": SKYTTAR}),
]})
S.append({"id": "sql-gruppera", "title": "Räkna och gruppera", "requires": ["sql-andra"],
 "summary": "`COUNT(*)`, `SUM`, `AVG`, `MAX`, `MIN`; `GROUP BY kolumn`; `HAVING` = WHERE för grupper; `AS` byter namn.",
 "lesson_md": """
# Räkna och gruppera

```sql
SELECT COUNT(*) AS antal FROM skyttar;
SELECT klubb, COUNT(*) AS antal, AVG(poang) AS snitt
FROM skyttar
GROUP BY klubb
ORDER BY snitt DESC;
```

`GROUP BY` samlar raderna per värde – en rad per klubb. `HAVING antal > 1` väljer bland
grupperna (WHERE väljer bland raderna innan de grupperas).
""", "tasks": [
 T("sql-gruppera-1", 2, "Per klubb", "Visa varje klubb med antal skyttar och högsta poäng (kolumnerna klubb, antal, basta), i bokstavsordning.",
   "SELECT klubb, COUNT(*) AS antal, MAX(poang) AS basta FROM skyttar GROUP BY klubb ORDER BY klubb;",
   {"expect": "klubb | antal | basta\nLund | 2 | 612\nMalmö | 2 | 655"},
   ["GROUP BY klubb ger en rad per klubb.", "COUNT(*) AS antal, MAX(poang) AS basta"], files={"setup.sql": SKYTTAR}),
]})
S.append({"id": "sql-join", "title": "Flera tabeller: JOIN", "requires": ["sql-gruppera"],
 "summary": "Data delas upp i tabeller kopplade med id; `JOIN t2 ON t1.x = t2.id`; `LEFT JOIN` behåller rader utan träff.",
 "lesson_md": """
# Flera tabeller: JOIN

I riktiga databaser (som Ianseos) delas datan upp: en tabell med skyttar, en med klubbar –
kopplade med ett **id**:

```sql
SELECT s.namn, k.namn AS klubb
FROM skyttar s
JOIN klubbar k ON s.klubb_id = k.id
ORDER BY s.namn;
```

`s` och `k` är korta namn på tabellerna. `JOIN` tar bara rader som har en träff i båda;
`LEFT JOIN` behåller alla från den vänstra (med NULL där träff saknas).
""", "tasks": [
 T("sql-join-1", 2, "Skytt och klubb", "Tabellerna deltagare (namn, klubb_id) och klubbar (id, namn). Visa varje deltagares namn och klubbens namn (kolumnerna namn och klubb) i bokstavsordning efter deltagaren.",
   "SELECT d.namn, k.namn AS klubb FROM deltagare d JOIN klubbar k ON d.klubb_id = k.id ORDER BY d.namn;",
   {"expect": "namn | klubb\nAnna | BK Lund\nBo | Malmö BS"},
   ["JOIN klubbar k ON d.klubb_id = k.id", "SELECT d.namn, k.namn AS klubb …"],
   files={"setup.sql": "CREATE TABLE klubbar (id INTEGER PRIMARY KEY, namn TEXT);\nCREATE TABLE deltagare (id INTEGER PRIMARY KEY, namn TEXT, klubb_id INTEGER);\nINSERT INTO klubbar VALUES (1, 'BK Lund'), (2, 'Malmö BS');\nINSERT INTO deltagare (namn, klubb_id) VALUES ('Bo', 2), ('Anna', 1);\n"}),
]})
S.append({"id": "sql-tabeller", "title": "Skapa tabeller", "requires": ["sql-join"],
 "summary": "`CREATE TABLE t (id INTEGER PRIMARY KEY, namn TEXT NOT NULL, … )`; `UNIQUE`, `DEFAULT`, `FOREIGN KEY`; en sak per tabell.",
 "lesson_md": """
# Skapa tabeller

```sql
CREATE TABLE anvandare (
  id INTEGER PRIMARY KEY,         -- unikt nummer, sätts själv
  namn TEXT NOT NULL UNIQUE,      -- måste finnas, inga dubbletter
  losenord_hash TEXT NOT NULL,    -- aldrig själva lösenordet!
  skapad TEXT DEFAULT CURRENT_TIMESTAMP
);
```

- En tabell per sorts sak (användare, anmälningar, raider) – koppla med id.
- `NOT NULL`, `UNIQUE` och `DEFAULT` låter databasen själv vakta reglerna.
- I MariaDB heter typerna lite annorlunda (`INT AUTO_INCREMENT`, `VARCHAR(100)`) – idén är densamma.
""", "tasks": [
 T("sql-tabeller-1", 3, "Anmälningar", "Skapa tabellen anmalan med id (INTEGER PRIMARY KEY), namn (TEXT NOT NULL) och roll (TEXT NOT NULL, standard 'DPS'). Lägg in Kaytho med rollen Healer och Bo utan roll, och visa namn och roll i id-ordning.",
   "CREATE TABLE anmalan (id INTEGER PRIMARY KEY, namn TEXT NOT NULL, roll TEXT NOT NULL DEFAULT 'DPS');\nINSERT INTO anmalan (namn, roll) VALUES ('Kaytho', 'Healer');\nINSERT INTO anmalan (namn) VALUES ('Bo');\nSELECT namn, roll FROM anmalan ORDER BY id;",
   {"expect": "namn | roll\nKaytho | Healer\nBo | DPS"},
   ["roll TEXT NOT NULL DEFAULT 'DPS'", "Utelämna roll i INSERT för Bo, så tar den standardvärdet."]),
]})
write_track("sql", S)

K = []
K.append({"id": "sak-sqlinjektion", "title": "SQL-injektion och prepared statements", "requires": ["php-pdo"], "locked": True,
 "summary": "Sätt **aldrig** ihop SQL med användarens text; `$st = $db->prepare(\"… WHERE namn = ?\"); $st->execute([$namn]);`.",
 "lesson_md": """
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
""", "tasks": [
 T("sak-sqlinjektion-1", 2, "Säker sökning", 'Variabeln $sok kommer från användaren och är just nu en attack: "x\' OR \'1\'=\'1". Skriv om sökningen med prepare och execute så att den skriver ut "Inga träffar" (attacken fungerar inte). Med $sok = "Bo" ska den skriva "Bo 655".',
   '<?php\n$db = new PDO("sqlite::memory:", null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);\n$db->exec(file_get_contents("setup.sql"));\n$sok = "x\' OR \'1\'=\'1";\n\n$st = $db->prepare("SELECT namn, poang FROM skyttar WHERE namn = ?");\n$st->execute([$sok]);\n$rader = $st->fetchAll(PDO::FETCH_ASSOC);\nif (!$rader) {\n    echo "Inga träffar\\n";\n}\nforeach ($rader as $r) {\n    echo $r["namn"] . " " . $r["poang"] . "\\n";\n}',
   {"type": "script", "script": "check_injektion.py"},
   ['$st = $db->prepare("SELECT namn, poang FROM skyttar WHERE namn = ?");', "$st->execute([$sok]); och sedan $st->fetchAll(PDO::FETCH_ASSOC)"],
   '<?php\n$db = new PDO("sqlite::memory:", null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);\n$db->exec(file_get_contents("setup.sql"));\n$sok = "x\' OR \'1\'=\'1";\n\n$rader = $db->query("SELECT namn, poang FROM skyttar WHERE namn = \'$sok\'")->fetchAll(PDO::FETCH_ASSOC);\nif (!$rader) {\n    echo "Inga träffar\\n";\n}\nforeach ($rader as $r) {\n    echo $r["namn"] . " " . $r["poang"] . "\\n";\n}\n',
   files={"setup.sql": SKYTTAR}),
]})
K.append({"id": "sak-losenord", "title": "Lösenord: hasha, spara aldrig", "requires": ["sak-sqlinjektion"], "locked": True,
 "summary": "`password_hash($lösen, PASSWORD_DEFAULT)` när kontot skapas; `password_verify($lösen, $hash)` vid inloggning; aldrig md5/sha1, aldrig klartext.",
 "lesson_md": """
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
""", "tasks": [
 T("sak-losenord-1", 2, "Hasha och kontrollera", 'Skriv function skapa(string $losen): string som returnerar en hash, och function kolla(string $losen, string $hash): bool. Skriv sedan ut kolla("hunter2", skapa("hunter2")) och kolla("fel", skapa("hunter2")) som ja/nej: ja och nej.',
   '<?php\nfunction skapa(string $losen): string {\n    return password_hash($losen, PASSWORD_DEFAULT);\n}\nfunction kolla(string $losen, string $hash): bool {\n    return password_verify($losen, $hash);\n}\necho (kolla("hunter2", skapa("hunter2")) ? "ja" : "nej") . "\\n";\necho (kolla("fel", skapa("hunter2")) ? "ja" : "nej") . "\\n";',
   {"type": "script", "script": "check_losenord.py"},
   ["password_hash($losen, PASSWORD_DEFAULT)", "password_verify($losen, $hash)"]),
]})
K.append({"id": "sak-xss", "title": "XSS: skriv ut användarens text säkert", "requires": ["sak-losenord"], "locked": True,
 "summary": "Allt från användare som skrivs ut i HTML: `htmlspecialchars($text, ENT_QUOTES, 'UTF-8')`; i JavaScript `textContent`, inte `innerHTML`.",
 "lesson_md": """
# XSS: skriv ut användarens text säkert

Om någon skriver `<script>stjäl(document.cookie)</script>` som sitt namn, och sidan skriver ut
namnet som det är, så **körs** skriptet hos alla som tittar. Det kallas **XSS** (cross-site scripting).

Skydd: gör om specialtecknen till ofarlig text när du skriver ut:

```php
echo "<p>Anmäld: " . htmlspecialchars($namn, ENT_QUOTES, "UTF-8") . "</p>";
```

`<` blir `&lt;` och visas som tecknet i stället för att bli en tagg. Gör det **vid utskriften** –
varje gång, för allt som kommer utifrån (formulär, databasen, adressen). I JavaScript:
`element.textContent = text` (aldrig `innerHTML` med användarens text).
""", "tasks": [
 T("sak-xss-1", 2, "Ofarligt namn", 'Namnet $namn = "<script>alert(1)</script>" kommer från ett formulär. Skriv ut <p>Anmäld: …</p> så att taggen visas som text (med htmlspecialchars och ENT_QUOTES).',
   '<?php\n$namn = "<script>alert(1)</script>";\necho "<p>Anmäld: " . htmlspecialchars($namn, ENT_QUOTES, "UTF-8") . "</p>\\n";',
   {"expect": "<p>Anmäld: &lt;script&gt;alert(1)&lt;/script&gt;</p>"},
   ["htmlspecialchars($namn, ENT_QUOTES, \"UTF-8\")", "Lägg den runt $namn inne i echo."],
   '<?php\n$namn = "<script>alert(1)</script>";\necho "<p>Anmäld: " . $namn . "</p>\\n";\n'),
]})
K.append({"id": "sak-sessioner", "title": "Inloggning med sessioner", "requires": ["sak-xss"], "locked": True,
 "summary": "`session_start()`; efter lyckad inloggning `session_regenerate_id(true)` + `$_SESSION[\"anvandare\"]`; logga ut: `session_destroy()`; cookie `httponly`, `secure`, `samesite`.",
 "lesson_md": """
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
""", "tasks": [
 T("sak-sessioner-1", 3, "Logga in rätt", 'Skriv function logga_in(string $namn, string $losen, string $hash): bool som kontrollerar lösenordet med password_verify och, om det stämmer, byter sessionsnyckel med session_regenerate_id(true) och sparar namnet i $_SESSION["anvandare"]. Returnera true/false.',
   '<?php\nfunction logga_in(string $namn, string $losen, string $hash): bool {\n    if (!password_verify($losen, $hash)) {\n        return false;\n    }\n    session_regenerate_id(true);\n    $_SESSION["anvandare"] = $namn;\n    return true;\n}',
   {"type": "script", "script": "check_sessioner.py"},
   ["Börja med if (!password_verify($losen, $hash)) { return false; }", 'session_regenerate_id(true); $_SESSION["anvandare"] = $namn; return true;'],
   '<?php\nfunction logga_in(string $namn, string $losen, string $hash): bool {\n    return false;\n}\n'),
]})
write_track("sakerhet", K)

I = []
IANSEO = ("CREATE TABLE Countries (CoId INTEGER PRIMARY KEY, CoCode TEXT, CoName TEXT);\n"
          "CREATE TABLE Entries (EnId INTEGER PRIMARY KEY, EnName TEXT, EnFirstName TEXT, EnCountry INTEGER, EnDivision TEXT, EnClass TEXT);\n"
          "CREATE TABLE Qualifications (QuId INTEGER PRIMARY KEY, QuScore INTEGER, QuGold INTEGER, QuXnine INTEGER);\n"
          "INSERT INTO Countries VALUES (1, 'BKL', 'BK Lund'), (2, 'MBS', 'Malmö BS');\n"
          "INSERT INTO Entries VALUES (1, 'Andersson', 'Anna', 1, 'R', 'D'), (2, 'Berg', 'Bo', 2, 'R', 'H'), (3, 'Carlsson', 'Cia', 1, 'C', 'D'), (4, 'Dahl', 'Dan', 2, 'R', 'H');\n"
          "INSERT INTO Qualifications VALUES (1, 612, 18, 6), (2, 655, 25, 9), (3, 655, 25, 11), (4, 601, 15, 4);\n")
I.append({"id": "ianseo-struktur", "title": "Hur Ianseo är byggt", "requires": ["php-pdo", "sql-join"],
 "summary": "PHP + MariaDB; i GOBLINCAKES i containern `ianseo-web` (`/opt/ianseo`), databasen ianseo; tabeller med prefix: `Entries` (En…), `Countries` (Co…), `Qualifications` (Qu…), `Tournament` (To…); jobba alltid mot en kopia.",
 "lesson_md": """
# Hur Ianseo är byggt

Ianseo är en PHP-app med en MariaDB-databas. I GOBLINCAKES kör den i containrar
(`ianseo-web` med filerna i `/opt/ianseo`, `ianseo-db` med databasen `ianseo`).

Ianseos tabeller har ett **prefix per tabell** på kolumnerna, t.ex.:

| Tabell | Innehåll | Några kolumner |
|---|---|---|
| `Tournament` | tävlingar | `ToId`, `ToCode`, `ToName` |
| `Entries` | deltagare | `EnId`, `EnName`, `EnFirstName`, `EnCountry`, `EnDivision`, `EnClass`, `EnTournament` |
| `Countries` | klubbar/länder | `CoId`, `CoCode`, `CoName` |
| `Qualifications` | kvalresultat (samma id som deltagaren) | `QuId`, `QuScore`, `QuGold`, `QuXnine` |

Lika poäng avgörs av antal 10:or (`QuGold`) och sedan X/9:or (`QuXnine`).

**Viktigt:** pröva aldrig ny kod mot en riktig tävling. Ta en kopia av databasen (GOBLINCAKES gör
backup i `~/Ianseo/Backup`) – här i lärläget används förenklade kopior av tabellerna i SQLite.
Kolla kolumnerna i din egen Ianseo (`SHOW COLUMNS FROM Entries;`) – de kan skilja mellan versioner.
""", "tasks": [
 T("ianseo-struktur-1", 2, "Kvallistan", "Skriv PHP som hämtar förnamn, efternamn och poäng och skriver ut kvallistan högst först – vid lika poäng avgör flest 10:or och sedan flest X: \"Cia Carlsson 655\" per rad.",
   '<?php\n$db = new PDO("sqlite::memory:", null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);\n$db->exec(file_get_contents("setup.sql"));\n\n$sql = "SELECT EnFirstName, EnName, QuScore FROM Entries JOIN Qualifications ON QuId = EnId ORDER BY QuScore DESC, QuGold DESC, QuXnine DESC";\nforeach ($db->query($sql) as $r) {\n    echo $r["EnFirstName"] . " " . $r["EnName"] . " " . $r["QuScore"] . "\\n";\n}',
   {"expect": "Cia Carlsson 655\nBo Berg 655\nAnna Andersson 612\nDan Dahl 601"},
   ["JOIN Qualifications ON QuId = EnId", "ORDER BY QuScore DESC, QuGold DESC, QuXnine DESC"],
   '<?php\n$db = new PDO("sqlite::memory:", null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);\n$db->exec(file_get_contents("setup.sql"));\n\n', files={"setup.sql": IANSEO}),
]})
I.append({"id": "ianseo-export", "title": "En egen export", "requires": ["ianseo-struktur"],
 "summary": "Gör om Ianseo-data till CSV (`fputcsv`) eller HTML; filtrera på klass/division med prepared statements; `header('Content-Type: text/csv')` på riktigt.",
 "lesson_md": """
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
""", "tasks": [
 T("ianseo-export-1", 3, "Recurve till CSV", 'Exportera division "R" som CSV med rubrikraden Namn,Klubb,Poäng och sedan en rad per skytt (förnamn + efternamn, klubbens namn, poäng), högst först med samma tie-break. Använd prepare för divisionen och fputcsv.',
   '<?php\n$db = new PDO("sqlite::memory:", null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);\n$db->exec(file_get_contents("setup.sql"));\n$division = "R";\n\n$st = $db->prepare("SELECT EnFirstName, EnName, CoName, QuScore FROM Entries JOIN Qualifications ON QuId = EnId JOIN Countries ON CoId = EnCountry WHERE EnDivision = ? ORDER BY QuScore DESC, QuGold DESC, QuXnine DESC");\n$st->execute([$division]);\n$ut = fopen("php://output", "w");\nfputcsv($ut, ["Namn", "Klubb", "Poäng"]);\nforeach ($st as $r) {\n    fputcsv($ut, [$r["EnFirstName"] . " " . $r["EnName"], $r["CoName"], $r["QuScore"]]);\n}',
   {"expect": "Namn,Klubb,Poäng\n\"Bo Berg\",\"Malmö BS\",655\n\"Anna Andersson\",\"BK Lund\",612\n\"Dan Dahl\",\"Malmö BS\",601"},
   ["JOIN Countries ON CoId = EnCountry och WHERE EnDivision = ? med prepare.", 'fputcsv($ut, [… , $r["CoName"], $r["QuScore"]]);'],
   '<?php\n$db = new PDO("sqlite::memory:", null, null, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);\n$db->exec(file_get_contents("setup.sql"));\n$division = "R";\n\n', files={"setup.sql": IANSEO}),
]})
write_track("ianseo", I)
