#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
git -C "$tmp/repo" clone --bare "$tmp/repo" "$tmp/bare.git" >/dev/null
git -C "$tmp/repo" remote add origin "$tmp/bare.git"
git -C "$tmp/repo" push -u origin main >/dev/null

cd "$tmp/repo"
slug=repush
git checkout -b "req/${slug}" >/dev/null
mkdir -p "requirements/${slug}"
echo in > "requirements/${slug}/overview.md"
echo t1 > "requirements/${slug}/specified-tests.md"
git add requirements && git commit -m spec1 >/dev/null

OPEN_AUTO_FEATURE_PUSH=1 ./scripts/open-auto-feature.sh "$slug"
git -C "$tmp/bare.git" rev-parse --verify "auto-feature/${slug}" >/dev/null

# New CYCLE must replace the remote branch (the CI failure mode).
git checkout "req/${slug}" >/dev/null
echo t2 > "requirements/${slug}/specified-tests.md"
git add requirements && git commit -m spec2 >/dev/null
OPEN_AUTO_FEATURE_PUSH=1 ./scripts/open-auto-feature.sh "$slug"

hash="$(./scripts/cycle-hash.sh "$slug")"
got="$(git -C "$tmp/bare.git" show "auto-feature/${slug}:requirements/${slug}/CYCLE" | tr -d '\r\n')"
assert_eq "$got" "$hash" "remote CYCLE after non-ff replace"
grep -q 'force-with-lease' "$ROOT/scripts/open-auto-feature.sh"
grep -q -- '--no-track' "$ROOT/scripts/open-auto-feature.sh"
