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
