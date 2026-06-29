#!/usr/bin/env bash
set -u

URGENT_COLOR="${URGENT_COLOR:-rgb(ff3333)}"
NORMAL_ACTIVE_COLOR="${NORMAL_ACTIVE_COLOR:-rgba(33ccffee)}"
NORMAL_INACTIVE_COLOR="${NORMAL_INACTIVE_COLOR:-rgba(33ccff00)}"
BLINK_INTERVAL="${BLINK_INTERVAL:-0.25}"

declare -A HUB_URGENT
HUB_PHASE=0

hub_hyprctl() {
  if [ -n "${HUB_DRY_RUN:-}" ]; then
    printf '%s\n' "$*" >>"${HUB_CAPTURE:-/dev/stdout}"
    return 0
  fi
  hyprctl "$@" >/dev/null
}

hub_set_red() {
  hub_hyprctl dispatch setprop "address:$1" active_border_color "$URGENT_COLOR"
  hub_hyprctl dispatch setprop "address:$1" inactive_border_color "$URGENT_COLOR"
}

hub_set_normal() {
  hub_hyprctl dispatch setprop "address:$1" active_border_color "$NORMAL_ACTIVE_COLOR"
  hub_hyprctl dispatch setprop "address:$1" inactive_border_color "$NORMAL_INACTIVE_COLOR"
}

hub_handle_event() {
  local line="$1"
  local ev="${line%%>>*}"
  local data="${line#*>>}"
  case "$ev" in
    urgent)
      HUB_URGENT["0x${data}"]=1
      ;;
    activewindowv2)
      local addr="0x${data}"
      if [ -n "${HUB_URGENT[$addr]:-}" ]; then
        unset 'HUB_URGENT[$addr]'
        hub_set_normal "$addr"
      fi
      ;;
    closewindow)
      unset "HUB_URGENT[0x${data}]"
      ;;
  esac
}

hub_blink_tick() {
  HUB_PHASE=$((1 - HUB_PHASE))
  local addr
  for addr in "${!HUB_URGENT[@]}"; do
    if [ "$HUB_PHASE" -eq 1 ]; then hub_set_red "$addr"; else hub_set_normal "$addr"; fi
  done
}

hub_revert_all() {
  local addr
  for addr in "${!HUB_URGENT[@]}"; do
    hub_set_normal "$addr"
  done
}

hub_resolve_sock() {
  local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
  local base="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
  if [ -n "$sig" ] && [ -S "$base/$sig/.socket2.sock" ]; then
    printf '%s\n' "$base/$sig/.socket2.sock"
    return 0
  fi
  local s
  for s in "$base"/*/.socket2.sock; do
    [ -S "$s" ] && { printf '%s\n' "$s"; return 0; }
  done
  return 1
}

hub_run() {
  trap 'hub_revert_all; exit 0' TERM INT
  local sock
  while true; do
    if ! sock="$(hub_resolve_sock)"; then
      sleep 2
      continue
    fi
    while true; do
      IFS= read -r -t "$BLINK_INTERVAL" line
      local rc=$?
      if [ "$rc" -eq 0 ]; then
        hub_handle_event "$line"
      elif [ "$rc" -gt 128 ]; then
        hub_blink_tick
      else
        break
      fi
    done < <(socat -U - "UNIX-CONNECT:$sock")
    sleep 1
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  hub_run
fi
