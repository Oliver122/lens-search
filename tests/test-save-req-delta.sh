#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=cam

git checkout -b "req/${slug}" >/dev/null
mkdir -p "requirements/${slug}" requirements/_defs
cat > "requirements/${slug}/overview.md" <<'EOF'
overview-body

## Catalog

### group

demo

### slices

backend

### defs

hook-shape
EOF
echo "1. First check" > "requirements/${slug}/specified-tests.md"
echo unique-def-body > requirements/_defs/hook-shape.md
git add requirements && git commit -m spec >/dev/null

./scripts/save-req-delta.sh "$slug"

git checkout "cycle/${slug}" >/dev/null
test -f DELTA.md
grep -q 'overview-body' DELTA.md
grep -q 'First check' DELTA.md
grep -q 'unique-def-body' DELTA.md
# delta only: not a dump of scripts/ or README
if grep -q '^diff --git a/README.md' DELTA.md; then
  echo "delta must not include README.md" >&2
  exit 1
fi
if grep -q '^diff --git a/scripts/' DELTA.md; then
  echo "delta must not include scripts/" >&2
  exit 1
fi

rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| delta | DELTA.md |'
git checkout "req/${slug}" -- "requirements/${slug}"
want="$(./scripts/cycle-hash.sh "$slug")"
echo "$rec" | grep -q "| hash | ${want} |"
