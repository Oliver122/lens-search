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

WORKER_REVIEW=pending ./scripts/apply-worker-review.sh "$slug"
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| 1 | First observable check | in-review |'

WORKER_REVIEW=approve ./scripts/apply-worker-review.sh "$slug"
git checkout "orchestrator/${slug}" >/dev/null
test -f subtask-1.txt
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| 1 | First observable check | merged | worker/cam/1-1 |'

./scripts/open-worker.sh "$slug" >/dev/null
git rev-parse --verify "worker/${slug}/2-1" >/dev/null
WORKER_REVIEW=reject ./scripts/apply-worker-review.sh "$slug"
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| 2 | Second observable check | respawned | worker/cam/2-1 |'
echo "$rec" | grep -q '| 2 | Second observable check | respawned |' 
echo "$rec" | grep '| 2 |' | grep -q '| 2 |'

./scripts/open-worker.sh "$slug" >/dev/null
git rev-parse --verify "worker/${slug}/2-2" >/dev/null
rec="$(./scripts/cycle-record.sh load "$slug")"
echo "$rec" | grep -q '| 2 | Second observable check | in-review | worker/cam/2-2 |'
