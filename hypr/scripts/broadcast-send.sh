#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/broadcast-lib.sh"

bc_state_init
if [ ! -s "$BC_STATE_FILE" ]; then
  bc_notify "Nothing selected"
  exit 0
fi

msg_file="$(mktemp --suffix=.broadcast)"
trap 'rm -f "$msg_file"' EXIT

ghostty --class=com.floating.broadcast --confirm-close-surface=false \
  -e nvim "$msg_file" &
wait "$!"

if [ -z "$(tr -d '[:space:]' <"$msg_file")" ]; then
  bc_clear_all
  bc_notify "Selection cleared"
  exit 0
fi

clients="$(hyprctl clients -j)"
sent=0; skipped=0
while IFS=$'\t' read -r addr session; do
  [ -n "$addr" ] || continue
  if ! printf '%s' "$clients" | grep -q "\"$addr\""; then skipped=$((skipped + 1)); continue; fi
  if ! tmux has-session -t "=$session" 2>/dev/null; then skipped=$((skipped + 1)); continue; fi
  bc_deliver "$session" "$msg_file"
  sent=$((sent + 1))
done <"$BC_STATE_FILE"

bc_clear_all
bc_notify "Sent to $sent session(s), skipped $skipped"
