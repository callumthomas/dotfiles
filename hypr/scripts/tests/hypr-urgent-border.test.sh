#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../hypr-urgent-border.sh"

PASS=0
FAIL=0

reset() {
  HUB_URGENT=()
  HUB_PHASE=0
  HUB_CAPTURE="$(mktemp)"
  HUB_DRY_RUN=1
}

cap() { cat "$HUB_CAPTURE"; }

check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$desc" "$expected" "$actual"
  fi
}

URGENT_COLOR="rgb(ff3333)"
NORMAL_ACTIVE_COLOR="rgba(33ccffee)"
NORMAL_INACTIVE_COLOR="rgba(33ccff00)"
BLINK_INTERVAL="0.45"

# shellcheck disable=SC1090
source "$SCRIPT"

reset
hub_handle_event "urgent>>5606ede17da0"
check "urgent event registers address with 0x prefix" "1" "${HUB_URGENT[0x5606ede17da0]:-}"
check "urgent event emits no hyprctl calls" "" "$(cap)"

reset
hub_handle_event "urgent>>aaa"
hub_handle_event "urgent>>bbb"
check "two urgent windows tracked" "2" "${#HUB_URGENT[@]}"

reset
hub_handle_event "urgent>>aaa"
hub_handle_event "activewindowv2>>aaa"
check "focusing an urgent window removes it" "0" "${#HUB_URGENT[@]}"
check "focusing urgent window reverts both borders to normal" \
"dispatch hl.dsp.window.set_prop({ window = \"address:0xaaa\", prop = \"active_border_color\", value = \"rgba(33ccffee)\" })
dispatch hl.dsp.window.set_prop({ window = \"address:0xaaa\", prop = \"inactive_border_color\", value = \"rgba(33ccff00)\" })" "$(cap)"

reset
hub_handle_event "urgent>>aaa"
hub_handle_event "activewindowv2>>bbb"
check "focusing a non-urgent window leaves urgent set intact" "1" "${#HUB_URGENT[@]}"
check "focusing a non-urgent window emits nothing" "" "$(cap)"

reset
hub_handle_event "activewindowv2>>ccc"
check "focusing a never-urgent window is a no-op" "0" "${#HUB_URGENT[@]}"
check "focusing a never-urgent window emits nothing" "" "$(cap)"

reset
hub_handle_event "urgent>>aaa"
hub_handle_event "closewindow>>aaa"
check "closing an urgent window drops it from the set" "0" "${#HUB_URGENT[@]}"

reset
hub_handle_event "urgent>>aaa"
hub_blink_tick
check "first tick sets red on urgent window" \
"dispatch hl.dsp.window.set_prop({ window = \"address:0xaaa\", prop = \"active_border_color\", value = \"rgb(ff3333)\" })
dispatch hl.dsp.window.set_prop({ window = \"address:0xaaa\", prop = \"inactive_border_color\", value = \"rgb(ff3333)\" })" "$(cap)"
check "phase advances to 1 after first tick" "1" "$HUB_PHASE"

reset
hub_handle_event "urgent>>aaa"
hub_blink_tick
: >"$HUB_CAPTURE"
hub_blink_tick
check "second tick reverts to normal (blink off-phase)" \
"dispatch hl.dsp.window.set_prop({ window = \"address:0xaaa\", prop = \"active_border_color\", value = \"rgba(33ccffee)\" })
dispatch hl.dsp.window.set_prop({ window = \"address:0xaaa\", prop = \"inactive_border_color\", value = \"rgba(33ccff00)\" })" "$(cap)"

reset
hub_blink_tick
check "tick with no urgent windows emits nothing" "" "$(cap)"

reset
hub_handle_event "urgent>>aaa"
hub_handle_event "urgent>>bbb"
hub_revert_all
check "revert_all touches both windows (4 setprop calls)" "4" "$(cap | wc -l)"

reset
HYPRLAND_INSTANCE_SIGNATURE="" XDG_RUNTIME_DIR="/nonexistent-$$" hub_resolve_sock
check "resolve_sock fails cleanly when no socket exists" "1" "$?"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
