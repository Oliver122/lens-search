#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

slug=old
mkdir -p "requirements/${slug}"
echo '# old' > "requirements/${slug}/overview.md"
got="$(./scripts/read-catalog.sh "$slug")"
assert_eq "$got" $'ungrouped\tprocess\t' "missing Catalog defaults"

slug=tagged
mkdir -p "requirements/${slug}"
cat > "requirements/${slug}/overview.md" <<'EOF'
# tagged

## Catalog

### group

marketplace

### slices

ui
backend

### defs

colors
layout

## In scope

- a feature
EOF
got="$(./scripts/read-catalog.sh "$slug")"
assert_eq "$got" $'marketplace\tui,backend\tcolors,layout' "parse Catalog headings"

slug=commas
mkdir -p "requirements/${slug}"
cat > "requirements/${slug}/overview.md" <<'EOF'
## Catalog

### group

scan-store

### slices

ui, backend

### defs

colors, layout
EOF
got="$(./scripts/read-catalog.sh "$slug")"
assert_eq "$got" $'scan-store\tui,backend\tcolors,layout' "comma lists"

assert_fail "missing set" ./scripts/read-catalog.sh no-such-slug
