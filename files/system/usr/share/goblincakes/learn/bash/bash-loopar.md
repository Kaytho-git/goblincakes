# Loopar

```bash
for namn in Kaytho Bo Cia; do
  echo "Hej $namn"
done

for fil in *.txt; do
  echo "Hittade $fil"
done

for i in {1..3}; do echo "$i"; done

while read -r rad; do
  echo "Rad: $rad"
done < lista.txt
```

`for f in *.txt` är det vanligaste sättet att göra något med många filer – t.ex. byta namn eller
packa ner dem.
