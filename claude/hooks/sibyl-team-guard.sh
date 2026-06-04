#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

deny() {
  reason=$1
  jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

if [ -z "$cwd" ]; then
  deny "sibyl-team-guard: could not determine cwd from hook input; refusing memory_save. Add a .sibyl-team marker to the project if it belongs in the shared pool."
fi

dir=$cwd
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
  if [ -e "$dir/.sibyl-team" ]; then
    exit 0
  fi
  dir=$(dirname "$dir")
done

deny "sibyl-team-guard: '$cwd' is not under a .sibyl-team-marked project, so this memory_save was blocked to keep non-team facts out of the shared pool. If this project should write to shared memory, drop an empty .sibyl-team file at its root."
