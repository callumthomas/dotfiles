#!/usr/bin/env bash
set -u

BC_SELECT_COLOR="${BC_SELECT_COLOR:-rgb(ff8800)}"
BC_NORMAL_ACTIVE="${BC_NORMAL_ACTIVE:-rgba(33ccffee)}"
BC_NORMAL_INACTIVE="${BC_NORMAL_INACTIVE:-rgba(33ccff00)}"
BC_STATE_FILE="${BC_STATE_FILE:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-broadcast/selected}"

bc_hyprctl() {
  if [ -n "${BC_DRY_RUN:-}" ]; then printf '%s\n' "$*" >>"${BC_CAPTURE:-/dev/stdout}"; return 0; fi
  hyprctl "$@" >/dev/null
}

bc_tmux() {
  if [ -n "${BC_DRY_RUN:-}" ]; then printf '%s\n' "$*" >>"${BC_CAPTURE:-/dev/stdout}"; return 0; fi
  tmux "$@"
}

bc_notify() {
  [ -n "${BC_QUIET:-}" ] && return 0
  notify-send -a broadcast "Broadcast" "$1" >/dev/null 2>&1 || true
}

bc_state_init() { mkdir -p "$(dirname "$BC_STATE_FILE")"; [ -f "$BC_STATE_FILE" ] || : >"$BC_STATE_FILE"; }
bc_state_list() { bc_state_init; cat "$BC_STATE_FILE"; }
bc_state_has() { bc_state_init; grep -q "^$1	" "$BC_STATE_FILE"; }
bc_state_session() { bc_state_init; awk -F'	' -v a="$1" '$1==a{print $2; exit}' "$BC_STATE_FILE"; }
bc_state_add() { bc_state_init; bc_state_has "$1" || printf '%s\t%s\n' "$1" "$2" >>"$BC_STATE_FILE"; }
bc_state_remove() {
  bc_state_init
  local tmp; tmp="$(mktemp)"
  grep -v "^$1	" "$BC_STATE_FILE" >"$tmp" || true
  mv "$tmp" "$BC_STATE_FILE"
}
