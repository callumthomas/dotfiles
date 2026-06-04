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

bc_set_border() {
  bc_hyprctl dispatch setprop "address:$1" active_border_color "$BC_SELECT_COLOR"
  bc_hyprctl dispatch setprop "address:$1" inactive_border_color "$BC_SELECT_COLOR"
}
bc_clear_border() {
  bc_hyprctl dispatch setprop "address:$1" active_border_color "$BC_NORMAL_ACTIVE"
  bc_hyprctl dispatch setprop "address:$1" inactive_border_color "$BC_NORMAL_INACTIVE"
}

bc_resolve_window() {
  python3 -c '
import json, sys
x, y = int(sys.argv[1]), int(sys.argv[2])
data = json.load(sys.stdin)
cands = []
for c in data:
    if not c.get("mapped", False) or c.get("hidden", False):
        continue
    ax, ay = c.get("at", [0, 0])
    w, h = c.get("size", [0, 0])
    if ax <= x < ax + w and ay <= y < ay + h:
        cands.append(c)
if not cands:
    sys.exit(1)
cands.sort(key=lambda c: c.get("focusHistoryID", 1 << 30))
print(cands[0]["address"], cands[0]["pid"])
' "$1" "$2"
}

bc_match_session() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
wpid = sys.argv[1]
children = {}
for line in open(sys.argv[2]):
    parts = line.split()
    if len(parts) < 2:
        continue
    pid, ppid = parts[0], parts[1]
    children.setdefault(ppid, []).append(pid)
tmux = {}
for line in open(sys.argv[3]):
    parts = line.split(None, 1)
    if len(parts) < 2:
        continue
    tmux[parts[0]] = parts[1].strip()
seen = set()
stack = [wpid]
while stack:
    p = stack.pop()
    if p in tmux:
        print(tmux[p]); sys.exit(0)
    for ch in children.get(p, []):
        if ch not in seen:
            seen.add(ch); stack.append(ch)
sys.exit(1)
PY
}

bc_deliver() {
  local session="$1" msg_file="$2"
  bc_tmux load-buffer -b broadcast "$msg_file"
  bc_tmux paste-buffer -p -d -b broadcast -t "$session"
  bc_tmux send-keys -t "$session" Enter
}

bc_state_init() { mkdir -p "$(dirname "$BC_STATE_FILE")"; [ -f "$BC_STATE_FILE" ] || : >"$BC_STATE_FILE"; }
bc_state_list() { bc_state_init; cat "$BC_STATE_FILE"; }
bc_state_has() { bc_state_init; awk -F'\t' -v a="$1" '$1==a{f=1} END{exit !f}' "$BC_STATE_FILE"; }
bc_state_session() { bc_state_init; awk -F'\t' -v a="$1" '$1==a{print $2; exit}' "$BC_STATE_FILE"; }
bc_state_add() { bc_state_init; bc_state_has "$1" || printf '%s\t%s\n' "$1" "$2" >>"$BC_STATE_FILE"; }
bc_state_remove() {
  bc_state_init
  local tmp; tmp="$(mktemp)"
  awk -F'\t' -v a="$1" '$1!=a' "$BC_STATE_FILE" >"$tmp"
  mv "$tmp" "$BC_STATE_FILE"
}

bc_clear_all() {
  bc_state_init
  local addr _session
  while IFS=$'\t' read -r addr _session; do
    [ -n "$addr" ] && bc_clear_border "$addr"
  done <"$BC_STATE_FILE"
  : >"$BC_STATE_FILE"
}
