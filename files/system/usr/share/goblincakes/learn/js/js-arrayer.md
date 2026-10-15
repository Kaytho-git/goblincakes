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
