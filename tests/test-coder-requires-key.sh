#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

grep -q 'CURSOR_API_KEY' "$ROOT/.github/workflows/auto-feature.yml"
grep -q 'install-cursor-cli.sh' "$ROOT/.github/workflows/auto-feature.yml"
grep -q 'install-cursor-cli.sh' "$ROOT/.github/workflows/auto-fix.yml"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=keycheck
git checkout -b "req/${slug}" >/dev/null
mkdir -p "requirements/${slug}"
echo in > "requirements/${slug}/overview.md"
echo t > "requirements/${slug}/specified-tests.md"
git add requirements && git commit -m spec >/dev/null
./scripts/open-auto-feature.sh "$slug"
unset CURSOR_API_KEY || true
assert_fail "coder without key" ./scripts/run-coder.sh "$slug"
