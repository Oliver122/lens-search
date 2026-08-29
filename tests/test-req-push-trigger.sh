#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

wf=.github/workflows/auto-feature.yml
grep -q 'req/\*\*' "$wf"
grep -q 'step-cycle.sh' "$wf"
grep -q 'pull_request_review' "$wf"
grep -q 'schedule:' "$wf"
grep -q 'workflow_dispatch' "$wf"
if grep -q 'open-auto-feature.sh' "$wf"; then
  echo "workflow must wake step-cycle, not open-auto-feature" >&2
  exit 1
fi
if grep -q 'run-orchestrator.sh' "$wf"; then
  echo "workflow must not call run-orchestrator" >&2
  exit 1
fi

got="$(./scripts/slug-from-ref.sh req/my-feature)"
assert_eq "$got" "my-feature" "slug-from-ref req"

if grep -R --include='*.sh' --include='*.yml' -n 'pr merge --auto' scripts .github; then
  echo "found gh pr merge --auto" >&2
  exit 1
fi
if grep -R --include='*.yml' -n 'enableAutoMerge' .github; then
  echo "found enableAutoMerge" >&2
  exit 1
fi
