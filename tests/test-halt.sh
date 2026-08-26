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
echo t > "requirements/${slug}/specified-tests.md"
git add requirements
git commit -m req >/dev/null
git checkout -b "req/${slug}" >/dev/null

# Halt: missing-req exists -> openAutoFeature no-ops (no auto-feature branch)
git checkout -b "missing-req/${slug}" main >/dev/null
git checkout "req/${slug}" >/dev/null
out="$(./scripts/open-auto-feature.sh "$slug")"
echo "$out" | grep -q 'skip, missing-req'
assert_fail "no auto-feature branch after skip" git rev-parse --verify "auto-feature/${slug}"

# After missing-req is gone, empty dir fails
git branch -D "missing-req/${slug}" >/dev/null
git checkout -b "req/empty" main >/dev/null
mkdir -p requirements/empty
assert_fail "empty req" ./scripts/open-auto-feature.sh empty
