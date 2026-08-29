#!/usr/bin/env bash
# Set one PROGRESS.md row state. Does not touch CYCLE.
set -euo pipefail

slug="${1:?slug required}"
n="${2:?number required}"
new_state="${3:?state required}"
if [[ ! "$new_state" =~ ^(todo|in-progress|done|blocked|gap)$ ]]; then
  echo "set-progress-state: invalid state" >&2
  exit 1
fi

root="$(git rev-parse --show-toplevel)"
out="${root}/PROGRESS.md"

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

while IFS= read -r row; do
  num="${row%%$'\t'*}"
  rest="${row#*$'\t'}"
  text="${rest#*$'\t'}"
  if [[ "$num" == "$n" ]]; then
    old_state["${num}|${text}"]="$new_state"
  fi
done < <("${root}/scripts/split-specified-tests.sh" "$slug")

# Re-run init-progress after seeding old_state via rewriting the file first.
{
  echo "# Progress — ${slug}"
  echo
  echo "States: \`todo\` | \`in-progress\` | \`done\` | \`blocked\` | \`gap\`"
  echo
  echo "Live board on \`auto-feature/${slug}\`. Do not edit \`requirements/${slug}/\` to record status."
  echo
  echo "| # | specified test | state |"
  echo "|---|---|---|"
  while IFS= read -r row; do
    num="${row%%$'\t'*}"
    rest="${row#*$'\t'}"
    text="${rest#*$'\t'}"
    key="${num}|${text}"
    state="${old_state[$key]:-todo}"
    printf '| %s | %s | %s |\n' "$num" "$text" "$state"
  done < <("${root}/scripts/split-specified-tests.sh" "$slug")
} > "$out"
