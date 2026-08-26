#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

wf=.github/workflows/auto-feature.yml
grep -q 'open-auto-feature.sh' "$wf"
# The Coder step calls the orchestrator directly; run-coder.sh is gone.
grep -q 'run-orchestrator.sh' "$wf"
if grep -q 'run-coder.sh' "$wf"; then
  echo "workflow must not reference the deleted run-coder.sh" >&2
  exit 1
fi
test ! -f scripts/run-coder.sh
test ! -f scripts/merge-subtask-worktree.sh
# Missing-req defaults moved from run-coder.sh into the workflow step.
grep -q 'OPEN_MISSING_REQ_PUSH' "$wf"
grep -q 'OPEN_MISSING_REQ_COMMENT' "$wf"

open_line="$(grep -n 'open-auto-feature.sh' "$wf" | head -1 | cut -d: -f1)"
orch_line="$(grep -n 'run-orchestrator.sh' "$wf" | head -1 | cut -d: -f1)"
if [[ "$orch_line" -le "$open_line" ]]; then
  echo "orchestrator must run after openAutoFeature" >&2
  exit 1
fi
