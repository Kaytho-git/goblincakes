from lib import write_track, T
PAGE = '<!doctype html>\n<html lang="sv">\n<head>\n  <meta charset="utf-8">\n  <title>Min sida</title>\n</head>\n<body>\n\n</body>\n</html>\n'
def page(body, head=""):
    return f'<!doctype html>\n<html lang="sv">\n<head>\n  <meta charset="utf-8">\n  <title>Min sida</title>\n{head}</head>\n<body>\n{body}\n</body>\n</html>\n'
H = []
H.append({"id": "html-forsta", "title": "Din första sida", "requires": [],
 "summary": "`<h1>`–`<h6>` rubriker, `<p>` stycke, `<strong>`/`<em>`; det synliga i `<body>`, info i `<head>`; `<meta charset=\"utf-8\">`.",
 "lesson_md": """
# Din första sida

En hemsida är en textfil med **taggar** som säger vad varje del är:

```html
<h1>Rubrik</h1>
<p>Ett stycke text med <strong>fet</strong> och <em>kursiv</em> text.</p>
```

De flesta taggar har en start `<p>` och ett slut `</p>`. Det som syns står mellan `<body>` och
`</body>`; `<head>` innehåller information om sidan, som titeln i fliken och teckenkodningen
(`utf-8`, så att å, ä och ö blir rätt).

Tryck **Förhandsvisa** för att se sidan i webbläsaren.
""", "tasks": [
 T("html-forsta-1", 1, "En sida om dig", "Gör en sida med en rubrik (h1) med ditt namn och ett stycke (p) om vad du gillar.",
   page("  <h1>Kaytho</h1>\n  <p>Jag gillar bågskytte och WoW.</p>"), {"has": ["<h1", "</h1>", "<p", "</p>"]},
   ["En rubrik skrivs <h1>Text</h1>.", "Lägg <h1>…</h1> och <p>…</p> mellan <body> och </body>."], PAGE),
 T("html-forsta-2", 2, "Rubriknivåer", "Gör en sida med en h1 (Raidguide), två h2 (Bossar och Tips) och ett stycke under varje h2 där ett ord är fetstilt med strong.",
   page("  <h1>Raidguide</h1>\n  <h2>Bossar</h2>\n  <p>Den första är <strong>svår</strong>.</p>\n  <h2>Tips</h2>\n  <p>Stå inte i elden.</p>"),
   {"regex": [r"<h1[^>]*>\s*Raidguide", r"<h2[^>]*>\s*Bossar", r"<h2[^>]*>\s*Tips", r"<strong>"]},
   ["h2 är en underrubrik.", "<strong>ord</strong> gör ordet fetstilt."], PAGE),
]})
H.append({"id": "html-lankar", "title": "Länkar och bilder", "requires": ["html-forsta"],
 "summary": "`<a href=\"url\">text</a>` (`target=\"_blank\"` = ny flik), `<img src=\"bild.png\" alt=\"beskrivning\">` – alt är obligatoriskt.",
 "lesson_md": """
# Länkar och bilder

```html
<a href="https://ianseo.net">Ianseo</a>
<a href="om.html">Om mig</a>                       <!-- en annan sida bredvid -->
<img src="goblin.png" alt="En goblin med en cupcake">
```

- `href` = vart länken går. En egen sida bredvid skrivs bara med filnamnet.
- `<img>` har ingen sluttagg. `alt` beskriver bilden för den som inte kan se den (skärmläsare,
  eller när bilden inte laddas) – **skriv alltid alt**.
""", "tasks": [
 T("html-lankar-1", 1, "Länk och bild", "Lägg till en länk till https://worldofwarcraft.blizzard.com med texten WoW, och en bild med src=goblin.png och en alt-text.",
   page('  <a href="https://worldofwarcraft.blizzard.com">WoW</a>\n  <img src="goblin.png" alt="En goblin">'),
   {"regex": [r'<a[^>]+href="https://worldofwarcraft\.blizzard\.com"', r'<img[^>]+src="goblin\.png"', r'<img[^>]+alt="[^"]+"']},
   ['<a href="adress">text</a>', '<img src="goblin.png" alt="beskrivning">'], PAGE),
]})
H.append({"id": "html-listor", "title": "Listor och tabeller", "requires": ["html-lankar"],
 "summary": "`<ul>`/`<ol>` med `<li>`; tabell: `<table>`, `<tr>` rad, `<th>` rubrikcell, `<td>` cell, gärna `<thead>`/`<tbody>`.",
 "lesson_md": """
# Listor och tabeller

```html
<ul>                <!-- punktlista; <ol> = numrerad -->
  <li>Pilbåge</li>
  <li>Pilar</li>
</ul>

<table>
  <thead><tr><th>Namn</th><th>Poäng</th></tr></thead>
  <tbody>
    <tr><td>Bo</td><td>655</td></tr>
  </tbody>
</table>
```

Tabeller är till för **data** (resultatlistor!), inte för att placera ut saker på sidan – det gör
man med CSS.
""", "tasks": [
 T("html-listor-1", 2, "Resultatlista", "Gör en tabell med rubrikerna Namn och Poäng (th) och två rader: Bo 655 och Anna 612.",
   page("  <table>\n    <thead><tr><th>Namn</th><th>Poäng</th></tr></thead>\n    <tbody>\n      <tr><td>Bo</td><td>655</td></tr>\n      <tr><td>Anna</td><td>612</td></tr>\n    </tbody>\n  </table>"),
   {"regex": [r"<table", r"<th[^>]*>\s*Namn", r"<th[^>]*>\s*Poäng", r"<td[^>]*>\s*Bo\s*</td>\s*<td[^>]*>\s*655", r"<td[^>]*>\s*Anna\s*</td>\s*<td[^>]*>\s*612"]},
   ["<tr> är en rad, <th> en rubrikcell, <td> en vanlig cell.", "En rad: <tr><td>Bo</td><td>655</td></tr>"], PAGE),
]})
H.append({"id": "html-formular", "title": "Formulär", "requires": ["html-listor"],
 "summary": "`<form action method=\"post\">`, `<label for>` + `<input id name type required>`, `type=\"email\"`/`password`/`number`, `<select>`, `<button>`.",
 "lesson_md": """
# Formulär

Formulär låter besökaren skicka in något – anmälan, inloggning, sökning:

```html
<form action="anmal.php" method="post">
  <label for="namn">Namn</label>
  <input id="namn" name="namn" type="text" required>

  <label for="klass">Klass</label>
  <select id="klass" name="klass">
    <option>Recurve</option>
    <option>Compound</option>
  </select>

  <button type="submit">Anmäl</button>
</form>
```

- `name` = namnet servern får värdet under (`$_POST["namn"]` i PHP).
- `label for` kopplad till `id` – klicka på texten, så hamnar markören i fältet.
- `type="email"`, `"password"`, `"number"` ger rätt tangentbord och enkel kontroll; `required` = måste fyllas i.
- Kontrollen i webbläsaren är bara en hjälp – **servern måste alltid kontrollera igen**.
""", "tasks": [
 T("html-formular-1", 2, "Raidanmälan", "Gör ett formulär (method post, action anmal.php) med ett obligatoriskt textfält name=namn med label, en select name=roll med Tank, Healer och DPS, och en skicka-knapp.",
   page('  <form action="anmal.php" method="post">\n    <label for="namn">Namn</label>\n    <input id="namn" name="namn" type="text" required>\n    <label for="roll">Roll</label>\n    <select id="roll" name="roll">\n      <option>Tank</option>\n      <option>Healer</option>\n      <option>DPS</option>\n    </select>\n    <button type="submit">Anmäl</button>\n  </form>'),
   {"regex": [r'<form[^>]+method="post"', r'<form[^>]+action="anmal\.php"', r'<label[^>]+for="namn"', r'<input[^>]+name="namn"[^>]*required|<input[^>]+required[^>]*name="namn"',
              r'<select[^>]+name="roll"', r"<option[^>]*>\s*Tank", r"<option[^>]*>\s*Healer", r"<option[^>]*>\s*DPS", r'<button[^>]*type="submit"|<input[^>]+type="submit"']},
   ['<input id="namn" name="namn" type="text" required>', "<select name=\"roll\"> med tre <option>."], PAGE),
]})
H.append({"id": "css-grunder", "title": "CSS: färger och text", "requires": ["html-forsta"],
 "summary": "`<style>` eller `style.css` med `<link rel=\"stylesheet\">`; väljare `h1`, `.klass`, `#id`; `color`, `background`, `font-family`, `font-size`, `margin`, `padding`, `border`.",
 "lesson_md": """
# CSS: färger och text

**CSS** bestämmer hur sidan ser ut. Antingen i `<head>`:

```html
<style>
  body { background: #0E1420; color: #E6ECF5; font-family: sans-serif; }
  h1   { color: #2F6FED; font-size: 2rem; }
  .viktig { font-weight: bold; }
</style>
```

eller i en egen fil `style.css` som kopplas in med `<link rel="stylesheet" href="style.css">`.

- **Väljare:** `h1` (alla h1), `.viktig` (allt med `class="viktig"`), `#meny` (det med `id="meny"`).
- **Lådmodellen:** `padding` = luft innanför kanten, `border` = kanten, `margin` = luft utanför.
- Färger skrivs `#2F6FED`, `rgb(47 111 237)` eller med namn (`red`).
""", "tasks": [
 T("css-grunder-1", 2, "GOBLINCAKES-färger", "Ge sidan mörk bakgrund #0E1420 och ljus text #E6ECF5 (på body), gör h1 blå #2F6FED, och ge ett stycke klassen viktig som blir fetstilt.",
   page('  <h1>GOBLINCAKES</h1>\n  <p class="viktig">Raid i kväll!</p>',
        "  <style>\n    body { background: #0E1420; color: #E6ECF5; }\n    h1 { color: #2F6FED; }\n    .viktig { font-weight: bold; }\n  </style>\n"),
   {"regex": [r"body\s*\{[^}]*background(-color)?\s*:\s*#0e1420", r"body\s*\{[^}]*color\s*:\s*#e6ecf5", r"h1\s*\{[^}]*color\s*:\s*#2f6fed",
              r"\.viktig\s*\{[^}]*font-weight\s*:\s*(bold|[6-9]00)", r'class="viktig"']},
   ["Skriv CSS i <style> i <head>.", ".viktig { font-weight: bold; } och class=\"viktig\" på stycket."], PAGE),
]})
H.append({"id": "css-layout", "title": "CSS: layout med flexbox och grid", "requires": ["css-grunder"],
 "summary": "`display: flex` (+ `gap`, `justify-content`, `align-items`, `flex-wrap`); `display: grid; grid-template-columns: repeat(3, 1fr)`.",
 "lesson_md": """
# CSS: layout med flexbox och grid

**Flexbox** lägger saker i en rad (eller kolumn):

```css
.meny { display: flex; gap: 1rem; justify-content: space-between; align-items: center; }
```

**Grid** gör rutnät:

```css
.kort { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
```

`1fr` = en del av det lediga utrymmet – tre kolumner lika breda. Det här ersätter allt gammalt
fifflande med tabeller och `float`.
""", "tasks": [
 T("css-layout-1", 2, "Meny och kort", "Gör en nav med klassen meny som har display flex och gap, och en div med klassen kort som är ett grid med tre lika breda kolumner.",
   page('  <nav class="meny"><a href="#">Hem</a><a href="#">Raid</a></nav>\n  <div class="kort"><div>1</div><div>2</div><div>3</div></div>',
        "  <style>\n    .meny { display: flex; gap: 1rem; }\n    .kort { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }\n  </style>\n"),
   {"regex": [r"\.meny\s*\{[^}]*display\s*:\s*flex", r"\.meny\s*\{[^}]*gap\s*:", r"\.kort\s*\{[^}]*display\s*:\s*grid",
              r"\.kort\s*\{[^}]*grid-template-columns\s*:\s*(repeat\(\s*3\s*,\s*1fr\s*\)|1fr\s+1fr\s+1fr)", r'class="meny"', r'class="kort"']},
   ["display: flex; gap: 1rem;", "grid-template-columns: repeat(3, 1fr);"], PAGE),
]})
H.append({"id": "css-mobil", "title": "CSS: sidor som fungerar i mobilen", "requires": ["css-layout"],
 "summary": "`<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">`; `@media (max-width: 600px) { … }`; `max-width` + `margin: 0 auto`.",
 "lesson_md": """
# CSS: sidor som fungerar i mobilen

Två saker gör att en sida fungerar på telefonen:

```html
<meta name="viewport" content="width=device-width, initial-scale=1">
```

i `<head>` (annars låtsas telefonen vara en stor skärm), och **media queries** som ändrar
layouten på smala skärmar:

```css
.kort { display: grid; grid-template-columns: repeat(3, 1fr); }
@media (max-width: 600px) {
  .kort { grid-template-columns: 1fr; }
}
```

Bra grund: `main { max-width: 900px; margin: 0 auto; padding: 16px; }` – lagom bred och centrerad.
""", "tasks": [
 T("css-mobil-1", 3, "En kolumn i mobilen", "Lägg till viewport-taggen och en media query som gör .kort till en kolumn när skärmen är högst 600px bred.",
   page('  <div class="kort"><div>1</div><div>2</div><div>3</div></div>',
        '  <meta name="viewport" content="width=device-width, initial-scale=1">\n  <style>\n    .kort { display: grid; grid-template-columns: repeat(3, 1fr); }\n    @media (max-width: 600px) {\n      .kort { grid-template-columns: 1fr; }\n    }\n  </style>\n'),
   {"regex": [r'<meta[^>]+name="viewport"[^>]+width=device-width', r"@media\s*\(\s*max-width\s*:\s*600px\s*\)\s*\{[^@]*\.kort\s*\{[^}]*grid-template-columns\s*:\s*1fr\s*;?\s*\}"]},
   ['<meta name="viewport" content="width=device-width, initial-scale=1">', "@media (max-width: 600px) { .kort { grid-template-columns: 1fr; } }"],
   page('  <div class="kort"><div>1</div><div>2</div><div>3</div></div>', "  <style>\n    .kort { display: grid; grid-template-columns: repeat(3, 1fr); }\n  </style>\n")),
]})
write_track("html", H)

J = []
J.append({"id": "js-grunder", "title": "JavaScript: grunder", "requires": [],
 "summary": "`console.log()`; `const` (ändras inte) / `let`; template literals `` `Hej ${namn}` ``; `===` jämför; `//` kommentar.",
 "lesson_md": """
# JavaScript: grunder

JavaScript gör hemsidor levande – och körs också utanför webbläsaren (Node.js), som här.

```js
const namn = "Kaytho";     // const = ändras inte
let nivå = 79;             // let = kan ändras
nivå = nivå + 1;
console.log(`${namn} är nivå ${nivå}`);
```

- Använd `const` som standard, `let` när värdet ska ändras. (Gamla `var` – undvik.)
- Text med `` ` `` (backticks) kan ha `${variabler}` inuti.
- Jämför med `===` och `!==` (tre tecken) – `==` gör konstiga omvandlingar.
""", "tasks": [
 T("js-grunder-1", 1, "Hej", 'Skapa const namn = "Kaytho" och skriv ut: Hej Kaytho!',
   'const namn = "Kaytho";\nconsole.log(`Hej ${namn}!`);', {"expect": "Hej Kaytho!"},
   ["console.log skriver ut.", "console.log(`Hej ${namn}!`);"], 'const namn = "Kaytho";\n'),
 T("js-grunder-2", 2, "Räkna", "Med let poang = 600, lägg till 55 och skriv ut: Poäng: 655",
   'let poang = 600;\npoang += 55;\nconsole.log(`Poäng: ${poang}`);', {"expect": "Poäng: 655"}, ["poang += 55", "console.log(`Poäng: ${poang}`);"]),
]})
J.append({"id": "js-villkor", "title": "JavaScript: villkor och loopar", "requires": ["js-grunder"],
 "summary": "`if (x) { } else if { } else { }`; `&&`, `||`, `!`; `for (let i = 0; i < 5; i++)`; `for (const x of lista)`; `while`.",
 "lesson_md": """
# JavaScript: villkor och loopar

```js
const liv = 30;
if (liv < 20) {
  console.log("Läk mig!");
} else if (liv < 50) {
  console.log("Halvt liv");
} else {
  console.log("Lugnt");
}

for (let i = 1; i <= 3; i++) {
  console.log(`Våg ${i}`);
}

for (const namn of ["Kaytho", "Bo"]) {
  console.log(namn);
}
```

Villkoret står inom `( )`, koden inom `{ }`. `i++` ökar med 1.
""", "tasks": [
 T("js-villkor-1", 1, "Vågor", "Skriv ut Våg 1 till Våg 3 med en for-loop.",
   'for (let i = 1; i <= 3; i++) {\n  console.log(`Våg ${i}`);\n}', {"expect": "Våg 1\nVåg 2\nVåg 3"},
   ["for (let i = 1; i <= 3; i++) { … }", "console.log(`Våg ${i}`);"]),
 T("js-villkor-2", 2, "Jämna tal", "Skriv ut de jämna talen från 1 till 10 (ett per rad).",
   'for (let i = 1; i <= 10; i++) {\n  if (i % 2 === 0) console.log(i);\n}', {"expect": "2\n4\n6\n8\n10"},
   ["% ger resten vid division.", "i % 2 === 0 betyder jämnt."]),
]})
J.append({"id": "js-funktioner", "title": "JavaScript: funktioner", "requires": ["js-villkor"],
 "summary": "`function namn(a) { return … }` eller pilfunktion `const namn = (a) => …`; standardvärden `(a = 1)`.",
 "lesson_md": """
# JavaScript: funktioner

```js
function dubbla(x) {
  return x * 2;
}
const halsa = (namn) => `Hej ${namn}!`;     // pilfunktion – kort form

console.log(dubbla(21));    // 42
console.log(halsa("Bo"));
```

Pilfunktioner används överallt i modern JavaScript, t.ex. när man skickar en funktion till en
annan (`lista.map(x => x * 2)`, `knapp.addEventListener("click", () => …)`).
""", "tasks": [
 T("js-funktioner-1", 1, "Dubbla", "Skriv funktionen dubbla(x) som returnerar x * 2 och skriv ut dubbla(21).",
   'function dubbla(x) {\n  return x * 2;\n}\nconsole.log(dubbla(21));', {"expect": "42"},
   ["function dubbla(x) { return x * 2; }", "console.log(dubbla(21));"]),
 T("js-funktioner-2", 2, "Pilfunktion", "Skriv en pilfunktion snitt som tar en lista och returnerar medelvärdet. Skriv ut snitt([8, 9, 10, 9]).",
   'const snitt = (lista) => lista.reduce((a, b) => a + b, 0) / lista.length;\nconsole.log(snitt([8, 9, 10, 9]));', {"expect": "9"},
   ["lista.reduce((a, b) => a + b, 0) ger summan.", "Dela med lista.length."]),
]})
J.append({"id": "js-arrayer", "title": "JavaScript: listor och objekt", "requires": ["js-funktioner"],
 "summary": "`[]` med `push`, `length`, `map`, `filter`, `find`, `sort((a, b) => b - a)`; objekt `{ namn: \"Bo\" }`, `obj.namn`; `JSON.stringify`/`JSON.parse`.",
 "lesson_md": """
# JavaScript: listor och objekt

```js
const skyttar = [
  { namn: "Anna", poang: 612 },
  { namn: "Bo", poang: 655 },
];
const bra = skyttar.filter(s => s.poang > 620);          // de som uppfyller villkoret
const namn = skyttar.map(s => s.namn);                    // gör om varje
skyttar.sort((a, b) => b.poang - a.poang);                // högst först
console.log(JSON.stringify(namn));                        // ["Anna","Bo"]
```

**JSON** är textformen av listor och objekt – det servrar och JavaScript skickar mellan sig.
`JSON.parse(text)` gör tillbaka till objekt.
""", "tasks": [
 T("js-arrayer-1", 2, "Vinnaren", 'const skyttar = [{namn:"Anna",poang:612},{namn:"Bo",poang:655},{namn:"Cia",poang:590}]. Skriv ut namnet på den med högst poäng.',
   'const skyttar = [{namn:"Anna",poang:612},{namn:"Bo",poang:655},{namn:"Cia",poang:590}];\nconst vinnare = [...skyttar].sort((a, b) => b.poang - a.poang)[0];\nconsole.log(vinnare.namn);',
   {"expect": "Bo"}, ["Sortera med (a, b) => b.poang - a.poang.", "Den första efter sorteringen är vinnaren: [0].namn"],
   'const skyttar = [{namn:"Anna",poang:612},{namn:"Bo",poang:655},{namn:"Cia",poang:590}];\n'),
 T("js-arrayer-2", 3, "Över 600", 'Med samma lista: skriv ut JSON med namnen på dem som har över 600 poäng: ["Anna","Bo"]',
   'const skyttar = [{namn:"Anna",poang:612},{namn:"Bo",poang:655},{namn:"Cia",poang:590}];\nconsole.log(JSON.stringify(skyttar.filter(s => s.poang > 600).map(s => s.namn)));',
   {"expect": '["Anna","Bo"]'}, ["filter först, sedan map.", "JSON.stringify(…) gör texten."],
   'const skyttar = [{namn:"Anna",poang:612},{namn:"Bo",poang:655},{namn:"Cia",poang:590}];\n'),
]})
J.append({"id": "js-async", "title": "JavaScript: vänta på saker (async)", "requires": ["js-arrayer"],
 "summary": "Promise = ett svar som kommer senare; `async function` + `await`; `try/catch` runt `await`; `fetch(url)` → `await svar.json()`.",
 "lesson_md": """
# JavaScript: vänta på saker (async)

Att hämta data från en server tar tid. JavaScript väntar utan att frysa med **async/await**:

```js
async function hamtaResultat() {
  try {
    const svar = await fetch("/api/resultat.json");
    const data = await svar.json();
    console.log(data);
  } catch (fel) {
    console.log("Kunde inte hämta: " + fel.message);
  }
}
```

`await` fungerar bara inne i en `async function`. Allt som "kommer senare" är ett **Promise**.
(Övningsdatorn har inget nät – här låtsas vi med `Promise.resolve`.)
""", "tasks": [
 T("js-async-1", 3, "Vänta på svaret", 'Skriv en async function hamta() som awaitar Promise.resolve({ namn: "Bo", poang: 655 }) och skriver ut: Bo: 655. Anropa hamta().',
   'async function hamta() {\n  const data = await Promise.resolve({ namn: "Bo", poang: 655 });\n  console.log(`${data.namn}: ${data.poang}`);\n}\nhamta();',
   {"expect": "Bo: 655"}, ["const data = await Promise.resolve({ … });", "Anropa hamta() sist."]),
]})
J.append({"id": "js-dom", "title": "JavaScript på hemsidan (DOM)", "requires": ["js-async", "html-forsta"], "run": "html",
 "summary": "`document.querySelector(\"#id\")`, `.textContent`, `.addEventListener(\"click\", () => …)`, `classList.toggle`; `<script>` sist i body eller `defer`.",
 "lesson_md": """
# JavaScript på hemsidan (DOM)

På en sida kommer JavaScript åt allt via **DOM**:

```html
<p id="antal">0 klick</p>
<button id="knapp">Klicka</button>
<script>
  const knapp = document.querySelector("#knapp");
  const text = document.querySelector("#antal");
  let n = 0;
  knapp.addEventListener("click", () => {
    n++;
    text.textContent = `${n} klick`;
  });
</script>
```

- `querySelector` tar samma väljare som CSS (`#id`, `.klass`, `button`).
- `textContent` byter text (säkert – `innerHTML` med användarens text öppnar för attacker).
- Lägg `<script>` sist i `<body>` så att knapparna finns när koden körs.

Den här uppgiften kontrolleras på koden – tryck **Förhandsvisa** och prova knappen själv.
""", "tasks": [
 T("js-dom-1", 2, "Klickräknare", "Gör en sida med en knapp (id knapp) och ett stycke (id antal) som visar hur många gånger knappen klickats, med addEventListener och textContent.",
   page('  <p id="antal">0 klick</p>\n  <button id="knapp">Klicka</button>\n  <script>\n    const knapp = document.querySelector("#knapp");\n    const text = document.querySelector("#antal");\n    let n = 0;\n    knapp.addEventListener("click", () => {\n      n++;\n      text.textContent = `${n} klick`;\n    });\n  </script>'),
   {"regex": [r'id="knapp"', r'id="antal"', r"addEventListener\(\s*[\"']click", r"textContent\s*="]},
   ['document.querySelector("#knapp")', 'knapp.addEventListener("click", () => { … text.textContent = … })'], PAGE),
]})
write_track("js", J)
