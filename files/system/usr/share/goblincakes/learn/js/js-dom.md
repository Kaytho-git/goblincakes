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
