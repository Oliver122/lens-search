#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

slug=splitme
git checkout -b "req/${slug}" >/dev/null
mkdir -p "requirements/${slug}"
echo in > "requirements/${slug}/overview.md"
cat > "requirements/${slug}/specified-tests.md" <<'EOF'
# tests
1. First observable check
2. Second observable check
3. Third observable check
EOF
git add requirements && git commit -m spec >/dev/null

./scripts/save-req-delta.sh "$slug" >/dev/null
./scripts/open-orchestrator.sh "$slug"

git rev-parse --verify "orchestrator/${slug}" >/dev/null
git checkout "orchestrator/${slug}" >/dev/null
test -f "requirements/${slug}/CYCLE"
test -f "requirements/${slug}/specified-tests.md"
hash="$(./scripts/cycle-hash.sh "$slug")"
assert_eq "$(cat "requirements/${slug}/CYCLE")" "$hash" "CYCLE on orch"

rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q "| orch | orchestrator/${slug} |"
echo "$rec" | grep -q '| 1 | First observable check | pending |'
echo "$rec" | grep -q '| 2 | Second observable check | pending |'
echo "$rec" | grep -q '| 3 | Third observable check | pending |'

slug_def=withdef
git checkout main >/dev/null
git checkout -b "req/${slug_def}" >/dev/null
mkdir -p "requirements/${slug_def}" requirements/_defs
cat > "requirements/${slug_def}/overview.md" <<'EOF'
## Catalog

### group

demo

### slices

backend

### defs

hook-shape
EOF
echo "1. [backend] First check" > "requirements/${slug_def}/specified-tests.md"
echo '# hook-shape' > requirements/_defs/hook-shape.md
git add requirements && git commit -m withdef >/dev/null
./scripts/save-req-delta.sh "$slug_def" >/dev/null
./scripts/open-orchestrator.sh "$slug_def"
git checkout "orchestrator/${slug_def}" >/dev/null
test -f requirements/_defs/hook-shape.md

slug1=one
git checkout main >/dev/null
mkdir -p "requirements/${slug1}"
echo in > "requirements/${slug1}/overview.md"
echo "1. Only one check" > "requirements/${slug1}/specified-tests.md"
git add requirements && git commit -m one >/dev/null
git checkout -b "req/${slug1}" >/dev/null
./scripts/save-req-delta.sh "$slug1" >/dev/null
./scripts/open-orchestrator.sh "$slug1"
rec1="$(./scripts/cycle-record.sh load "$slug1")"
echo "$rec1" | grep -q '| 1 | Only one check | pending |'
if echo "$rec1" | grep -q '| 2 |'; then
  echo "single test must yield one subtask" >&2
  exit 1
fi

slug0=thin
git checkout main >/dev/null
mkdir -p "requirements/${slug0}"
echo in > "requirements/${slug0}/overview.md"
echo "no numbered tests" > "requirements/${slug0}/specified-tests.md"
git add requirements && git commit -m thin >/dev/null
git checkout -b "req/${slug0}" >/dev/null
./scripts/save-req-delta.sh "$slug0" >/dev/null
./scripts/open-orchestrator.sh "$slug0"
rec0="$(./scripts/cycle-record.sh load "$slug0")"
echo "$rec0" | grep -q "| orch | orchestrator/${slug0} |"
if echo "$rec0" | grep -E -q '\| [0-9]+ \|'; then
  echo "thin spec must have no subtask rows" >&2
  exit 1
fi
