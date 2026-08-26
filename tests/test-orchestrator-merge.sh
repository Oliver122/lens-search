#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

mkdir -p "$tmp/bin"
cp "$ROOT/tests/fake-agent.sh" "$tmp/bin/agent"
chmod +x "$tmp/bin/agent"
export PATH="${tmp/bin}:${PATH}"
export AGENT_BIN="$tmp/bin/agent"
export CURSOR_API_KEY=test-key
export ORCH_AGENT_SLEEP=0
export ORCH_AGENT_MODE=unique
export ORCHESTRATOR_WORKTREE_ROOT="$tmp/wts"

slug=merge
mkdir -p "requirements/${slug}"
echo overview > "requirements/${slug}/overview.md"
cat > "requirements/${slug}/specified-tests.md" <<'EOF'
1. First check
2. Second check
EOF
git add requirements && git commit -m spec >/dev/null
git checkout -b "req/${slug}" >/dev/null
./scripts/open-auto-feature.sh "$slug" >/dev/null
git checkout "auto-feature/${slug}" >/dev/null

./scripts/run-orchestrator.sh "$slug"
git checkout "auto-feature/${slug}" >/dev/null
test -f subtask-1.txt
test -f subtask-2.txt
assert_eq "$(cat subtask-1.txt)" "ok-1" "merged subtask 1"
assert_eq "$(cat subtask-2.txt)" "ok-2" "merged subtask 2"

# MR head is auto-feature/<slug>, worktree branches not left unmerged
assert_fail "worktree branch 1 gone" git rev-parse --verify "auto-feature/${slug}--t1"
assert_fail "worktree branch 2 gone" git rev-parse --verify "auto-feature/${slug}--t2"
git rev-parse --verify "auto-feature/${slug}" >/dev/null
