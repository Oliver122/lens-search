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

./scripts/open-auto-feature.sh "$slug" >/dev/null
echo extra >> README.md
git add README.md
git commit -m extra >/dev/null
extra="$(git rev-parse HEAD)"

out="$(./scripts/open-auto-feature.sh "$slug")"
echo "$out" | grep -q 'already CYCLE'
assert_eq "$(git rev-parse HEAD)" "$extra" "same CYCLE keeps auto-feature tip"

echo in2 > "requirements/${slug}/overview.md"
git checkout -B "req/${slug}" >/dev/null
git add requirements
git commit -m req2 >/dev/null
./scripts/open-auto-feature.sh "$slug" >/dev/null
if git merge-base --is-ancestor "$extra" HEAD; then
  echo "new CYCLE should not keep extra commit" >&2
  exit 1
fi
test -f "requirements/${slug}/CYCLE"
