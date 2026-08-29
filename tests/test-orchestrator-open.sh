#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

wf=.github/workflows/auto-feature.yml
grep -q 'step-cycle.sh' "$wf"
if grep -q 'run-coder.sh' "$wf"; then
  echo "workflow must not call run-coder.sh" >&2
  exit 1
fi
if grep -q 'run-orchestrator.sh' "$wf"; then
  echo "workflow must not call run-orchestrator.sh" >&2
  exit 1
fi
grep -q 'pull_request_review' "$wf"
grep -q 'schedule:' "$wf"
