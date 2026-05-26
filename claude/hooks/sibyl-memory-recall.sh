#!/usr/bin/env bash
# UserPromptSubmit hook — searches sibyl team memory and injects relevant
# facts into the prompt context. Designed to fail-visible: when sibyl is
# unreachable the model is told so explicitly and instructed not to attempt
# memory_save this turn.
#
# Test hooks (set in CI / bats fixtures only):
#   MOCK_SIBYL_SEARCH_RESPONSE_FILE  — path to a JSON file used in place of
#                                       a live POST to /memory/search
#   MOCK_SIBYL_CURL_EXIT             — non-zero forces the unreachable path
#   MOCK_SIBYL_HTTP_STATUS           — overrides the HTTP status check
set -uo pipefail

SIBYL_URL="${SIBYL_URL:-http://127.0.0.1:8080}"
SIBYL_TOKEN="${SIBYL_WRITER_TOKEN:-a2db865eac7c681f9a66a644b194258721916f47897611ec8a4037413d2710f7}"
SIBYL_USER_ID="${SIBYL_USER_ID:-cal@local}"
MAX_FACTS="${MAX_FACTS:-5}"
SHOW_FACTS="${SHOW_FACTS:-3}"
TIMEOUT_S="${TIMEOUT_S:-8}"
TRUNCATE_CHARS="${TRUNCATE_CHARS:-120}"

INPUT="$(cat)"
PROMPT="$(echo "$INPUT" | jq -r '.prompt // empty')"

# Skip empty / too-short / slash-command prompts.
if [ -z "$PROMPT" ] || [ "${#PROMPT}" -lt 10 ] || [[ "$PROMPT" == /* ]]; then
  exit 0
fi

START_NS="$(date +%s%N)"

if [ -n "${MOCK_SIBYL_CURL_EXIT:-}" ]; then
  CURL_EXIT="$MOCK_SIBYL_CURL_EXIT"
  HTTP_STATUS=0
  BODY=""
elif [ -n "${MOCK_SIBYL_SEARCH_RESPONSE_FILE:-}" ]; then
  CURL_EXIT=0
  HTTP_STATUS="${MOCK_SIBYL_HTTP_STATUS:-200}"
  BODY="$(cat "$MOCK_SIBYL_SEARCH_RESPONSE_FILE")"
else
  REQ_BODY="$(jq -n --arg q "$PROMPT" --argjson n "$MAX_FACTS" \
    '{query: $q, top_k: $n, rerank: false}')"
  HTTP_TMP="$(mktemp)"
  HTTP_STATUS="$(curl -s --max-time "$TIMEOUT_S" \
    -o "$HTTP_TMP" -w '%{http_code}' \
    -X POST "$SIBYL_URL/memory/search" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SIBYL_TOKEN" \
    -H "x-user-id: $SIBYL_USER_ID" \
    -d "$REQ_BODY" 2>/dev/null)"
  CURL_EXIT=$?
  BODY="$(cat "$HTTP_TMP")"
  rm -f "$HTTP_TMP"
fi

ELAPSED_MS=$(( ($(date +%s%N) - START_NS) / 1000000 ))

emit_ctx() {
  jq -n --arg ctx "$1" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
}

if [ "$CURL_EXIT" -ne 0 ] || { [ "$HTTP_STATUS" -lt 200 ] || [ "$HTTP_STATUS" -ge 300 ]; }; then
  WARN="⚠ Sibyl unreachable (curl exit ${CURL_EXIT} / HTTP ${HTTP_STATUS}) — memory disabled this turn. Do not call memory_save."
  emit_ctx "${WARN}

[memory lookup took ${ELAPSED_MS}ms — end your reply to the user with this timing in brackets]"
  exit 0
fi

TOTAL="$(echo "$BODY" | jq -r '.results | length // 0')"

if [ "$TOTAL" -eq 0 ]; then
  emit_ctx "(no relevant team memories)

[memory lookup took ${ELAPSED_MS}ms — end your reply to the user with this timing in brackets]"
  exit 0
fi

SHOWN=$(( TOTAL < SHOW_FACTS ? TOTAL : SHOW_FACTS ))

FACTS_LINES="$(echo "$BODY" | jq -r --argjson n "$SHOWN" --argjson w "$TRUNCATE_CHARS" '
  .results[0:$n] | to_entries[] |
  "\(.key+1). [credibility \(.value.credibility // 0 | tostring | .[0:4])] " +
  ( .value.text | if length > $w then .[0:$w] + "…" else . end )
')"

CTX="Relevant team memories (${SHOWN} of ${TOTAL} hits, lookup ${ELAPSED_MS}ms):
${FACTS_LINES}

[memory lookup took ${ELAPSED_MS}ms — end your reply to the user with this timing in brackets]"

emit_ctx "$CTX"
