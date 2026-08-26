#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
slug=seq
make_feature_repo "$tmp/repo" "$slug"

install_test_agent "$tmp/bin"
install_test_verifier
export CURSOR_API_KEY=test-key
export ORCH_TRACE="$tmp/trace.txt"

./scripts/run-orchestrator.sh "$slug"

test -f "$ORCH_TRACE"
starts="$(grep -c '^START ' "$ORCH_TRACE")"
assert_eq "$starts" "2" "two subtask agents started"

# Sequential: subtask 1 ends before subtask 2 starts.
e1="$(grep -n '^END 1 ' "$ORCH_TRACE" | head -1 | cut -d: -f1)"
s2="$(grep -n '^START 2 ' "$ORCH_TRACE" | head -1 | cut -d: -f1)"
if [[ -z "$e1" || -z "$s2" || "$e1" -gt "$s2" ]]; then
  echo "subtask 1 did not end before subtask 2 started" >&2
  cat "$ORCH_TRACE" >&2
  exit 1
fi

# Both subtasks ran on the feature branch checkout itself, not worktrees.
feat_tree="$(git rev-parse --show-toplevel)"
t1="$(awk '/^START 1 /{print $3}' "$ORCH_TRACE")"
t2="$(awk '/^START 2 /{print $3}' "$ORCH_TRACE")"
assert_eq "$t1" "$feat_tree" "subtask 1 on primary checkout"
assert_eq "$t2" "$feat_tree" "subtask 2 on primary checkout"

# Accumulated result of both subtasks is on the feature branch.
git checkout "auto-feature/${slug}" >/dev/null 2>&1
assert_eq "$(cat subtask-1.txt)" "ok-1" "subtask 1 output present"
assert_eq "$(cat subtask-2.txt)" "ok-2" "subtask 2 output present"
