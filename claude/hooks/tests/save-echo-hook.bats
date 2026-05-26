#!/usr/bin/env bats

HOOK="${BATS_TEST_DIRNAME}/../sibyl-memory-save-echo.sh"
FIX="${BATS_TEST_DIRNAME}/fixtures"

extract_msg() {
  jq -r '.systemMessage // empty'
}

@test "memory_save: echoes 💾 with content snippet + op id + wait" {
  run bash -c "cat $FIX/posttooluse-save-sample.json | bash $HOOK"
  [ "$status" -eq 0 ]
  msg="$(echo "$output" | extract_msg)"
  echo "$msg" | grep -qE '^💾 sibyl saved: "The sibyl PostToolUse capture test fixture'
  echo "$msg" | grep -qE 'op 7df134de-9dfc-4b7d-9790-26bf3fd4fe3c'
  echo "$msg" | grep -qE 'wait=processed'
}

@test "memory_pin: echoes 📌 with fact uuid" {
  run bash -c "cat $FIX/posttooluse-pin-sample.json | bash $HOOK"
  [ "$status" -eq 0 ]
  msg="$(echo "$output" | extract_msg)"
  echo "$msg" | grep -qE '^📌 sibyl pinned fact b9efddf1-733e-0a86-ed8f-823520974fb4$'
}

@test "memory_unpin: echoes 📍 with fact uuid" {
  run bash -c "cat $FIX/posttooluse-unpin-sample.json | bash $HOOK"
  [ "$status" -eq 0 ]
  msg="$(echo "$output" | extract_msg)"
  echo "$msg" | grep -qE '^📍 sibyl unpinned fact b9efddf1-733e-0a86-ed8f-823520974fb4$'
}

@test "memory_correct: echoes ✏ with old fact uuid + new content snippet" {
  run bash -c "cat $FIX/posttooluse-correct-sample.json | bash $HOOK"
  [ "$status" -eq 0 ]
  msg="$(echo "$output" | extract_msg)"
  echo "$msg" | grep -qE '^✏ sibyl corrected fact b9efddf1-733e-0a86-ed8f-823520974fb4: "The sibyl PostToolUse capture test fixture'
}

@test "memory_invalidate: echoes 🗑 with fact uuid + reason" {
  run bash -c "cat $FIX/posttooluse-invalidate-sample.json | bash $HOOK"
  [ "$status" -eq 0 ]
  msg="$(echo "$output" | extract_msg)"
  echo "$msg" | grep -qE '^🗑 sibyl invalidated fact b00b78e3-d535-52f6-9385-2a8b119e0a67: "wrong"$'
}

@test "memory_pin error: echoes ⚠ with error text" {
  run bash -c "cat $FIX/posttooluse-error-sample.json | bash $HOOK"
  [ "$status" -eq 0 ]
  msg="$(echo "$output" | extract_msg)"
  echo "$msg" | grep -qE '^⚠ sibyl pin failed:.*not found'
}

@test "long save content truncates to ~200 chars + ellipsis" {
  long_fix="$(mktemp)"
  jq --arg t "$(printf 'x%.0s' {1..300})" '.tool_input.content = $t' \
    "$FIX/posttooluse-save-sample.json" > "$long_fix"
  run bash -c "cat $long_fix | bash $HOOK"
  [ "$status" -eq 0 ]
  msg="$(echo "$output" | extract_msg)"
  echo "$msg" | grep -qE '^💾 sibyl saved: "x{200}…"'
  rm -f "$long_fix"
}

@test "unknown tool name: no output (defensive default)" {
  unk="$(mktemp)"
  echo '{"tool_name":"mcp__sibyl__memory_unknown","tool_input":{},"tool_response":[]}' > "$unk"
  run bash -c "cat $unk | bash $HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -f "$unk"
}
