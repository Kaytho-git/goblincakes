# Password hashing: password_hash/password_verify, never md5/sha1 or the password itself
import re
import subprocess
import sys

code = open("main.php", encoding="utf-8").read()
# PHP mode is left open at the end of most files – close it before adding more code
closed = code if code.rstrip().endswith("?>") else code + "\n?>"
if re.search(r"\b(md5|sha1|crypt)\s*\(", code):
    print("md5/sha1/crypt är inte säkra för lösenord – använd password_hash och password_verify.")
    sys.exit(1)
if "password_hash" not in code or "password_verify" not in code:
    print("Använd password_hash när kontot skapas och password_verify vid inloggning.")
    sys.exit(1)
out = subprocess.run(["php", "main.php"], capture_output=True, text=True, timeout=10)
if out.stdout.strip() != "ja\nnej":
    print("Utskriften blev \"" + (out.stdout + out.stderr).strip() + "\" – väntat ja och nej på var sin rad.")
    sys.exit(1)
probe = "?>" + closed + '\n<?php $h = skapa("hemligt"); echo (str_contains($h, "hemligt") ? "klartext" : "ok");'
r = subprocess.run(["php", "-r", probe], capture_output=True, text=True, timeout=10)
if not r.stdout.strip().endswith("ok"):
    print("skapa() får inte returnera lösenordet självt.")
    sys.exit(1)
print("Rätt – lösenordet sparas bara som hash och kontrolleras med password_verify.")
