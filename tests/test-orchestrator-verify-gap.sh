#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
slug=gapper
make_feature_repo "$tmp/repo" "$slug"

install_test_agent "$tmp/bin"
install_test_verifier
export CURSOR_API_KEY=test-key
export ORCH_TRACE="$tmp/trace.txt"

# Subtask 1: red on both attempts → gap. Subtask 2: green → loop continued.
printf 'red\nred\ngreen\n' > "$tmp/plan.txt"
export FAKE_VERIFIER_PLAN="$tmp/plan.txt"

./scripts/run-orchestrator.sh "$slug"

# Two attempts for subtask 1, then the loop moved on to subtask 2.
assert_eq "$(grep -c '^START 1 ' "$ORCH_TRACE")" "2" "subtask 1 got 2 attempts"
assert_eq "$(grep -c '^START 2 ' "$ORCH_TRACE")" "1" "loop continued to subtask 2"

git checkout "auto-feature/${slug}" >/dev/null 2>&1
test -f GAPS.md
grep -q "First check for ${slug}" GAPS.md
assert_eq "$(./scripts/progress-board.sh get "$slug" 1)" "gap" "subtask 1 gap"
assert_eq "$(./scripts/progress-board.sh get "$slug" 2)" "done" "subtask 2 done"

# Unverified subtask-1 work was discarded; the suite-green subtask 2 landed.
test ! -f subtask-1.txt
assert_eq "$(cat subtask-2.txt)" "ok-2" "subtask 2 output present"
assert_eq "$(git status --porcelain)" "" "clean tree after run"
