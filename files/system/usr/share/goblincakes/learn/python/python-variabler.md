# Variabler

En **variabel** är ett namn på ett värde – som en etikett på en låda.

```python
namn = "Kaytho"
nivå = 80
print(namn)
print(nivå + 1)
```

`=` betyder "lägg värdet i lådan", inte "är lika med". Värdet kan bytas senare: `nivå = nivå + 1`.

**Typer:** tal utan citattecken (`80`, `3.5`) kan man räkna med: `+ - * /`, heltalsdivision `//`
och rest `%`. Text inom citattecken är en sträng – `"80" + 1` blir ett fel. Byt typ med
`int("80")` och `str(80)`.

Text och variabler sätts ihop med en **f-sträng** – ett `f` före citattecknet och variabeln inom `{ }`:

```python
print(f"Hej {namn}, du är nivå {nivå}")
```
