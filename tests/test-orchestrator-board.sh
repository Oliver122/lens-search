#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

# The three old board scripts are gone; progress-board.sh is the sole owner.
test ! -f scripts/init-progress.sh
test ! -f scripts/set-progress-state.sh
test ! -f scripts/write-orchestration.sh
test -f scripts/progress-board.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
slug=board
make_feature_repo "$tmp/repo" "$slug"

install_test_agent "$tmp/bin"
install_test_verifier
export CURSOR_API_KEY=test-key

./scripts/run-orchestrator.sh "$slug"

# Single board: PROGRESS.md only, no ORCHESTRATION.md.
test ! -f ORCHESTRATION.md
test -f PROGRESS.md
grep -q '| 1 |' PROGRESS.md
grep -q '| 2 |' PROGRESS.md
while IFS='|' read -r _ num _ state _; do
  num="${num// /}"
  state="${state// /}"
  if [[ "$num" =~ ^[0-9]+$ ]]; then
    if [[ ! "$state" =~ ^(todo|in-progress|done|gap)$ ]]; then
      echo "bad board state: ${state}" >&2
      exit 1
    fi
  fi
done < PROGRESS.md

assert_eq "$(./scripts/progress-board.sh get "$slug" 1)" "done" "subtask 1 done on board"
assert_eq "$(./scripts/progress-board.sh get "$slug" 2)" "done" "subtask 2 done on board"

# Board is committed with the subtask (same commit), not left dirty.
assert_eq "$(git status --porcelain)" "" "clean tree after run"
