#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

grep -q 'workflow_dispatch' .github/workflows/missing-req.yml
grep -q 'open-missing-req.sh' .github/workflows/missing-req.yml

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

./scripts/open-missing-req.sh demo "need bounds"
git rev-parse --verify missing-req/demo >/dev/null
test -f MISSING.md
files="$(git ls-files)"
assert_eq "$files" "MISSING.md" "missing-req only MISSING.md"
"$ROOT/scripts/missing-req-file-policy.sh" missing-req/demo MISSING.md
