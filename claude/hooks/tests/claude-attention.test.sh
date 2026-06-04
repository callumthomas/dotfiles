#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../claude-attention.sh"

PASS=0
FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$desc" "$expected" "$actual"
  fi
}

ATTENTION_STYLE="bg=red,fg=white,bold,blink"

# shellcheck disable=SC1090
source "$SCRIPT"

check "permission_prompt maps to critical urgency" "critical" "$(ca_urgency permission_prompt)"
check "idle_prompt maps to normal urgency" "normal" "$(ca_urgency idle_prompt)"
check "unknown type maps to normal urgency" "normal" "$(ca_urgency something_else)"

check "permission_prompt title" "Claude needs permission" "$(ca_title permission_prompt)"
check "idle_prompt title" "Claude is waiting" "$(ca_title idle_prompt)"
check "fallback title" "Claude Code" "$(ca_title auth_success)"

CA_DRY_RUN=1

CA_CAPTURE="$(mktemp)"
ca_mark "%17"
check "mark sets both window styles on the pane's window" \
"tmux set-option -w -t @TEST window-status-style bg=red,fg=white,bold,blink
tmux set-option -w -t @TEST window-status-current-style bg=red,fg=white,bold,blink" "$(cat "$CA_CAPTURE")"

CA_CAPTURE="$(mktemp)"
ca_clear "%17"
check "clear unsets both window styles on the pane's window" \
"tmux set-option -uw -t @TEST window-status-style
tmux set-option -uw -t @TEST window-status-current-style" "$(cat "$CA_CAPTURE")"

CA_CAPTURE="$(mktemp)"
ca_mark ""
check "mark with empty pane is a no-op" "" "$(cat "$CA_CAPTURE")"

CA_CAPTURE="$(mktemp)"
ca_notify "permission_prompt" "Allow Bash command?"
check "notify emits notify-send with critical urgency and message body" \
"notify-send -a Claude Code -u critical -h string:x-canonical-private-synchronous:claude-attention Claude needs permission Allow Bash command?" "$(cat "$CA_CAPTURE")"

TMUX="/tmp/tmux-1000/default,1,1"
TMUX_PANE="%17"

CA_CAPTURE="$(mktemp)"
printf '%s' '{"notification_type":"permission_prompt","message":"Run git push?"}' | ca_main
check "permission_prompt marks tmux window AND toasts" \
"tmux set-option -w -t @TEST window-status-style bg=red,fg=white,bold,blink
tmux set-option -w -t @TEST window-status-current-style bg=red,fg=white,bold,blink
notify-send -a Claude Code -u critical -h string:x-canonical-private-synchronous:claude-attention Claude needs permission Run git push?" "$(cat "$CA_CAPTURE")"

CA_CAPTURE="$(mktemp)"
printf '%s' '{"notification_type":"idle_prompt","message":"waiting"}' | ca_main
check "idle_prompt marks tmux window but does NOT toast" \
"tmux set-option -w -t @TEST window-status-style bg=red,fg=white,bold,blink
tmux set-option -w -t @TEST window-status-current-style bg=red,fg=white,bold,blink" "$(cat "$CA_CAPTURE")"

CA_CAPTURE="$(mktemp)"
ca_main clear
check "clear mode unsets the tmux window styles" \
"tmux set-option -uw -t @TEST window-status-style
tmux set-option -uw -t @TEST window-status-current-style" "$(cat "$CA_CAPTURE")"

unset TMUX
CA_CAPTURE="$(mktemp)"
printf '%s' '{"notification_type":"idle_prompt"}' | ca_main
check "outside tmux, idle_prompt emits nothing" "" "$(cat "$CA_CAPTURE")"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
