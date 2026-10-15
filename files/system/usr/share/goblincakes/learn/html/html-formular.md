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
