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
