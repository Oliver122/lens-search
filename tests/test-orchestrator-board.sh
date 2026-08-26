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

slug=board
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
grep -q '| 1 |' ORCHESTRATION.md
grep -q '| 2 |' ORCHESTRATION.md
grep -q '| done |' ORCHESTRATION.md
while IFS='|' read -r _ num _ state _; do
  num="${num// /}"
  state="${state// /}"
  if [[ "$num" =~ ^[0-9]+$ ]]; then
    if [[ ! "$state" =~ ^(running|done|blocked)$ ]]; then
      echo "bad orchestration state: ${state}" >&2
      exit 1
    fi
  fi
done < ORCHESTRATION.md
