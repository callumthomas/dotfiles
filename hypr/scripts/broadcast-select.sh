#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/broadcast-lib.sh"

pos="$(hyprctl cursorpos)"
cx="${pos%%,*}"; cx="${cx// /}"
cy="${pos##*,}"; cy="${cy// /}"

if ! [[ "$cx" =~ ^-?[0-9]+$ && "$cy" =~ ^-?[0-9]+$ ]]; then
  bc_notify "Couldn't read cursor position"; exit 1
fi

resolved="$(hyprctl clients -j | bc_resolve_window "$cx" "$cy")"
if [ -z "$resolved" ]; then bc_notify "No window under cursor"; exit 0; fi
read -r addr pid <<<"$resolved"

proc_table="$(mktemp)"; ps -eo pid=,ppid= >"$proc_table"
tmux_table="$(mktemp)"; tmux list-clients -F '#{client_pid} #{session_name}' >"$tmux_table" 2>/dev/null || true

session="$(bc_match_session "$pid" "$proc_table" "$tmux_table")"; rc=$?
rm -f "$proc_table" "$tmux_table"
if [ "$rc" -eq 2 ]; then
  bc_notify "Ambiguous: ghostty single-instance is on. Fully restart ghostty so each window has its own PID."
  exit 0
elif [ "$rc" -ne 0 ]; then
  bc_notify "Not a tmux terminal — can't broadcast here"
  exit 0
fi

if bc_state_has "$addr"; then
  bc_state_remove "$addr"
  bc_clear_border "$addr"
  bc_notify "Removed from broadcast ($(bc_state_list | wc -l) selected)"
else
  bc_state_add "$addr" "$session"
  bc_set_border "$addr"
  bc_notify "Added '$session' to broadcast ($(bc_state_list | wc -l) selected)"
fi
