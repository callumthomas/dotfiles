#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../broadcast-lib.sh"

PASS=0
FAIL=0

reset() {
  BC_CAPTURE="$(mktemp)"
  BC_DRY_RUN=1
  BC_QUIET=1
  BC_STATE_FILE="$(mktemp)"
  BC_SELECT_COLOR="rgb(ff8800)"
  BC_NORMAL_ACTIVE="rgba(33ccffee)"
  BC_NORMAL_INACTIVE="rgba(33ccff00)"
}

cap() { cat "$BC_CAPTURE"; }

check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$desc" "$expected" "$actual"
  fi
}

# shellcheck disable=SC1090
source "$SCRIPT"

reset
bc_state_add 0xaaa delio-ai
bc_state_add 0xbbb portfolio
check "add writes two records" "0xaaa	delio-ai
0xbbb	portfolio" "$(bc_state_list)"

reset
bc_state_add 0xaaa delio-ai
check "has finds present address" "0" "$(bc_state_has 0xaaa; echo $?)"
check "has rejects absent address" "1" "$(bc_state_has 0xzzz; echo $?)"

reset
bc_state_add 0xaaa delio-ai
bc_state_add 0xbbb portfolio
bc_state_remove 0xaaa
check "remove drops only the matching record" "0xbbb	portfolio" "$(bc_state_list)"

reset
bc_state_add 0xaaa delio-ai
check "session lookup returns the mapped session" "delio-ai" "$(bc_state_session 0xaaa)"

reset
bc_state_add 0xaaa delio-ai
bc_state_add 0xaaa delio-ai
check "duplicate add does not create a second record" "1" "$(bc_state_list | wc -l)"

reset
bc_set_border 0xaaa
check "set_border paints both borders orange" \
"dispatch setprop address:0xaaa active_border_color rgb(ff8800)
dispatch setprop address:0xaaa inactive_border_color rgb(ff8800)" "$(cap)"

reset
bc_clear_border 0xaaa
check "clear_border restores configured colours" \
"dispatch setprop address:0xaaa active_border_color rgba(33ccffee)
dispatch setprop address:0xaaa inactive_border_color rgba(33ccff00)" "$(cap)"

CLIENTS_JSON='[
  {"address":"0xaaa","pid":100,"mapped":true,"hidden":false,"at":[0,0],"size":[500,500],"focusHistoryID":2},
  {"address":"0xbbb","pid":200,"mapped":true,"hidden":false,"at":[100,100],"size":[500,500],"focusHistoryID":0},
  {"address":"0xccc","pid":300,"mapped":false,"hidden":false,"at":[0,0],"size":[500,500],"focusHistoryID":1},
  {"address":"0xddd","pid":400,"mapped":true,"hidden":true,"at":[0,0],"size":[500,500],"focusHistoryID":3}
]'

reset
check "cursor in single window resolves it" "0xaaa 100" "$(printf '%s' "$CLIENTS_JSON" | bc_resolve_window 50 50)"

reset
check "overlap picks topmost by focusHistoryID" "0xbbb 200" "$(printf '%s' "$CLIENTS_JSON" | bc_resolve_window 200 200)"

reset
check "cursor over empty space resolves nothing" "" "$(printf '%s' "$CLIENTS_JSON" | bc_resolve_window 2000 2000)"
check "empty-space resolution returns failure" "1" "$(printf '%s' "$CLIENTS_JSON" | bc_resolve_window 2000 2000; echo $?)"

reset
check "unmapped/hidden windows ignored" "0xaaa 100" "$(printf '%s' "$CLIENTS_JSON" | bc_resolve_window 10 10)"

PROC_TABLE="$(mktemp)"; printf '%s\n' \
  "100 1" "150 100" "200 150" \
  "300 1" "350 300" \
  "400 1" >"$PROC_TABLE"
TMUX_TABLE="$(mktemp)"; printf '%s\n' \
  "200 delio-ai" "350 portfolio" >"$TMUX_TABLE"

reset
check "window pid maps to session via grandchild tmux client" \
  "delio-ai" "$(bc_match_session 100 "$PROC_TABLE" "$TMUX_TABLE")"

reset
check "second window maps to its own session" \
  "portfolio" "$(bc_match_session 300 "$PROC_TABLE" "$TMUX_TABLE")"

reset
check "window with no tmux client in subtree returns failure" \
  "1" "$(bc_match_session 400 "$PROC_TABLE" "$TMUX_TABLE"; echo $?)"

reset
MSGF="$(mktemp)"; printf 'line one\nline two' >"$MSGF"
bc_deliver delio-ai "$MSGF"
check "deliver loads buffer, bracketed-pastes, then submits" \
"load-buffer -b broadcast $MSGF
paste-buffer -p -d -b broadcast -t =delio-ai
send-keys -t =delio-ai Enter" "$(cap)"

reset
bc_state_add 0xaaa delio-ai
bc_state_add 0xbbb portfolio
bc_clear_all
check "clear_all reverts borders for every selected window" \
"dispatch setprop address:0xaaa active_border_color rgba(33ccffee)
dispatch setprop address:0xaaa inactive_border_color rgba(33ccff00)
dispatch setprop address:0xbbb active_border_color rgba(33ccffee)
dispatch setprop address:0xbbb inactive_border_color rgba(33ccff00)" "$(cap)"
check "clear_all empties the state file" "" "$(bc_state_list)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
