# Easy Anti-Cheat-kontrollen – efter nästa image
- Hjälparen finns i imagen
  kör: test -x /usr/libexec/goblincakes-anticheat && echo finns
  väntat: finns (annars är imagen för gammal – goblin update och starta om)
- Polkit-regeln finns
  kör: test -f /usr/share/polkit-1/actions/org.goblincakes.anticheat.policy && echo finns
  väntat: finns
- Kontrollen via pkexec utan lösenord
  kör: /usr/libexec/goblincakes-anticheat check --json
  väntat: JSON där "root" är true och ingen kontroll har "ok": null (null = kunde inte läsas)
- Kärnans signatur
  kör: goblin anticheat
  väntat: Signerad kärna = OK med "Fedora Secure Boot CA", Signerade drivrutiner = OK, BPF-LSM = OK
- Measured boot
  kör: goblin anticheat
  väntat: Measured boot = OK (om TPM är på i BIOS). NEJ med "firmware mätte starten, men inte starthanteraren" = skriv det i rapporten
- Kortet i Config
  fråga: Öppna GOBLINCAKES Config → Grafik och scrolla ner. Syns kortet "Easy Anti-Cheat v2 (Fortnite m.fl.)" med tio rader, och stämmer bockarna med goblin anticheat?
- Gör systemet redo
  fråga: Om knappen "Gör systemet redo" syns: tryck den. Frågade den efter lösenordet, och står det sedan "Starta om datorn för att ändringarna ska gälla"? (Hoppa om knappen inte syns.)
- Efter omstart
  kör: cat /proc/sys/kernel/kexec_load_disabled; rpm-ostree kargs
  väntat: 1, och kargs innehåller sysctl.kernel.kexec_load_disabled=1 (bara om Gör systemet redo trycktes – annars 0 och hoppa)
- Bevakningen av anti-fusket finns
  kör: python3 /usr/share/goblincakes/ai/reminders.py påminnelser
  väntat: en rad "säg till när något ändras i Linux-stödet för FACEIT, Ricochet och EA Javelin" (läggs in när tjänsten goblincakes-kakan-vakt startat efter nästa image)
- Listan går att läsa
  kör: python3 /usr/share/goblincakes/ai/anticheatwatch.py
  väntat: rader för Counter-Strike 2 (FACEIT), Battlefield 6 och Call of Duty med status, och "Källa: https://areweanticheatyet.com"
