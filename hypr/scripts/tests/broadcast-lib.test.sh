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

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
