#!/usr/bin/env python3
"""GOBLINCAKES lärläge: runs the user's main.gd in Godot without a window. main.gd is a node
script, as in a real Godot scene (extends Node/Node2D …): it is added to the scene tree, _ready
runs, then _process for the task's number of frames (frames.txt, 60 frames = 1 second at a
fixed 60 fps). inputs.txt presses and releases actions on given frames ("30 press ui_right")."""
import os
import shutil
import subprocess
import sys
from pathlib import Path

HARNESS = r'''extends SceneTree

var frame := 0
var inputs := {}

func _init():
	var f = FileAccess.open("res://inputs.txt", FileAccess.READ)
	if f:
		while not f.eof_reached():
			var parts = f.get_line().strip_edges().split(" ", false)
			if parts.size() == 3:
				var at = int(parts[0])
				if not inputs.has(at):
					inputs[at] = []
				inputs[at].append([parts[1], parts[2]])
	var s = load("res://main.gd")
	if s == null or not s.can_instantiate():
		quit(1)
		return
	var n = s.new()
	if not (n is Node):
		print("main.gd måste börja med extends Node (eller Node2D …) – som ett skript på en nod.")
		quit(1)
		return
	n.name = "Main"
	root.add_child(n)

func _process(_delta):
	frame += 1
	for a in inputs.get(frame, []):
		if a[0] == "press":
			Input.action_press(a[1])
		else:
			Input.action_release(a[1])
	return false
'''
# Fewer worker threads: Godot otherwise starts one per processor core (the practice computer
# allows 64 processes and 256 MB)
PROJECT = "config_version=5\n\n[threading]\n\nworker_pool/max_threads=2\n"
NOISE = ("WARNING: ObjectDB instances leaked", "Leaked instance", "ERROR: 1 resources still in use",
         "ERROR: Resources still in use", "   Resource still in use")


def godot():
    for c in (os.environ.get("GOBLINCAKES_GODOT"), "/opt/godot/godot", shutil.which("godot")):
        if c and os.path.exists(c):
            return c
    return None


def main():
    script = sys.argv[1] if len(sys.argv) > 1 else "main.gd"
    if Path(script).resolve() != Path("main.gd").resolve():
        shutil.copy(script, "main.gd")
    Path("_goblincakes_harness.gd").write_text(HARNESS)
    Path("project.godot").write_text(PROJECT)
    frames = 1
    if Path("frames.txt").exists():
        frames = int(Path("frames.txt").read_text().split()[0])
    exe = godot()
    if not exe:
        print("Godot finns inte i övningsdatorn – gör om den i Lär dig koda.")
        return 1
    try:
        r = subprocess.run([exe, "--headless", "--no-header", "--fixed-fps", "60", "--quit-after", str(frames + 1),
                            "--script", "_goblincakes_harness.gd"], capture_output=True, text=True, timeout=8)
    except subprocess.TimeoutExpired:
        print("Godot svarade inte på 8 sekunder – en loop som aldrig slutar?")
        return 124
    out, skip = [], False
    for line in (r.stdout + r.stderr).splitlines():
        if skip and line.startswith("   "):
            continue  # the "at:" line under a hidden message
        skip = line.startswith(NOISE) or "_goblincakes_harness.gd" in line
        if not skip:
            out.append(line.replace("res://", ""))
    text = "\n".join(out).strip()
    if text:
        print(text)
    failed = r.returncode != 0 or "SCRIPT ERROR" in text or "Parse Error" in text
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
