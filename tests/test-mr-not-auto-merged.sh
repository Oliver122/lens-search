#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

grep -q 'disable-auto' scripts/open-requirement-pr.sh
grep -q 'autoMergeRequest' scripts/open-requirement-pr.sh
if grep -R --include='*.sh' --include='*.yml' -n 'pr merge --auto' scripts .github; then
  echo "found gh pr merge --auto" >&2
  exit 1
fi
if grep -R --include='*.yml' -n 'enableAutoMerge' .github; then
  echo "found enableAutoMerge" >&2
  exit 1
fi
if grep -q 'open-auto-feature.sh' .github/workflows/auto-feature.yml; then
  echo "requirement PR is opened by step-cycle, not open-auto-feature" >&2
  exit 1
fi
