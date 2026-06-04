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
