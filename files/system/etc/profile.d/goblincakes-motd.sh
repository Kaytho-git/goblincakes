# GOBLINCAKES: show the goblin commands when a new terminal opens (like Bazzite's ujust list).
# Turn off with "goblin motd off". Only in interactive terminals, once per window
# (not again in shells started from it).
if [ -n "${PS1:-}" ] && [ -t 1 ] && [ -z "${GOBLINCAKES_MOTD_SHOWN:-}" ] && command -v goblin >/dev/null 2>&1; then
    export GOBLINCAKES_MOTD_SHOWN=1
    goblin motd
fi
