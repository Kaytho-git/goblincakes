# Frugans laptop

Allt om frugans dator samlat på ett ställe (användarens önskan 9 nov). Detaljer om hur funktionerna är byggda står kvar i `anteckningar.md` – här står vad som gäller för just hennes dator och var man läser mer (`grep -n` på rubriken).

**Repot är publikt:** inget namn, inga IP-adresser, serienummer eller annat personligt här.

## Datorn
- **Lenovo Legion Y520-15IKBN**, Intel i7-7700HQ, 16 GB minne.
- **Grafik:** Nvidia GTX 1050 Ti (Pascal) → varianten `goblincakes-nvidia-legacy` (Nvidias 580-drivrutin). P8 i vila, ingen runtime D3. Läs mer: "Tredje varianten" i anteckningarna.
- **Disk:** Seagate ST2000LM007, 2 TB hårddisk 5400 rpm (ingen SSD), SMART frisk 4 nov.
- **Wifi:** Intel 8265 (iwlwifi), 5 GHz.
- **Skärm:** den inbyggda är spräckt (se Reparationer) – hon använder en extern skärm via HDMI (HDMI-A-1).
- **Fläktar:** `ideapad_laptop` `fan_mode`; reglaget `fan-boost` sätter effektiv kylning under spel (ej provat på hennes dator).
- **UEFI/firmware:** KEK 2011→2023 nekas av BIOS:et (Lenovo har inte signerat för modellen) – `goblin update` hoppar över det. db (UEFI CA 2023) och dbx väntar, ej provat. Läs mer: "Firmware som datorn redan nekat".

## Installerat och inställt åt henne
- GOBLINCAKES nyinstallerat (3 nov).
- **Inställningar (3–7 nov):** `no-lock-resume` (inget lösenord när locket öppnas), `sleep-lid-only` (somnar bara när locket stängs), locket = viloläge även med extern skärm, Prestandaläge av, batteriskydd `conservation_mode` 1. `autologin` finns som val (ej provat på riktig SDDM).
- **Wifi utan strömsparläge** för alla datorer (hennes hade `Power save: on`) – ej provat efter imagen: `iw dev wlp3s0 get power_save` → off.
- **AI:** lokal AI kvar (hennes val), liten modell → `/kalender` byggt för henne. Ingen egen moln-AI – ChatGPT kan kopplas in. Beställningar via GoblinShare (bilder: Goblin AI eller ChatGPT på användarens dator).
- **Hårddisken långsam:** bakgrundsjobben får låg prioritet och uppdateringarna väntar 20 min efter start; `goblincakes-prewarm` förvärmer de mest använda programmen. Mätt 4 nov: start 7 min 20 s, Firefox 23 s första gången. **Kvar:** mät igen efter en riktig omstart med nya imagen (`systemd-analyze` + `blame`). **Provkopia av prewarm i hennes hem** (`~/.local/bin/goblincakes-prewarm`, `~/.config/systemd/user/goblincakes-prewarm.*`) – tas bort när hennes image har den. Läs mer: "Hårddiskar: bakgrundsjobben", "Förvärmning efter inloggning".

## Hjälp på distans (GoblinShare)
- Hon trycker **Be om hjälp** och läser upp koden → användaren: Terminal + koden. Gäller tills terminalen stängs; under tiden fungerar `ssh <hennes namn i GoblinShare> <kommando>` från Claude Code (provat 4 nov: whoami, rpm-ostree status, uptime).
- Datorn somnar inte medan någon är inne (ej provat i en riktig hjälpsession).
- Text och filer mellan datorerna provat 3 nov. Läs mer: "GoblinShare" och "Hjälp via terminal / SSH".

## Reparationer
### Inbyggda skärmen spräckt (känt 4 nov, byte planeras 9 nov)
**Status:** skärmmodellen inte kollad än – användaren kollar via GoblinShare.
- **Ta reda på panelen** (i hennes terminal): `for f in /sys/class/drm/card*-eDP-*/edid; do echo "$f"; strings "$f"; done` – modellnamnet börjar t.ex. med `LP156WF6`, `NV156FHM` eller `N156HCA`. Inget svar → läs etiketten på panelens baksida.
- **Rätt ersättare:** 15,6", 1920×1080, matt, 30 stift eDP (kontakt till höger). IPS passar även om den gamla var TN. Lenovos delnummer: 5D10L79763, 5D10M09831, 5D10N87379, 5D10Q98000; LG LP156WF6-SPK3/-SPK6 vanliga.
- **Köpa:** ingen svensk butik hittad. eBay.de (IPS för LP156WF6-varianterna ca 56 €, brittiska säljare från ca £32 + frakt, tänk på moms/tull), Amazon.se (ca 509 kr + 158 kr frakt, TN, säljaren 2/5 – hellre IPS annorstädes), LaptopScreen.com, LCDBros, AliExpress (billigast, långsamt). Sök på panelens modellnamn.
- **Byte** (iFixit: https://www.ifixit.com/Guide/Lenovo+Y520-15IKBN+Display+Replacement/148180): stäng av helt, dra ur laddaren → bottenplattan av, batteriets 4 skruvar (PH00), dra ur batterikontakten → bänd loss skärmramen med plastverktyg (snäppen, börja nertill) → 4 skruvar (PH1) i panelen, fäll fram den → tejpen av, fäll upp spärren, dra ur kabeln → koppla in nya, spärren ner, tejpen på → prova innan allt skruvas ihop. Verktyg: PH00, PH1, plastbändare. 30–60 min.
- Efter bytet: locket/viloläget med och utan HDMI kan bete sig annorlunda – kolla.

## Önskemål och idéer
- **Kakan för hela familjen** (bara idé, 30 okt): hon ska kunna be Kakan skicka saker till sin iPhone. Läs mer: "Kakan för hela familjen".

## Logg
- 15 okt: varianten `nvidia-legacy` byggd för hennes 1050 Ti.
- 3 nov: GOBLINCAKES installerat, GoblinShare-text provat, `/kalender`, wifi och lösenordsinställningar.
- 4 nov: Hjälp via terminal provat, hårddiskmätningar, prewarm-provkopia, firmware, hennes inställningar.
- 7 nov: somnade mitt i hjälpen → ingen vila medan någon är inne; `sleep-lid-only`.
- 9 nov: skärmbytet planeras.
