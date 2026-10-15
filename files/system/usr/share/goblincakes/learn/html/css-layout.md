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
