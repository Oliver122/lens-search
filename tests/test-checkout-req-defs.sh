#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

slug=defs
git checkout -b "req/${slug}" >/dev/null
mkdir -p "requirements/${slug}" requirements/_defs
cat > "requirements/${slug}/overview.md" <<'EOF'
## Catalog

### group

demo

### slices

backend

### defs

hook-shape
EOF
echo "1. [backend] Check" > "requirements/${slug}/specified-tests.md"
echo '# hook-shape' > requirements/_defs/hook-shape.md
git add requirements && git commit -m spec >/dev/null

listed="$(./scripts/checkout-req-defs.sh --list "$slug")"
assert_eq "$listed" "requirements/_defs/hook-shape.md" "list pointed def"

git checkout main >/dev/null
test ! -f requirements/_defs/hook-shape.md
git checkout -B "orchestrator/${slug}" main >/dev/null
git checkout "req/${slug}" -- "requirements/${slug}"
./scripts/checkout-req-defs.sh "$slug"
test -f requirements/_defs/hook-shape.md
