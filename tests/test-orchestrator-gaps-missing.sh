#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

wf=.github/workflows/auto-feature.yml
grep -q 'GAPS.md' "$wf"
grep -q 'open-auto-fix.sh' "$wf"
grep -q 'run-hardener.sh' "$wf"
grep -q 'merge-auto-fix.sh' "$wf"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

mkdir -p "$tmp/bin"
cp "$ROOT/tests/fake-agent.sh" "$tmp/bin/agent"
chmod +x "$tmp/bin/agent"
export PATH="${tmp/bin}:${PATH}"
export AGENT_BIN="$tmp/bin/agent"
export CURSOR_API_KEY=test-key

# Thin spec (no numbered tests) opens missing-req with MISSING.md only
slug=thin
mkdir -p "requirements/${slug}"
echo overview > "requirements/${slug}/overview.md"
echo "no numbered items here" > "requirements/${slug}/specified-tests.md"
git add requirements && git commit -m spec >/dev/null
git checkout -b "req/${slug}" >/dev/null
./scripts/open-auto-feature.sh "$slug" >/dev/null
./scripts/run-orchestrator.sh "$slug"
git rev-parse --verify "missing-req/${slug}" >/dev/null
git checkout "missing-req/${slug}" >/dev/null
test -f MISSING.md
files="$(git ls-files)"
assert_eq "$files" "MISSING.md" "missing-req only MISSING.md"
"$ROOT/scripts/missing-req-file-policy.sh" "missing-req/${slug}" MISSING.md
