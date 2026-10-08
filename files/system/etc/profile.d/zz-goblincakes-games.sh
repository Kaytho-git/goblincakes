# GOBLINCAKES: type a game's name in the terminal to start it – always through Steam
# (e.g. wow, cs2, worldofwarcraft). When bash doesn't know a command it asks
# /usr/libexec/goblincakes-games, which looks the word up among the games in Steam
# right then, so newly installed games work at once. `goblin play` lists them.
# zz- so it loads after (and keeps) any other "command not found" helper.
if [ -n "${BASH_VERSION:-}" ] && [ -n "${PS1:-}" ] \
    && ! declare -f command_not_found_handle 2>/dev/null | grep -q goblincakes-games; then
    if declare -F command_not_found_handle >/dev/null; then
        eval "_goblincakes_prev_cnf() $(declare -f command_not_found_handle | tail -n +2)"
    fi
    command_not_found_handle() {
        /usr/libexec/goblincakes-games run "$1" && return 0
        if declare -F _goblincakes_prev_cnf >/dev/null; then
            _goblincakes_prev_cnf "$@"
            return $?
        fi
        printf 'bash: %s: kommandot finns inte\n' "$1" >&2
        return 127
    }
fi
