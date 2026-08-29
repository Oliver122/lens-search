#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
install_test_agent "$tmp/bin"
export CURSOR_API_KEY=test

slug=cam
git checkout -b "req/${slug}" >/dev/null
mkdir -p "requirements/${slug}"
echo in > "requirements/${slug}/overview.md"
cat > "requirements/${slug}/specified-tests.md" <<'EOF'
1. First observable check
2. Second observable check
EOF
git add requirements && git commit -m spec >/dev/null

./scripts/save-req-delta.sh "$slug" >/dev/null
./scripts/open-orchestrator.sh "$slug" >/dev/null
./scripts/open-worker.sh "$slug"

git rev-parse --verify "worker/${slug}/1-1" >/dev/null
git checkout "worker/${slug}/1-1" >/dev/null
test -f subtask-1.txt

rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| 1 | First observable check | in-review | worker/cam/1-1 |'
echo "$rec" | grep -q '| 2 | Second observable check | pending |'

assert_fail "second worker while in-review" ./scripts/open-worker.sh "$slug"
assert_fail "no worker 2 yet" git rev-parse --verify "worker/${slug}/2-1"

assert_fail "open-worker without key" env -u CURSOR_API_KEY ./scripts/open-worker.sh "$slug"
