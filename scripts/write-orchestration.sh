#!/usr/bin/env bash
# Write or update repo-root ORCHESTRATION.md. Does not touch CYCLE.
# Usage: write-orchestration.sh <slug> [n state]
#   no extra args: init all subtasks as running (keep existing states when text matches)
#   n state: set that subtask's state (running|done|blocked)
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
out="${root}/ORCHESTRATION.md"
split="${root}/scripts/split-specified-tests.sh"

declare -A old_state=()
if [[ -f "$out" ]]; then
  while IFS='|' read -r _ num text state _; do
    num="${num// /}"
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    state="${state// /}"
    if [[ "$num" =~ ^[0-9]+$ && "$state" =~ ^(running|done|blocked)$ ]]; then
      old_state["${num}|${text}"]="$state"
    fi
  done < "$out"
fi

if [[ $# -ge 3 ]]; then
  n="$2"
  new_state="$3"
  if [[ ! "$new_state" =~ ^(running|done|blocked)$ ]]; then
    echo "write-orchestration: state must be running|done|blocked" >&2
    exit 1
  fi
  while IFS= read -r row; do
    num="${row%%$'\t'*}"
    rest="${row#*$'\t'}"
    text="${rest#*$'\t'}"
    [[ "$num" == "$n" ]] || continue
    old_state["${num}|${text}"]="$new_state"
  done < <("$split" "$slug")
fi

{
  echo "# Orchestration — ${slug}"
  echo
  echo "Subtasks from \`requirements/${slug}/specified-tests.md\`. States: \`running\` | \`done\` | \`blocked\`."
  echo
  echo "Live board on \`auto-feature/${slug}\`. Do not edit \`requirements/${slug}/\` to record status."
  echo
  echo "| # | subtask | state |"
  echo "|---|---|---|"
  while IFS= read -r row; do
    num="${row%%$'\t'*}"
    rest="${row#*$'\t'}"
    text="${rest#*$'\t'}"
    key="${num}|${text}"
    state="${old_state[$key]:-running}"
    printf '| %s | %s | %s |\n' "$num" "$text" "$state"
  done < <("$split" "$slug")
} > "$out"

echo "write-orchestration: wrote ${out}"
