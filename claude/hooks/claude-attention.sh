#!/usr/bin/env bash
set -u

ATTENTION_STYLE="${ATTENTION_STYLE:-bg=red,fg=white,bold,blink}"

ca_run() {
  if [ -n "${CA_DRY_RUN:-}" ]; then
    printf '%s\n' "$*" >>"${CA_CAPTURE:-/dev/stdout}"
    return 0
  fi
  "$@"
}

ca_urgency() {
  case "$1" in
    permission_prompt) printf 'critical' ;;
    *) printf 'normal' ;;
  esac
}

ca_title() {
  case "$1" in
    permission_prompt) printf 'Claude needs permission' ;;
    idle_prompt) printf 'Claude is waiting' ;;
    *) printf 'Claude Code' ;;
  esac
}

ca_tmux_window() {
  local pane="$1"
  [ -n "$pane" ] || return 1
  if [ -n "${CA_DRY_RUN:-}" ]; then
    printf '@TEST'
    return 0
  fi
  tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null
}

ca_mark() {
  local win
  win="$(ca_tmux_window "${1:-}")" || return 0
  [ -n "$win" ] || return 0
  ca_run tmux set-option -w -t "$win" window-status-style "$ATTENTION_STYLE"
  ca_run tmux set-option -w -t "$win" window-status-current-style "$ATTENTION_STYLE"
}

ca_clear() {
  local win
  win="$(ca_tmux_window "${1:-}")" || return 0
  [ -n "$win" ] || return 0
  ca_run tmux set-option -uw -t "$win" window-status-style
  ca_run tmux set-option -uw -t "$win" window-status-current-style
}

ca_notify() {
  local type="$1" message="$2"
  local urgency title body
  urgency="$(ca_urgency "$type")"
  title="$(ca_title "$type")"
  body="${message:-$title}"
  ca_run notify-send -a "Claude Code" -u "$urgency" \
    -h "string:x-canonical-private-synchronous:claude-attention" \
    "$title" "$body"
}

ca_main() {
  if [ "${1:-}" = "clear" ]; then
    [ -n "${TMUX:-}" ] && ca_clear "${TMUX_PANE:-}"
    return 0
  fi
  local input type message
  input="$(cat)"
  type="$(printf '%s' "$input" | jq -r '.notification_type // ""')"
  message="$(printf '%s' "$input" | jq -r '.message // ""')"
  [ -n "${TMUX:-}" ] && ca_mark "${TMUX_PANE:-}"
  if [ "$type" = "permission_prompt" ]; then
    ca_notify "$type" "$message"
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  ca_main "$@"
fi
