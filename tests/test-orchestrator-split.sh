#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=splitme
mkdir -p "requirements/${slug}"
cat > "requirements/${slug}/overview.md" <<'EOF'
in
EOF
cat > "requirements/${slug}/specified-tests.md" <<'EOF'
# tests
1. First observable check
2. Second observable check
3. Third observable check
EOF
git add requirements && git commit -m spec >/dev/null
git checkout -b "req/${slug}" >/dev/null
./scripts/open-auto-feature.sh "$slug" >/dev/null
git checkout "auto-feature/${slug}" >/dev/null

mapfile -t rows < <(./scripts/split-specified-tests.sh "$slug")
assert_eq "${#rows[@]}" "3" "three subtasks for three tests"

slug1=one
mkdir -p "requirements/${slug1}"
echo in > "requirements/${slug1}/overview.md"
echo "1. Only one check" > "requirements/${slug1}/specified-tests.md"
git checkout main >/dev/null
git add requirements && git commit -m one >/dev/null
git checkout -b "req/${slug1}" >/dev/null
./scripts/open-auto-feature.sh "$slug1" >/dev/null
git checkout "auto-feature/${slug1}" >/dev/null
mapfile -t one < <(./scripts/split-specified-tests.sh "$slug1")
assert_eq "${#one[@]}" "1" "single test may yield one subtask"
