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
echo in > "requirements/${slug}/overview.md"
cat > "requirements/${slug}/specified-tests.md" <<'EOF'
# tests
1. [ui] First observable check
2. [backend] Second observable check
3. [process] Third observable check
EOF
git add requirements && git commit -m spec >/dev/null

mapfile -t rows < <(./scripts/split-specified-tests.sh "$slug")
assert_eq "${#rows[@]}" "3" "three subtasks for three tests"
assert_eq "${rows[0]}" $'1\tui\tFirst observable check' "slice column ui"
assert_eq "${rows[1]}" $'2\tbackend\tSecond observable check' "slice column backend"
assert_eq "${rows[2]}" $'3\tprocess\tThird observable check' "slice column process"

slug1=one
mkdir -p "requirements/${slug1}"
echo in > "requirements/${slug1}/overview.md"
echo "1. [process] Only one check" > "requirements/${slug1}/specified-tests.md"
git add requirements && git commit -m one >/dev/null
mapfile -t one < <(./scripts/split-specified-tests.sh "$slug1")
assert_eq "${#one[@]}" "1" "single test may yield one subtask"
assert_eq "${one[0]}" $'1\tprocess\tOnly one check' "single tagged row"

slug2=untagged
mkdir -p "requirements/${slug2}"
echo in > "requirements/${slug2}/overview.md"
echo "1. First observable check" > "requirements/${slug2}/specified-tests.md"
mapfile -t raw < <(./scripts/split-specified-tests.sh "$slug2")
assert_eq "${raw[0]}" $'1\t\tFirst observable check' "untagged keeps empty slice and text"
