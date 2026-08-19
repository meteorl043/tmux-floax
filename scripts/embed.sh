#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/utils.sh"

# Must set these BEFORE using them in functions
ORIGIN_SESSION="$(envvar_value ORIGIN_SESSION)"
if [ -z "$FLOAX_SESSION_NAME" ]; then
    FLOAX_SESSION_NAME="$DEFAULT_SESSION_NAME"
fi

embed() {
    unset_bindings
    # "=name:" forces tmux to read the target as a SESSION. A bare "$ORIGIN_SESSION"
    # is parsed as a window index first, so sessions with numeric names (0, 1, ...)
    # silently move the window around inside the floating session instead.
    if [ -z "$ORIGIN_SESSION" ] || ! tmux has-session -t "=$ORIGIN_SESSION" 2>/dev/null; then
        tmux display-message "floax: origin session '$ORIGIN_SESSION' not found"
        return 1
    fi
    number_of_windows=$(tmux list-windows -t "=$FLOAX_SESSION_NAME" | wc -l)
    if [ "$number_of_windows" -eq 1 ]; then
        # there's only one window, need to create an alternative
        # before moving the current one to another session
        # otherwise the session dies and popping back won't work
        tmux neww -d -t "=$FLOAX_SESSION_NAME:"
    fi
    # -s is mandatory: without it tmux resolves "current window" from whichever
    # client/session it considers most recent, which is often the OUTER one -- the
    # move then silently degenerates into "session 0 -> session 0" and nothing
    # visible happens. "=name:" means "the current window of that session".
    tmux movew -s "=$FLOAX_SESSION_NAME:" -t "=$ORIGIN_SESSION:"
    # target the floating session explicitly: a bare `detach-client` lets tmux pick
    # "the current client", which is sometimes the OUTER client -- that detaches the
    # whole terminal instead of just closing the popup.
    tmux detach-client -s "=$FLOAX_SESSION_NAME"
}

# NOTE: must NOT be named pop() -- utils.sh defines its own pop() (the one that
# actually opens the popup) and tmux_popup() calls it by name. Shadowing it here
# turns tmux_popup -> pop -> tmux_popup into infinite recursion that drags one
# window after another into the floating session. See local patch notes.
pop_window() {
    # Record where this window came from, so embed can send it back. floax.sh does
    # this too, but the menu -> pop path never did, leaving a stale ORIGIN_SESSION.
    # MUST run before the session is created below: a freshly created session becomes
    # the "most recent" one, and #{session_name} would then resolve to it instead.
    origin="$(tmux display -p '#{session_name},#{window_id}')"
    ORIGIN_SESSION="${origin%,*}"
    src_window="${origin##*,}"
    tmux setenv -g ORIGIN_SESSION "$ORIGIN_SESSION"
    # Ensure scratch session exists before trying to move window to it
    if ! tmux has-session -t "=$FLOAX_SESSION_NAME" 2>/dev/null; then
        tmux new-session -d -s "$FLOAX_SESSION_NAME"
        tmux set-option -t "=$FLOAX_SESSION_NAME" status off
    fi
    # embed() calls unset_bindings, and only floax.sh ever called set_bindings --
    # so after one embed the advertised C-M-* keys (incl. C-M-e) were gone for good.
    set_bindings
    tmux movew -s "$src_window" -t "=$FLOAX_SESSION_NAME:"
    tmux_popup
}

action=$1
case "$action" in
    embed)
        embed
        ;;
    pop)
        pop_window
        ;;
esac
