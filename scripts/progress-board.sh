#!/usr/bin/env bash
# Sole owner of the repo-root PROGRESS.md board. Does not touch CYCLE.
# Usage:
#   progress-board.sh init <slug>              write board from specified-tests.md;
#                                              rows keep their state when the test
#                                              text still matches (resume support)
#   progress-board.sh set <slug> <n> <state>   states: todo|in-progress|done|gap
#   progress-board.sh get <slug> <n>           print the row's state
set -euo pipefail

cmd="${1:?command required: init|set|get}"
slug="${2:?slug required}"
root="$(git rev-parse --show-toplevel)"
out="${root}/PROGRESS.md"
split="${root}/scripts/split-specified-tests.sh"

if [[ ! -f "${root}/requirements/${slug}/specified-tests.md" ]]; then
  echo "progress-board: missing requirements/${slug}/specified-tests.md" >&2
  exit 1
fi

declare -A row_state=()
load_board() {
  [[ -f "$out" ]] || return 0
  while IFS='|' read -r _ num text state _; do
    num="${num// /}"
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    state="${state// /}"
    if [[ "$num" =~ ^[0-9]+$ && "$state" =~ ^(todo|in-progress|done|gap)$ ]]; then
      row_state["${num}|${text}"]="$state"
    fi
  done < "$out"
}

write_board() {
  {
    echo "# Progress — ${slug}"
    echo
    echo "States: \`todo\` | \`in-progress\` | \`done\` | \`gap\`"
    echo
    echo "Live board on \`auto-feature/${slug}\`. Do not edit \`requirements/${slug}/\` to record status."
    echo
    echo "| # | specified test | state |"
    echo "|---|---|---|"
    while IFS=$'\t' read -r num text; do
      printf '| %s | %s | %s |\n' "$num" "$text" "${row_state["${num}|${text}"]:-todo}"
    done < <("$split" "$slug")
  } > "$out"
}

case "$cmd" in
  init)
    load_board
    write_board
    ;;
  set)
    n="${3:?number required}"
    new_state="${4:?state required}"
    if [[ ! "$new_state" =~ ^(todo|in-progress|done|gap)$ ]]; then
      echo "progress-board: invalid state ${new_state}" >&2
      exit 1
    fi
    load_board
    found=0
    while IFS=$'\t' read -r num text; do
      if [[ "$num" == "$n" ]]; then
        row_state["${num}|${text}"]="$new_state"
        found=1
      fi
    done < <("$split" "$slug")
    if [[ "$found" -ne 1 ]]; then
      echo "progress-board: no specified test ${n}" >&2
      exit 1
    fi
    write_board
    ;;
  get)
    n="${3:?number required}"
    if [[ ! -f "$out" ]]; then
      echo "progress-board: missing ${out}; run init first" >&2
      exit 1
    fi
    load_board
    while IFS=$'\t' read -r num text; do
      if [[ "$num" == "$n" ]]; then
        state="${row_state["${num}|${text}"]:-}"
        if [[ -z "$state" ]]; then
          echo "progress-board: row ${n} not on board; run init first" >&2
          exit 1
        fi
        echo "$state"
        exit 0
      fi
    done < <("$split" "$slug")
    echo "progress-board: no specified test ${n}" >&2
    exit 1
    ;;
  *)
    echo "progress-board: unknown command ${cmd}" >&2
    exit 1
    ;;
esac
