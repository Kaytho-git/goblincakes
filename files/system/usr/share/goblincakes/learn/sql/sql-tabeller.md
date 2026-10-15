# Skapa tabeller

```sql
CREATE TABLE anvandare (
  id INTEGER PRIMARY KEY,         -- unikt nummer, sätts själv
  namn TEXT NOT NULL UNIQUE,      -- måste finnas, inga dubbletter
  losenord_hash TEXT NOT NULL,    -- aldrig själva lösenordet!
  skapad TEXT DEFAULT CURRENT_TIMESTAMP
);
```

- En tabell per sorts sak (användare, anmälningar, raider) – koppla med id.
- `NOT NULL`, `UNIQUE` och `DEFAULT` låter databasen själv vakta reglerna.
- I MariaDB heter typerna lite annorlunda (`INT AUTO_INCREMENT`, `VARCHAR(100)`) – idén är densamma.
