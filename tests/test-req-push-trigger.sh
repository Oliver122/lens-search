#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

wf=.github/workflows/auto-feature.yml
grep -q 'req/\*\*' "$wf"
grep -q 'open-auto-feature.sh' "$wf"
# Trigger is req/*, not auto-feature push for opening the cycle
if grep -A2 '^on:' "$wf" | grep -q 'auto-feature'; then
  echo "auto-feature workflow must trigger on req/* only" >&2
  exit 1
fi

# Slug from req ref
got="$(./scripts/slug-from-ref.sh req/my-feature)"
assert_eq "$got" "my-feature" "slug-from-ref req"

if grep -R --include='*.sh' --include='*.yml' -n 'pr merge --auto' scripts .github; then
  echo "found gh pr merge --auto" >&2
  exit 1
fi
if grep -R --include='*.yml' -n 'enableAutoMerge' .github; then
  echo "found enableAutoMerge" >&2
  exit 1
fi

# End-to-end CYCLE on req-like tree
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=cam
git checkout -b "req/${slug}" >/dev/null
mkdir -p "requirements/${slug}"
echo in > "requirements/${slug}/overview.md"
echo t > "requirements/${slug}/specified-tests.md"
git add requirements
git commit -m spec >/dev/null

./scripts/open-auto-feature.sh "$slug"
git rev-parse --verify "auto-feature/${slug}" >/dev/null
test -f "requirements/${slug}/CYCLE"
hash="$(./scripts/cycle-hash.sh "$slug")"
assert_eq "$(cat "requirements/${slug}/CYCLE")" "$hash" "CYCLE matches tree hash"
