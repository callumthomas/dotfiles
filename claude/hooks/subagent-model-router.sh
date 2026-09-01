#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
table="$HOME/.claude/hooks/subagent-model-routing.json"

tool=$(jq -r '.tool_name // empty' <<<"$input")
if [[ "$tool" != "Agent" && "$tool" != "Task" ]]; then
  exit 0
fi

explicit=$(jq -r '.tool_input.model // empty' <<<"$input")
if [[ -n "$explicit" ]]; then
  exit 0
fi

if [[ ! -f "$table" ]]; then
  exit 0
fi

stype=$(jq -r '.tool_input.subagent_type // empty' <<<"$input")
model=$(jq -r --arg t "$stype" '.routes[$t] // .routes["*"] // empty' "$table")

if [[ -n "$model" ]]; then
  jq -c --arg m "$model" '{hookSpecificOutput: {hookEventName: "PreToolUse", updatedInput: (.tool_input + {model: $m})}}' <<<"$input"
fi

exit 0
