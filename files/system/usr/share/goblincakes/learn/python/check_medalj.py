# Checks the medal task with every placing (the user's code is in main.py): 1–3 and others
import re
import subprocess
import sys

code = open("main.py", encoding="utf-8").read()
want = {1: "Guld", 2: "Silver", 3: "Brons", 4: "Ingen medalj", 9: "Ingen medalj"}
for place, answer in want.items():
    test = re.sub(r"^placering\s*=.*$", f"placering = {place}", code, count=1, flags=re.M)
    out = subprocess.run([sys.executable, "-c", test], capture_output=True, text=True, timeout=5).stdout.strip()
    if out != answer:
        print(f"Med placering = {place} blev det \"{out}\" – väntat \"{answer}\".")
        sys.exit(1)
print("Rätt för alla placeringar!")
