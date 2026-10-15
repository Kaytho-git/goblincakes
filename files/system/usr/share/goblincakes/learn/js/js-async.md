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
