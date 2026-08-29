#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

grep -q 'CURSOR_API_KEY' "$ROOT/.github/workflows/auto-feature.yml"
grep -q 'install-cursor-cli.sh' "$ROOT/.github/workflows/auto-feature.yml"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=keycheck
git checkout -b "req/${slug}" >/dev/null
mkdir -p "requirements/${slug}"
echo in > "requirements/${slug}/overview.md"
echo "1. A check" > "requirements/${slug}/specified-tests.md"
git add requirements && git commit -m spec >/dev/null
./scripts/save-req-delta.sh "$slug" >/dev/null
./scripts/open-orchestrator.sh "$slug" >/dev/null
unset CURSOR_API_KEY || true
assert_fail "open-worker without key" ./scripts/open-worker.sh "$slug"
assert_fail "step-cycle worker without key" ./scripts/step-cycle.sh "$slug"
