# Login with sessions: wrong password stays out, right password sets the name and changes the session id
import subprocess
import sys

code = open("main.php", encoding="utf-8").read()
# PHP mode is left open at the end of most files – close it before adding more code
closed = code if code.rstrip().endswith("?>") else code + "\n?>"
harness = r'''<?php
ob_start();
session_save_path(sys_get_temp_dir());
ini_set('session.use_cookies', '0');
ini_set('session.use_only_cookies', '0');
session_start();
$h = password_hash('hunter2', PASSWORD_DEFAULT);
$fore = session_id();
$r = logga_in('Kaytho', 'fel', $h);
echo ($r ? 'fel-inne' : 'fel-ute'), ' ', (empty($_SESSION['anvandare']) ? 'tom' : 'satt'), ' ', (session_id() === $fore ? 'samma' : 'ny'), "\n";
$r = logga_in('Kaytho', 'hunter2', $h);
echo ($r ? 'in' : 'ute'), ' ', ($_SESSION['anvandare'] ?? '-'), ' ', (session_id() === $fore ? 'samma' : 'ny'), "\n";
'''
r = subprocess.run(["php", "-r", "?>" + closed + harness], capture_output=True, text=True, timeout=10)
lines = r.stdout.strip().splitlines()
if len(lines) != 2:
    print("Koden gick inte att köra: " + (r.stdout + r.stderr).strip()[:300])
    sys.exit(1)
if lines[0] != "fel-ute tom samma":
    print("Med fel lösenord ska logga_in returnera false och inte röra sessionen.")
    sys.exit(1)
first, name, sid = lines[1].split(" ", 2)
if first != "in":
    print("Med rätt lösenord ska logga_in returnera true.")
    sys.exit(1)
if name != "Kaytho":
    print('Spara namnet i $_SESSION["anvandare"] när lösenordet stämmer.')
    sys.exit(1)
if sid != "ny":
    print("Byt sessionsnyckel med session_regenerate_id(true) direkt efter lyckad inloggning.")
    sys.exit(1)
print("Rätt – fel lösenord släpps inte in, och efter inloggning byts sessionsnyckeln.")
