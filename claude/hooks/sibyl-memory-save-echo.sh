#!/usr/bin/env bash
# PostToolUse hook — surfaces sibyl write ops as inline systemMessage so
# the user sees every save/pin/unpin/correct/invalidate as it happens.
#
# Reads PostToolUse stdin JSON shaped as:
#   { tool_name, tool_input, tool_response: [{type: "text", text: "<json>"}],
#     tool_response_is_error?: bool, ... }
#
# tool_response is consistently an array of MCP content blocks. The inner
# JSON envelope is at .tool_response[0].text and looks like:
#   {"operation_id": "...", "processing_state": "completed",
#    "result": {...}, "warnings": [], "degraded": []}
# or, for failures, a plain error string.
set -uo pipefail

INPUT="$(cat)"
TOOL="$(echo "$INPUT" | jq -r '.tool_name // empty')"
INP="$(echo "$INPUT"  | jq -c '.tool_input    // {}')"
RESP_TEXT="$(echo "$INPUT" | jq -r '.tool_response // [] | if type == "array" then (.[0].text // "") else (. | tostring) end')"
IS_ERROR="$(echo "$INPUT" | jq -r '.tool_response_is_error // false')"

# Try to parse the response text as JSON; if it isn't, treat the raw text
# as the error message.
RESP_JSON="$(echo "$RESP_TEXT" | jq -c '.' 2>/dev/null || echo "null")"

short_op() {
  case "$1" in
    mcp__sibyl__memory_save)        echo "save" ;;
    mcp__sibyl__memory_pin)         echo "pin" ;;
    mcp__sibyl__memory_unpin)       echo "unpin" ;;
    mcp__sibyl__memory_correct)     echo "correct" ;;
    mcp__sibyl__memory_invalidate)  echo "invalidate" ;;
    *) echo "" ;;
  esac
}

OP="$(short_op "$TOOL")"
[ -z "$OP" ] && exit 0

emit() {
  jq -n --arg m "$1" '{systemMessage: $m}'
}

truncate200() {
  python3 -c 'import sys; s=sys.stdin.read(); print(s[:200]+("…" if len(s)>200 else ""), end="")'
}

# Error path: explicit isError flag, or response text that didn't parse as JSON.
if [ "$IS_ERROR" = "true" ] || [ "$RESP_JSON" = "null" ]; then
  ERR="$RESP_TEXT"
  [ -z "$ERR" ] && ERR="unknown error"
  emit "⚠ sibyl ${OP} failed: ${ERR}"
  exit 0
fi

case "$OP" in
  save)
    CONTENT="$(echo "$INP" | jq -r '.content // ""' | truncate200)"
    WAIT="$(echo "$INP" | jq -r '.wait // "none"')"
    OPID="$(echo "$RESP_JSON" | jq -r '.operation_id // "unknown"')"
    emit "💾 sibyl saved: \"${CONTENT}\" (op ${OPID}, wait=${WAIT})"
    ;;
  pin|unpin)
    FUUID="$(echo "$INP" | jq -r '.fact_uuid // ""')"
    ICON=$([ "$OP" = "pin" ] && echo "📌" || echo "📍")
    VERB=$([ "$OP" = "pin" ] && echo "pinned" || echo "unpinned")
    emit "${ICON} sibyl ${VERB} fact ${FUUID}"
    ;;
  correct)
    FUUID="$(echo "$INP" | jq -r '.old_fact_uuid // ""')"
    NEW="$(echo "$INP" | jq -r '.new_content // ""' | truncate200)"
    emit "✏ sibyl corrected fact ${FUUID}: \"${NEW}\""
    ;;
  invalidate)
    FUUID="$(echo "$INP" | jq -r '.fact_uuid // ""')"
    REASON="$(echo "$INP" | jq -r '.reason // ""' | truncate200)"
    emit "🗑 sibyl invalidated fact ${FUUID}: \"${REASON}\""
    ;;
esac
