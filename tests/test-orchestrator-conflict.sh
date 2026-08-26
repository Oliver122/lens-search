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
export ORCH_AGENT_MODE=conflict
export ORCHESTRATOR_WORKTREE_ROOT="$tmp/wts"

slug=clash
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

test -f ORCHESTRATION.md
grep -q '| blocked |' ORCHESTRATION.md
test -f GAPS.md
grep -q 'First check\|Second check' GAPS.md

# Did not force-merge (no -X ours/theirs / -s ours in scripts)
if grep -R --include='*.sh' -nE 'merge .*-X (ours|theirs)|merge .*-s ours|merge --force' scripts; then
  echo "found force-merge flags" >&2
  exit 1
fi

# SAME.txt must be one side or absent for the blocked subtask — not a concatenated invention
if [[ -f SAME.txt ]]; then
  if grep -q 'from-subtask-1' SAME.txt && grep -q 'from-subtask-2' SAME.txt; then
    echo "invented combined SAME.txt from both sides" >&2
    exit 1
  fi
fi
