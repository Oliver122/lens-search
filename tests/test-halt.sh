#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

slug=widget
mkdir -p "requirements/${slug}"
echo in > "requirements/${slug}/overview.md"
echo "1. A check" > "requirements/${slug}/specified-tests.md"
git add requirements
git commit -m req >/dev/null
git checkout -b "req/${slug}" >/dev/null

git checkout -b "missing-req/${slug}" main >/dev/null
git checkout "req/${slug}" >/dev/null
./scripts/step-cycle.sh "$slug"
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| incomplete |'
assert_fail "no orch while missing-req open" git rev-parse --verify "orchestrator/${slug}"
assert_fail "no worker while missing-req open" git rev-parse --verify "worker/${slug}/1-1"

git checkout main >/dev/null
git checkout -b "req/empty" >/dev/null
mkdir -p requirements/empty
./scripts/step-cycle.sh empty
rec="$(./scripts/cycle-record.sh load empty)"
echo "$rec" | grep -q '| incomplete |'
git rev-parse --verify "missing-req/empty" >/dev/null
