#!/usr/bin/env bash

SESSION_FILE="$HOME/.cache/hypr-session.json"

declare -A CLASS_TO_CMD=(
    ["firefox"]="firefox"
    ["ghostty"]="ghostty"
    ["thunar"]="thunar"
    ["jetbrains-datagrip"]="datagrip"
    ["Plex"]="GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb Plex"
    ["code"]="code"
    ["obsidian"]="obsidian"
    ["discord"]="discord"
    ["spotify"]="spotify"
    ["slack"]="slack"
)

if [[ ! -f "$SESSION_FILE" ]] || [[ ! -s "$SESSION_FILE" ]]; then
    exit 0
fi

window_count=$(jq 'length' "$SESSION_FILE")
if [[ "$window_count" -eq 0 ]]; then
    exit 0
fi

choice=$(printf "Yes\nNo" | wofi --dmenu --prompt "Restore previous session? ($window_count windows)")

if [[ "$choice" != "Yes" ]]; then
    exit 0
fi

jq -c '.[]' "$SESSION_FILE" | while IFS= read -r window; do
    class=$(echo "$window" | jq -r '.class')
    workspace=$(echo "$window" | jq -r '.workspace')
    floating=$(echo "$window" | jq -r '.floating')
    fullscreen=$(echo "$window" | jq -r '.fullscreen')
    pos_x=$(echo "$window" | jq -r '.at[0]')
    pos_y=$(echo "$window" | jq -r '.at[1]')
    size_x=$(echo "$window" | jq -r '.size[0]')
    size_y=$(echo "$window" | jq -r '.size[1]')

    cmd="${CLASS_TO_CMD[$class]}"
    if [[ -z "$cmd" ]]; then
        cmd="$class"
    fi

    if [[ "$workspace" -gt 0 ]]; then
        rules="workspace $workspace"
    else
        rules=""
    fi

    if [[ "$floating" == "true" ]]; then
        rules="$rules float"
        rules="$rules; size $size_x $size_y"
        rules="$rules; move $pos_x $pos_y"
    fi

    if [[ "$fullscreen" == "1" ]]; then
        rules="$rules; fullscreen"
    fi

    if [[ -n "$rules" ]]; then
        hyprctl dispatch exec "[${rules}] ${cmd}"
    else
        hyprctl dispatch exec "$cmd"
    fi

    sleep 0.3
done
