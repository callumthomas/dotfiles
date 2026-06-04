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

# --- tests appended by later increments ---

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

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
