# The search must use prepare/execute: tried with the attack and with a real name
import re
import subprocess
import sys

code = open("main.php", encoding="utf-8").read()
if "->prepare(" not in code or "->execute(" not in code:
    print("Använd $db->prepare(…) och ->execute([…]) – sätt aldrig ihop SQL med användarens text.")
    sys.exit(1)
if re.search(r"(query|exec)\s*\(\s*\"[^\"]*\$sok", code) or re.search(r"\.\s*\$sok\s*\.", code):
    print("$sok sätts fortfarande ihop med SQL-texten – skicka den i execute([$sok]) i stället.")
    sys.exit(1)
for sok, want in [("x' OR '1'='1", "Inga träffar"), ("Bo", "Bo 655")]:
    lit = '$sok = "' + sok.replace('"', '\\"') + '";'
    test = re.sub(r"\$sok\s*=\s*\".*?\";", lambda m: lit, code, count=1)
    out = subprocess.run(["php", "-r", "?>" + test], capture_output=True, text=True, timeout=5)
    got = (out.stdout + out.stderr).strip()
    if got != want:
        print(f"Med $sok = {sok} blev det \"{got}\" – väntat \"{want}\".")
        sys.exit(1)
print("Säkert! Attacken ger inga träffar och vanliga sökningar fungerar.")
