#!/usr/bin/env bash

SESSION_FILE="$HOME/.cache/hypr-session.json"
DEBOUNCE_PID=""
DEBOUNCE_DELAY=2

save_session() {
    hyprctl clients -j | jq '[.[] | {class, title, workspace: .workspace.id, floating, fullscreen, at, size}]' > "$SESSION_FILE"
}

debounced_save() {
    if [[ -n "$DEBOUNCE_PID" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
        kill "$DEBOUNCE_PID" 2>/dev/null
        wait "$DEBOUNCE_PID" 2>/dev/null
    fi

    (sleep "$DEBOUNCE_DELAY" && save_session) &
    DEBOUNCE_PID=$!
}

cleanup() {
    if [[ -n "$DEBOUNCE_PID" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
        kill "$DEBOUNCE_PID" 2>/dev/null
    fi
    save_session
    exit 0
}

trap cleanup SIGTERM SIGINT

save_session

SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

socat -U - UNIX-CONNECT:"$SOCKET_PATH" | while IFS= read -r event; do
    case "$event" in
        openwindow\>*|closewindow\>*|movewindow\>*|workspace\>*)
            debounced_save
            ;;
    esac
done
