# GOBLINCAKES: `fastfetch` makes the terminal window big enough for all of it first
# (/usr/libexec/goblincakes-fastfetch; `command fastfetch` runs it as it is).
if [ -n "${BASH_VERSION:-}" ] && [ -n "${PS1:-}" ] && [ -x /usr/libexec/goblincakes-fastfetch ]; then
    fastfetch() { /usr/libexec/goblincakes-fastfetch "$@"; }
fi
