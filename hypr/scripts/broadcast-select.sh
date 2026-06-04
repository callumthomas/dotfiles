#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/broadcast-lib.sh"

pos="$(hyprctl cursorpos)"            # e.g. "960, 540"
cx="${pos%%,*}"; cx="${cx// /}"
cy="${pos##*,}"; cy="${cy// /}"

resolved="$(hyprctl clients -j | bc_resolve_window "$cx" "$cy")"
if [ -z "$resolved" ]; then bc_notify "No window under cursor"; exit 0; fi
read -r addr pid <<<"$resolved"

proc_table="$(mktemp)"; ps -eo pid=,ppid= >"$proc_table"
tmux_table="$(mktemp)"; tmux list-clients -F '#{client_pid} #{session_name}' >"$tmux_table" 2>/dev/null || true

if ! session="$(bc_match_session "$pid" "$proc_table" "$tmux_table")"; then
  rm -f "$proc_table" "$tmux_table"
  bc_notify "Not a tmux terminal — can't broadcast here"
  exit 0
fi
rm -f "$proc_table" "$tmux_table"

if bc_state_has "$addr"; then
  bc_state_remove "$addr"
  bc_clear_border "$addr"
  bc_notify "Removed from broadcast ($(bc_state_list | wc -l) selected)"
else
  bc_state_add "$addr" "$session"
  bc_set_border "$addr"
  bc_notify "Added '$session' to broadcast ($(bc_state_list | wc -l) selected)"
fi
