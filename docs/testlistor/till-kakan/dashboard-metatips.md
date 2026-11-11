# Dashboard: Meta-tipset på skrivbordet och batteriet i dashboarden (11 nov) – efter nästa image
- Delarna finns i imagen
  kör: ls /usr/share/plasma/plasmoids/org.goblincakes.metahint/metadata.json && grep -c batteries /usr/share/goblincakes/dashboard/dash.py
  väntat: filen finns och en siffra 1 eller mer (annars är imagen för gammal – goblin update och starta om)
- Batteriet läses
  kör: python3 /usr/share/goblincakes/dashboard/dash.py batteries
  väntat: din mus (och ev. headset) med procent – [] om ingen trådlös enhet med batteri är på
- Batteriet i dashboarden
  fråga: Öppna dashboarden. Står musens batteri (ikon, procent och namnet litet under) uppe till höger mellan Anpassa och klockan? Stämmer procenten med skrivbordsraden/toppfältet?
- Tipset (bara med upplägget Dashboard)
  kör: /usr/libexec/goblincakes-desktop-layout status; cat ~/.local/state/goblincakes/dashboard-shown 2>/dev/null || echo 0
  väntat: dashboard och en siffra – är den under 3 ska tipset synas (är den 3 eller mer: kör rm ~/.local/state/goblincakes/dashboard-shown och /usr/libexec/goblincakes-desktop-layout login för att se det igen)
- Tipset syns
  fråga: Minimera alla fönster. Står "Ingen docka, inget toppfält – tryck Meta för dashboarden" i en liten ruta längst ner mitt på huvudskärmen? Ligger den rätt (inte för långt upp, inte utanför skärmen)?
- Tipset försvinner
  fråga: Tryck Meta och stäng dashboarden tre gånger, och vänta tio sekunder. Är tipset borta? (Vid nästa inloggning tas widgeten bort helt.)
