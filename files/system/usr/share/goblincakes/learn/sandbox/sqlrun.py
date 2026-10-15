"""GOBLINCAKES lärläge: runs an SQL file against SQLite and prints the results as a table.
setup.sql (when the task has one) is run first. Usage: python3 sqlrun.py main.sql"""
import sqlite3
import sys
from pathlib import Path

db = sqlite3.connect(":memory:")
if Path("setup.sql").exists():
    db.executescript(Path("setup.sql").read_text())
sql = Path(sys.argv[1]).read_text()
# One statement at a time (complete_statement knows about ; inside strings)
statements, part = [], ""
for line in sql.splitlines(keepends=True):
    part += line
    if sqlite3.complete_statement(part):
        statements.append(part.strip())
        part = ""
if part.strip():
    statements.append(part.strip())
try:
    for stmt in statements:
        cur = db.execute(stmt)
        if cur.description:
            names = [d[0] for d in cur.description]
            print(" | ".join(names))
            for row in cur.fetchall():
                print(" | ".join("" if v is None else str(v) for v in row))
    db.commit()
except sqlite3.Error as e:
    print(f"SQL-fel: {e}", file=sys.stderr)
    sys.exit(1)
