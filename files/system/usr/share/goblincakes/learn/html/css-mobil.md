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
