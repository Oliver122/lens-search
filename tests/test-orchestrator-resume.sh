#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
slug=resume
make_feature_repo "$tmp/repo" "$slug"

install_test_agent "$tmp/bin"
install_test_verifier
export CURSOR_API_KEY=test-key
export ORCH_TRACE="$tmp/trace.txt"

# Pre-seed the board as a previous run would have left it: subtask 1 done, committed.
./scripts/progress-board.sh init "$slug"
./scripts/progress-board.sh set "$slug" 1 done
git add PROGRESS.md
git commit -m "orchestrator(${slug}): board" >/dev/null

./scripts/run-orchestrator.sh "$slug"

# Done rows are skipped; only subtask 2 ran.
if grep -q '^START 1 ' "$ORCH_TRACE"; then
  echo "resume must not re-run a done subtask" >&2
  cat "$ORCH_TRACE" >&2
  exit 1
fi
assert_eq "$(grep -c '^START 2 ' "$ORCH_TRACE")" "1" "subtask 2 ran"

git checkout "auto-feature/${slug}" >/dev/null 2>&1
assert_eq "$(./scripts/progress-board.sh get "$slug" 1)" "done" "subtask 1 stayed done"
assert_eq "$(./scripts/progress-board.sh get "$slug" 2)" "done" "subtask 2 done"
test ! -f subtask-1.txt
assert_eq "$(cat subtask-2.txt)" "ok-2" "subtask 2 output present"
