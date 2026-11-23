# Fläktboost på fler bärbara (efter nästa image)
- Reglaget på den stationära datorn
  kör: /usr/libexec/goblincakes-tweak status fan-boost; ls /sys/firmware/acpi/platform_profile 2>&1; ls /sys/bus/platform/devices/ | grep -c VPC2004
  väntat: står det "unavailable" ska ls säga "No such file" och sista raden 0 (en stationär dator har ingen platform_profile). Finns platform_profile ska första raden vara "on" eller "off" – båda är OK.
- Spelvakten startar utan fel med den nya koden
  kör: systemctl --user is-active goblincakes-gameguard; journalctl --user -u goblincakes-gameguard -n 30 --no-pager | grep -ci traceback
  väntat: "active" och sedan 0 (inga Python-fel)
- Energiprofilen rörs inte under spel på den stationära datorn
  fråga: Starta ett spel en minut, stäng det. Kör sedan `journalctl --user -u goblincakes-gameguard -n 20 --no-pager | grep -i energiprofil`. Är det tomt (ingen rad om energiprofil)?
