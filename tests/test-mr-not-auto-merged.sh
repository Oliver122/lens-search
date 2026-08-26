#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

# Workflow opens/updates MR and disables auto-merge
grep -q 'OPEN_AUTO_FEATURE_MR' .github/workflows/auto-feature.yml
grep -q 'disable-auto' scripts/open-auto-feature.sh
grep -q 'autoMergeRequest' scripts/open-auto-feature.sh

# auto-fix hangs off feature only, same MR merge
grep -q 'auto-feature/\*\*' .github/workflows/auto-fix.yml
grep -q 'GAPS.md' .github/workflows/auto-fix.yml
grep -q 'merge-auto-fix.sh' .github/workflows/auto-fix.yml
grep -q 'already exists' scripts/open-auto-fix.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=lens
git checkout -b "req/${slug}" >/dev/null
mkdir -p "requirements/${slug}"
echo in > "requirements/${slug}/overview.md"
echo t > "requirements/${slug}/specified-tests.md"
git add requirements && git commit -m spec >/dev/null
./scripts/open-auto-feature.sh "$slug"
git checkout "auto-feature/${slug}" >/dev/null
echo 'unmet specified test' > GAPS.md
git add GAPS.md && git commit -m gaps >/dev/null

./scripts/open-auto-fix.sh "$slug"
git rev-parse --verify "auto-fix/${slug}" >/dev/null
assert_fail "second auto-fix" ./scripts/open-auto-fix.sh "$slug"

# merge back into feature
echo patched >> README.md
git add README.md && git commit -m harden >/dev/null
./scripts/merge-auto-fix.sh "$slug"
git checkout "auto-feature/${slug}" >/dev/null
git log -1 --oneline | grep -q "merge auto-fix"
assert_fail "fix branch gone" git rev-parse --verify "auto-fix/${slug}"
