#!/usr/bin/python3
"""Kakan's known solutions from the command line (point 12 part 4, 28 Oct) – for Claude Code after Skicka till
Claude: what it fixed is known to Kakan at once, without a new image. The solutions live with her lessons
(goblinai.save_solution, kind "solution").

  solutions.py add --tecken "…" --orsak "…" --losning "…" [--kategori datorn] [--bekraftad]
  solutions.py list [ord]                  (= read(): what Kakan's MCP tool `losningar` gives Claude Code)
  solutions.py list lärdomar [kategori]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import goblinai  # noqa: E402


def _line(i):
    mark = {"solution": "🔧", "avoid": "👎"}.get(i.get("kind"), "♥")
    extra = "" if i.get("kind") != "solution" or i.get("confirmed") else ", ej bekräftad"
    used = f", använd {i['used']} ggr" if i.get("used") else ""
    word = "Tecken" if i.get("kind") == "solution" else "Frågan"
    return f"- {mark} [{goblinai.category_of(i)}{extra}{used}, {i.get('added', '')}] {word}: {i['question']} → {i['lesson']}"


def read(query=""):
    """Empty: every known solution and how many lessons per category; "lärdomar [kategori]": the lessons;
    other words: the solutions (and lessons) about that – the ones Kakan would get first."""
    items = goblinai.load_lessons()
    solutions = [i for i in items if i.get("kind") == "solution"]
    lessons = [i for i in items if i.get("kind") != "solution"]
    names = dict(goblinai.CATEGORIES)
    query = " ".join(str(query).split())
    words = query.casefold().split()
    if not words:
        counts = ", ".join(f"{names[c]} {n}" for c, _ in goblinai.CATEGORIES
                           if (n := sum(1 for i in lessons if goblinai.category_of(i) == c)))
        out = [f"Kakans kända lösningar ({len(solutions)}) – problem som lösts på den här datorn:"]
        out += [_line(i) for i in solutions] or ["(inga ännu)"]
        out += ["", f"Lärdomar ({len(lessons)}): {counts or 'inga'}. Läs dem med \"lärdomar\" eller "
                    "\"lärdomar <kategori>\" (" + ", ".join(c for c, _ in goblinai.CATEGORIES) + ")."]
        return "\n".join(out)
    if words[0] in ("lärdomar", "lardomar", "lessons"):
        wanted = {"nätet": "natet", "övrigt": "ovrigt"}.get(words[1], words[1]) if len(words) > 1 else ""
        found = [i for i in lessons if not wanted or goblinai.category_of(i) == wanted]
        head = f"Kakans lärdomar{' i ' + names.get(wanted, wanted) if wanted else ''} ({len(found)}), nyast sist:"
        return "\n".join([head] + [_line(i) for i in found]) if found else head + " inga."
    best = goblinai.solutions_for(query)
    text_hits = [i for i in items if i not in best and query.casefold() in (i["question"] + " " + i["lesson"]).casefold()]
    if not best and not text_hits:
        return f"Inget om \"{query}\" bland Kakans {len(solutions)} kända lösningar och {len(lessons)} lärdomar."
    out = []
    if best:
        out += ["Kända lösningar som Kakan skulle få med till den frågan:"] + [_line(i) for i in best]
    if text_hits:
        out += ["Där orden står:"] + [_line(i) for i in text_hits[:30]]
    return "\n".join(out)


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
    print(read(" ".join(args.ord)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
