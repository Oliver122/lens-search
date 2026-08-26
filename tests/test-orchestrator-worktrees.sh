#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

install_test_agent "$tmp/bin"
export CURSOR_API_KEY=test-key
export ORCH_AGENT_SLEEP=1
export ORCH_TRACE="$tmp/trace.txt"
export ORCH_PROMPT_DIR="$tmp/prompts"
export ORCH_AGENT_MODE=unique
export ORCHESTRATOR_WORKTREE_ROOT="$tmp/wts"

slug=par
mkdir -p "requirements/${slug}"
echo "overview for ${slug}" > "requirements/${slug}/overview.md"
cat > "requirements/${slug}/specified-tests.md" <<EOF
1. First check for ${slug}
2. Second check for ${slug}
EOF
git add requirements
git commit -m "spec ${slug}" >/dev/null
git checkout -b "req/${slug}" >/dev/null
./scripts/open-auto-feature.sh "$slug" >/dev/null
git checkout "auto-feature/${slug}" >/dev/null
./scripts/run-orchestrator.sh "$slug"

test -f "$ORCH_TRACE"
starts="$(grep -c '^START ' "$ORCH_TRACE")"
assert_eq "$starts" "2" "two subtask agents started"

t1="$(awk '/^START 1 /{print $3}' "$ORCH_TRACE")"
t2="$(awk '/^START 2 /{print $3}' "$ORCH_TRACE")"
if [[ "$t1" == "$t2" ]]; then
  echo "subtask coders shared a working tree: ${t1}" >&2
  exit 1
fi
feat_tree="$(git rev-parse --show-toplevel)"
if [[ "$t1" == "$feat_tree" || "$t2" == "$feat_tree" ]]; then
  echo "subtask used primary tree" >&2
  exit 1
fi

# Overlap: both START lines before both END lines (parallel, not serial-only)
s1="$(grep -n '^START 1 ' "$ORCH_TRACE" | head -1 | cut -d: -f1)"
s2="$(grep -n '^START 2 ' "$ORCH_TRACE" | head -1 | cut -d: -f1)"
e1="$(grep -n '^END 1 ' "$ORCH_TRACE" | head -1 | cut -d: -f1)"
e2="$(grep -n '^END 2 ' "$ORCH_TRACE" | head -1 | cut -d: -f1)"
if [[ "$s1" -gt "$e2" || "$s2" -gt "$e1" ]]; then
  echo "subtasks did not overlap in time" >&2
  cat "$ORCH_TRACE" >&2
  exit 1
fi
