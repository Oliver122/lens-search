#!/usr/bin/env bash
# Write repo-root PROGRESS.md from specified-tests.md. Does not touch CYCLE.
# Existing rows keep their state when the test text still matches.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
tests="${root}/requirements/${slug}/specified-tests.md"
out="${root}/PROGRESS.md"

if [[ ! -f "$tests" ]]; then
  echo "init-progress: missing ${tests}" >&2
  exit 1
fi

declare -A old_state=()
if [[ -f "$out" ]]; then
  while IFS='|' read -r _ num text state _; do
    num="${num// /}"
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    state="${state// /}"
    if [[ "$num" =~ ^[0-9]+$ && "$state" =~ ^(todo|in-progress|done|blocked|gap)$ ]]; then
      old_state["${num}|${text}"]="$state"
    fi
  done < "$out"
fi

{
  echo "# Progress — ${slug}"
  echo
  echo "States: \`todo\` | \`in-progress\` | \`done\` | \`blocked\` | \`gap\`"
  echo
  echo "Live board on \`auto-feature/${slug}\`. Do not edit \`requirements/${slug}/\` to record status."
  echo
  echo "| # | specified test | state |"
  echo "|---|---|---|"
  n=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9]+)\.\ \[([^]]+)\][[:space:]]+(.*)$ ]]; then
      n="${BASH_REMATCH[1]}"
      text="${BASH_REMATCH[3]}"
    elif [[ "$line" =~ ^([0-9]+)\.\ (.+)$ ]]; then
      n="${BASH_REMATCH[1]}"
      text="${BASH_REMATCH[2]}"
    else
      continue
    fi
    key="${n}|${text}"
    state="${old_state[$key]:-todo}"
    printf '| %s | %s | %s |\n' "$n" "$text" "$state"
  done < "$tests"
} > "$out"

echo "init-progress: wrote ${out}"
