#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/utils.sh"

BORDER=2   # tmux popup -b rounded eats one row/col of border on each side, so
           # '#{window_width}' measured from INSIDE the popup is 2 less than the
           # -w that produced it. Without this every resize step silently loses 2.

# The outer client's tty, captured BEFORE detach-client -- afterwards tmux has
# no "current client" to hang the new popup on, so the re-pop lands on the wrong
# client or fails outright.
get_outer_client() {
    local origin_session tty=""
    origin_session="$(envvar_value ORIGIN_SESSION)"
    if [ -n "$origin_session" ]; then
        tty="$(tmux list-clients -t "=$origin_session" -F '#{client_tty}' 2>/dev/null | head -1)"
    fi
    if [ -z "$tty" ]; then
        tty="$(tmux list-clients -F '#{client_tty} #{client_session}' 2>/dev/null \
            | awk -v f="$FLOAX_SESSION_NAME" '$2 != f { print $1; exit }')"
    fi
    printf '%s' "$tty"
}

# Close the popup and reopen it with the new geometry/title on the same client.
repop() {
    FLOAX_TARGET_CLIENT="$(get_outer_client)"
    tmux detach-client -s "=$FLOAX_SESSION_NAME"
    tmux_popup
}

resize() {
    current_width=$(($(tmux display -p '#{window_width}') + BORDER))
    current_height=$(($(tmux display -p '#{window_height}') + BORDER))
    if [ $((current_height+step)) -le 0 ] || [ $((current_width+step)) -le 0 ]; then
        return
    fi
    ORIGIN_SESSION="$(envvar_value ORIGIN_SESSION)"
    if [ $((current_height+step)) -gt "$(tmux display -p -t "=$ORIGIN_SESSION:" '#{window_height}')" ] ||
        [ $((current_width+step)) -gt "$(tmux display -p -t "=$ORIGIN_SESSION:" '#{window_width}')" ]; then
        return
    fi
    tmux setenv -g FLOAX_WIDTH $((current_width+step))
    tmux setenv -g FLOAX_HEIGHT $((current_height+step))
    repop
}

full_screen() {
    tmux setenv -g FLOAX_WIDTH 100%
    tmux setenv -g FLOAX_HEIGHT 100%
    repop
}

reset_size() {
    tmux setenv -g FLOAX_WIDTH "$(tmux_option_or_fallback '@floax-width' '80%')" 
    tmux setenv -g FLOAX_HEIGHT "$(tmux_option_or_fallback '@floax-height' '80%')" 
    repop
}

unlock_bindings() {
    set_bindings
    local saved_title
    saved_title="$(tmux showenv -g FLOAX_TITLE_SAVED 2>/dev/null | cut -d '=' -f 2-)"
    if [ -n "$saved_title" ]; then
        change_popup_title "$saved_title"
        tmux setenv -gu FLOAX_TITLE_SAVED
    else
        change_popup_title "$DEFAULT_TITLE"
    fi
}

lock_bindings() {
    tmux setenv -g FLOAX_TITLE_SAVED "$FLOAX_TITLE"
    unset_bindings
    tmux bind -n C-M-u run "$CURRENT_DIR/zoom-options.sh unlock"
    change_popup_title "Bindings locked. Unlock with [Ctrl-Alt-u]"
}

change_popup_title() {
    tmux setenv -g FLOAX_TITLE "$1"
    repop
}

case "$1" in
    in)
        step=-5
        resize
        ;;
    out)
        step=5
        resize
        ;;
    full)
        full_screen
        ;;
    reset)
        reset_size
        ;;
    lock)
        lock_bindings
        ;;
    unlock)
        unlock_bindings
        ;;
esac
