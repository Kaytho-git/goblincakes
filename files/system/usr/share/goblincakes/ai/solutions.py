#!/usr/bin/python3
"""Kakan's known solutions from the command line (point 12 part 4, 28 Oct) – for Claude Code after Skicka till
Claude: what it fixed is known to Kakan at once, without a new image. The solutions live with her lessons
(goblinai.save_solution, kind "solution").

  solutions.py add --tecken "…" --orsak "…" --losning "…" [--kategori datorn] [--bekraftad]
  solutions.py list [ord]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import goblinai  # noqa: E402


def main():
    parser = argparse.ArgumentParser(prog="solutions.py", description="Kakans kända lösningar")
    sub = parser.add_subparsers(dest="cmd", required=True)
    add = sub.add_parser("add", help="spara en känd lösning")
    add.add_argument("--tecken", required=True, help="vad användaren märkte, med hens ord")
    add.add_argument("--orsak", default="", help="vad som var fel")
    add.add_argument("--losning", required=True, help="vad som gjordes")
    add.add_argument("--kategori", default="", choices=[""] + sorted(goblinai.CATEGORY_IDS))
    add.add_argument("--bekraftad", action="store_true", help="provat på datorn och fungerar")
    show = sub.add_parser("list", help="visa de kända lösningarna")
    show.add_argument("ord", nargs="*")
    args = parser.parse_args()

    if args.cmd == "add":
        entry, action = goblinai.save_solution(args.tecken, args.orsak, args.losning, source="claude-fix",
                                               confirmed=args.bekraftad, category=args.kategori)
        print(f"Sparad ({dict(goblinai.CATEGORIES)[entry['category']]}"
              f"{'' if entry['confirmed'] else ', ej bekräftad'}): {entry['question']} → {entry['lesson']}")
        if entry.get("similar"):
            print(f"Liknar {len(entry['similar'])} äldre – användaren väljer i Goblin AI (Lärdomar).")
        return 0
    query = " ".join(args.ord).casefold()
    found = [i for i in goblinai.load_lessons() if i.get("kind") == "solution"
             and (not query or query in (i["question"] + " " + i["lesson"]).casefold())]
    for i in found:
        print(f"- [{goblinai.category_of(i)}{'' if i.get('confirmed') else ', ej bekräftad'}] "
              f"{i['question']} → {i['lesson']}")
    if not found:
        print("Inga kända lösningar" + (f" med \"{query}\"." if query else " ännu."))
    return 0


if __name__ == "__main__":
    sys.exit(main())
