# Discord: hörs jag med fördröjning?

Felsökning steg för steg (27 okt 2026). Kör kommandona i terminalen och skriv ner vad de visar.
Vanligaste orsaken först.

## 1. Dubbel brusreducering (EasyEffects + Krisp)

EasyEffects (Config → Media) och Discords egen brusreducering (Krisp) lägger var för sig
till fördröjning – kör båda, så läggs de på varandra. EasyEffects kan dessutom ha stor buffert.

```
pgrep -a easyeffects
```

- Visar den något: stäng EasyEffects och prova igen.
- Discord → Inställningar → Röst och video → Brusreducering: prova avstängd.

## 2. Bluetooth-headset

Med mikrofonen igång byter ett Bluetooth-headset läge (HFP/HSP), och det läget har märkbar
fördröjning. Headset med egen USB-mottagare (t.ex. Logitech) brukar inte ha det problemet.

```
pactl list cards | grep -i -E "name:|active profile"
```

- Står det `bluez` och `headset-head-unit` eller liknande: det är Bluetooth-läget.

## 3. PipeWires buffert

Utan reglaget "Låg ljudfördröjning" (Config → Optimering) är bufferten ~21 ms i stället för
~5 ms. Sällan det man märker, men lätt att kolla. Kör **medan du är i en röstkanal**:

```
pw-top
```

- Titta på kolumnen `QUANT` på Discords rad: 256 eller 1024 är normalt, mycket mer är misstänkt.
- Avsluta med `q`.

## 4. Röstaktiveringen klipper början

Det som känns som fördröjning är ofta att röstaktiveringen kapar första ordet.

- Discord → Röst och video: sänk känsligheten för röstaktivering, eller prova push-to-talk.
- Har du push-to-talk: kolla "fördröjning när knappen släpps".

## 5. Nätverket

I Discord, när du är i röst: klicka på den gröna signalikonen nere till vänster.

- Ping över ~100 ms eller paketförlust = nätet eller röstservern, inte datorn.

## Bra att veta när du frågar om hjälp

- Vilket headset (trådat, USB-mottagare, Bluetooth)?
- Hur märks det: säger kompisarna att du hörs sent, eller hörs det i Discords mikrofontest?
- Vad kommandona ovan visade.
