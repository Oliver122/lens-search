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
./scripts/open-worker.sh "$slug" >/dev/null

assert_fail "req PR before any merge" ./scripts/open-requirement-pr.sh "$slug"

WORKER_REVIEW=approve ./scripts/apply-worker-review.sh "$slug" >/dev/null
assert_fail "req PR while second pending" ./scripts/open-requirement-pr.sh "$slug"

./scripts/open-worker.sh "$slug" >/dev/null
WORKER_REVIEW=approve ./scripts/apply-worker-review.sh "$slug" >/dev/null
./scripts/open-requirement-pr.sh "$slug"

git checkout "req/${slug}" >/dev/null
test -f subtask-1.txt
test -f subtask-2.txt
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q "| req_pr | req/${slug} |"
