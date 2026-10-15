# Pipor: grep, sort, wc

Med `|` (pipe) blir ett kommandos utskrift nästa kommandos indata:

```bash
cat logg.txt | grep "ERROR" | wc -l     # hur många felrader?
sort namn.txt | uniq -c                  # hur många av varje
```

| Verktyg | Gör |
|---|---|
| `grep ord` | rader som innehåller ordet (`-i` struntar i versaler, `-v` = de som inte gör det) |
| `sort` | sorterar (`-n` som tal, `-r` baklänges) |
| `uniq -c` | räknar likadana rader i följd (sortera först) |
| `wc -l` | antal rader |
| `head -n 3` / `tail -n 3` | första / sista raderna |
| `cut -d' ' -f1` | första fältet i varje rad |

Det här är vardag i Linux – t.ex. `journalctl --user -b | grep -i fel`.
