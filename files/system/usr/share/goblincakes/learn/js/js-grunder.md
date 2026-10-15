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
