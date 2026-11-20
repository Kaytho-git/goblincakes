# Skrivna kommandon utan AI (20 nov)
- Matchningen finns i imagen
  kör: python3 /usr/share/goblincakes/ai/voicecmd.py --skrivet "pausa" "starta om datorn" "hur pausar jag steam?"
  väntat: första raden slutar med ('pause', ''), de två andra med None
- Pausa musiken från chatten
  fråga: Starta musik i GoblinAmp eller Spotify. Skriv bara "pausa" i Goblin AI (en vanlig chatt, inte /testa). Pausades musiken direkt, och står det "Direkt – utan AI" vid svaret?
- Volymen från chatten
  fråga: Skriv "sätt volymen till 30" i Goblin AI. Ändrades musikens volym, och visar svaret något i stil med "Volymen i GoblinAmp 50 % → 30 %" (med procenttecken)?
- Starta ett program
  fråga: Skriv "starta discord" i Goblin AI. Startade Discord direkt utan att Kakan tänkte?
- Okänt program går till Kakan
  fråga: Skriv "starta blablaprogrammet" i Goblin AI. Svarade Kakan som vanligt (med modellnamn vid svaret, inte "Direkt – utan AI")?
- En fråga går till Kakan
  fråga: Skriv "kan du stoppa uppdateringen" i Goblin AI. Svarade Kakan (inte "Direkt – utan AI"), och fortsatte musiken spela?
- Under spel
  fråga: Starta WoW och musik. Gå till Goblin AI och skriv "nästa låt". Bytte låten direkt fast den lokala AI:n vilar under spelet?
