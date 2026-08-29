#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

assert_ok "orchestrator backfill" ./scripts/assert-req-shape.sh orchestrator

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

write_good() {
  local slug="$1"
  mkdir -p "requirements/${slug}" requirements/_defs
  cat > "requirements/${slug}/overview.md" <<'EOF'
# demo

## Catalog

### group

marketplace

### slices

ui

### defs

colors
EOF
  echo "1. [ui] First check" > "requirements/${slug}/specified-tests.md"
  echo '# colors' > requirements/_defs/colors.md
}

write_good good
assert_ok "tagged sliced resolving" ./scripts/assert-req-shape.sh good

slug=old
mkdir -p "requirements/${slug}"
echo '# old' > "requirements/${slug}/overview.md"
echo "1. First check" > "requirements/${slug}/specified-tests.md"
assert_fail "missing Catalog" ./scripts/assert-req-shape.sh old

slug=untagged
mkdir -p "requirements/${slug}"
cat > "requirements/${slug}/overview.md" <<'EOF'
## Catalog

### group

demo

### slices

process

### defs

EOF
echo "1. First check" > "requirements/${slug}/specified-tests.md"
assert_fail "untagged line" ./scripts/assert-req-shape.sh untagged

slug=unknown
mkdir -p "requirements/${slug}"
cat > "requirements/${slug}/overview.md" <<'EOF'
## Catalog

### group

demo

### slices

process

### defs

EOF
echo "1. [frontend] First check" > "requirements/${slug}/specified-tests.md"
assert_fail "unknown slice" ./scripts/assert-req-shape.sh unknown

slug=dangle
mkdir -p "requirements/${slug}"
cat > "requirements/${slug}/overview.md" <<'EOF'
## Catalog

### group

demo

### slices

process

### defs

missing-def
EOF
echo "1. [process] First check" > "requirements/${slug}/specified-tests.md"
assert_fail "dangling pointer" ./scripts/assert-req-shape.sh dangle

slug=thin
mkdir -p "requirements/${slug}"
cat > "requirements/${slug}/overview.md" <<'EOF'
## Catalog

### group

demo

### slices

process

### defs

EOF
echo "no numbers" > "requirements/${slug}/specified-tests.md"
assert_fail "no numbered tests" ./scripts/assert-req-shape.sh thin
