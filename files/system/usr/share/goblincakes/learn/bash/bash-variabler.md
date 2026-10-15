# Variabler och kommandon i kommandon

```bash
namn="Kaytho"
echo "Hej $namn"
antal=$(ls | wc -l)          # resultatet av ett kommando
echo "Det finns $antal filer"
echo $(( 6 * 12 ))           # räkna med heltal
```

- **Inga mellanslag** runt `=` (`namn = x` blir ett fel).
- Sätt variabler inom **dubbla citattecken** `"$namn"` – annars delas värden med mellanslag upp.
  Enkla citattecken `'$namn'` skriver ut texten precis som den står.
- `$(…)` kör ett kommando och ger dess utskrift. `$(( … ))` räknar.
