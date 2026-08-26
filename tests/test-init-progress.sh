#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=prog
mkdir -p "requirements/${slug}"
cat > "requirements/${slug}/specified-tests.md" <<'EOF'
# Specified tests — prog

1. Store listings by URL.
2. Sort by price.
EOF
git add requirements && git commit -m spec >/dev/null
git checkout -b "auto-feature/${slug}" >/dev/null
printf 'hash\n' > "requirements/${slug}/CYCLE"
git add requirements && git commit -m cycle >/dev/null

chmod +x ./scripts/init-progress.sh
./scripts/init-progress.sh "$slug"
grep -q '| 1 | Store listings by URL. | todo |' PROGRESS.md
grep -q '| 2 | Sort by price. | todo |' PROGRESS.md
grep -q 'auto-feature/prog' PROGRESS.md

# Keep state on re-init
sed -i 's/Store listings by URL. | todo/Store listings by URL. | done/' PROGRESS.md
./scripts/init-progress.sh "$slug"
grep -q '| 1 | Store listings by URL. | done |' PROGRESS.md
grep -q '| 2 | Sort by price. | todo |' PROGRESS.md

# Root board is not inside the RequirementSet (CYCLE)
test ! -f "requirements/${slug}/PROGRESS.md"
