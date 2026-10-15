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
