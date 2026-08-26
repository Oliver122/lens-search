#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
slug=retry
make_feature_repo "$tmp/repo" "$slug"

install_test_agent "$tmp/bin"
install_test_verifier
export CURSOR_API_KEY=test-key
export ORCH_TRACE="$tmp/trace.txt"
export ORCH_PROMPT_DIR="$tmp/prompts"

# Subtask 1: red then green (retry succeeds). Subtask 2: green first try.
printf 'red\ngreen\ngreen\n' > "$tmp/plan.txt"
export FAKE_VERIFIER_PLAN="$tmp/plan.txt"

./scripts/run-orchestrator.sh "$slug"

# Subtask 1 got two attempts, subtask 2 one.
assert_eq "$(grep -c '^START 1 ' "$ORCH_TRACE")" "2" "subtask 1 retried once"
assert_eq "$(grep -c '^START 2 ' "$ORCH_TRACE")" "1" "subtask 2 not retried"

# The attempt-2 prompt contains the verify failure output.
grep -q 'FAKE-VERIFY-RED' "$ORCH_PROMPT_DIR/agent-prompt-1.txt"
grep -q 'previous attempt failed verification' "$ORCH_PROMPT_DIR/agent-prompt-1.txt"
if grep -q 'FAKE-VERIFY-RED' "$ORCH_PROMPT_DIR/agent-prompt-2.txt"; then
  echo "subtask 2 first-attempt prompt must not carry a failure log" >&2
  exit 1
fi

# Retry made the subtask green: done on the board, no gap.
assert_eq "$(./scripts/progress-board.sh get "$slug" 1)" "done" "subtask 1 done after retry"
test ! -f GAPS.md
