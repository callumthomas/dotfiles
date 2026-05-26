#!/usr/bin/env bats

HOOK="${BATS_TEST_DIRNAME}/../sibyl-memory-recall.sh"
FIX="${BATS_TEST_DIRNAME}/fixtures"

prompt_input() {
  jq -n --arg p "$1" '{prompt: $p}'
}

extract_ctx() {
  jq -r '.hookSpecificOutput.additionalContext // empty'
}

@test "skips empty prompt" {
  run bash -c "echo '$(prompt_input "")' | bash $HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skips short prompt (<10 chars)" {
  run bash -c "echo '$(prompt_input "hi there")' | bash $HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skips slash commands" {
  run bash -c "echo '$(prompt_input "/help me with a thing")' | bash $HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "happy path: shows top-3 facts with credibility + total hits + timing" {
  export MOCK_SIBYL_SEARCH_RESPONSE_FILE="$FIX/sibyl-search-hits.json"
  run bash -c "echo '$(prompt_input "what database does billing use?")' | bash $HOOK"
  [ "$status" -eq 0 ]
  ctx="$(echo "$output" | extract_ctx)"
  echo "$ctx" | grep -qE 'Relevant team memories \(3 of 5 hits, lookup [0-9]+ms\)'
  echo "$ctx" | grep -qE '1\. \[credibility 0\.91\] We chose PostgreSQL'
  echo "$ctx" | grep -qE '2\. \[credibility 0\.87\] Sibyl listens on neo4j'
  echo "$ctx" | grep -qE '3\. \[credibility 0\.74\] Pre-commit hook fails'
  echo "$ctx" | grep -qE 'memory lookup took [0-9]+ms'
}

@test "no-hits: shows '(no relevant team memories)' + timing" {
  export MOCK_SIBYL_SEARCH_RESPONSE_FILE="$FIX/sibyl-search-empty.json"
  run bash -c "echo '$(prompt_input "an unknowable question")' | bash $HOOK"
  [ "$status" -eq 0 ]
  ctx="$(echo "$output" | extract_ctx)"
  echo "$ctx" | grep -qE '\(no relevant team memories\)'
  echo "$ctx" | grep -qE 'memory lookup took [0-9]+ms'
}

@test "curl failure: emits visible unreachable warning, exits 0" {
  export MOCK_SIBYL_CURL_EXIT=7
  run bash -c "echo '$(prompt_input "anything at all")' | bash $HOOK"
  [ "$status" -eq 0 ]
  ctx="$(echo "$output" | extract_ctx)"
  echo "$ctx" | grep -qE '⚠ Sibyl unreachable \(curl exit 7'
  echo "$ctx" | grep -qE 'Do not call memory_save'
}

@test "HTTP non-2xx: emits visible warning with status code" {
  export MOCK_SIBYL_HTTP_STATUS=500
  export MOCK_SIBYL_SEARCH_RESPONSE_FILE="$FIX/sibyl-search-empty.json"
  run bash -c "echo '$(prompt_input "anything at all")' | bash $HOOK"
  [ "$status" -eq 0 ]
  ctx="$(echo "$output" | extract_ctx)"
  echo "$ctx" | grep -qE '⚠ Sibyl unreachable .* HTTP 500'
}

@test "fact text longer than 120 chars is truncated with ellipsis" {
  long_fix=$(mktemp)
  jq --arg t "$(printf 'x%.0s' {1..200})" '.results[0].text = $t' \
    "$FIX/sibyl-search-hits.json" > "$long_fix"
  export MOCK_SIBYL_SEARCH_RESPONSE_FILE="$long_fix"
  run bash -c "echo '$(prompt_input "any prompt longer than ten chars")' | bash $HOOK"
  [ "$status" -eq 0 ]
  ctx="$(echo "$output" | extract_ctx)"
  echo "$ctx" | grep -qE '1\. \[credibility 0\.91\] x{117,120}…'
  rm -f "$long_fix"
}
