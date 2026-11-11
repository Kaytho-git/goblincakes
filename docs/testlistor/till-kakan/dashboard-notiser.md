# Dashboarden: NOTISER (11 nov)
- Notistjänsten finns och kör
  kör: systemctl --user is-active goblincakes-notifications.service
  väntat: active
- Tjänsten blev monitor utan fel (Fedoras dbus-broker)
  kör: journalctl --user -u goblincakes-notifications.service -b --no-pager | tail -5
  väntat: inga rader med "Error", "AccessDenied" eller "without the answers"
- En testnotis sparas med id
  ```bash
  notify-send -a GOBLINCAKES "Testnotis" "från testlistan"; sleep 2
  /usr/libexec/goblincakes-notifications list | head -12
  ```
  väntat: överst "Testnotis" med "id" större än 0 och "closed": 0 eller 1
- Siffran i dashboarden
  fråga: Öppna dashboarden (Meta eller goblin dashboard). Har klockikonen under loggan en blå siffra, och syns Testnotis överst när du trycker på klockan?
- Siffran försvinner och Rensa tömmer
  fråga: Stäng och öppna dashboarden igen – är siffran borta? Tryck på klockan och Rensa – står det "Inga notiser"?
- Tryck på en riktig notis
  fråga: Vänta på en notis från Discord eller Steam (eller låt någon skriva till dig). Syns den i NOTISER med programmets namn, och öppnas programmet när du trycker på den?
- Bortklickad notis försvinner
  fråga: Skicka en ny testnotis (notify-send Test2 hej) och klicka bort den med krysset i Plasmas ruta. Är den borta ur dashboardens NOTISER?
