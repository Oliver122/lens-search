#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

grep -q 'CURSOR_API_KEY' "$ROOT/.github/workflows/auto-feature.yml"
grep -q 'install-cursor-cli.sh' "$ROOT/.github/workflows/auto-feature.yml"
grep -q 'install-cursor-cli.sh' "$ROOT/.github/workflows/auto-fix.yml"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
slug=keycheck
make_feature_repo "$tmp/repo" "$slug"

unset CURSOR_API_KEY AGENT_BIN || true
assert_fail "subtask coder without key" ./scripts/run-subtask-coder.sh "$slug" 1
# The coder is the sole owner of the env checks; its env exit must abort the
# orchestrator (not be counted as a red attempt).
assert_fail "orchestrator without key" ./scripts/run-orchestrator.sh "$slug"
