# The form task with several inputs: the user's main.php is run with other $_POST values too
import re
import subprocess
import sys

code = open("main.php", encoding="utf-8").read()
cases = [('["namn" => "  Bo ", "roll" => "Tank"]', "Bo anmäld som Tank"),
         ('["namn" => "Kaytho", "roll" => "Healer"]', "Kaytho anmäld som Healer"),
         ('["namn" => "<b>X</b>", "roll" => "DPS"]', "&lt;b&gt;X&lt;/b&gt; anmäld som DPS"),
         ('["namn" => "Bo", "roll" => "Kock"]', "Fel roll")]
for post, want in cases:
    test = re.sub(r"\$_POST\s*=\s*\[.*?\];", lambda m: "$_POST = " + post + ";", code, count=1, flags=re.S)
    out = subprocess.run(["php", "-r", "?>" + test], capture_output=True, text=True, timeout=5)
    got = (out.stdout + out.stderr).strip()
    if got != want:
        print(f"Med $_POST = {post} blev det \"{got}\" – väntat \"{want}\".")
        sys.exit(1)
print("Rätt för alla formulärsvar – även farliga namn och fel roll.")
