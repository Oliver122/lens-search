#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

wf=.github/workflows/auto-feature.yml
grep -q 'open-auto-feature.sh' "$wf"
grep -q 'run-coder.sh' "$wf"
# Workflow still calls run-coder.sh; that script must hand off to the orchestrator.
grep -q 'run-orchestrator.sh' scripts/run-coder.sh
if grep -q 'coder-prompt.md' scripts/run-coder.sh; then
  echo "run-coder.sh must not be a whole-set coder" >&2
  exit 1
fi
open_line="$(grep -n 'open-auto-feature.sh' "$wf" | head -1 | cut -d: -f1)"
coder_line="$(grep -n 'run-coder.sh' "$wf" | head -1 | cut -d: -f1)"
if [[ "$coder_line" -le "$open_line" ]]; then
  echo "orchestrator (via run-coder.sh) must run after openAutoFeature" >&2
  exit 1
fi
