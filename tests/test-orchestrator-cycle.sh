#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

if grep -R --include='*.sh' --include='*.yml' -n 'pr merge --auto' scripts .github; then
  echo "found gh pr merge --auto" >&2
  exit 1
fi
if grep -R --include='*.yml' -n 'enableAutoMerge' .github; then
  echo "found enableAutoMerge" >&2
  exit 1
fi
grep -q 'disable-auto' scripts/open-auto-feature.sh

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
export ORCH_AGENT_MODE=unique
export ORCHESTRATOR_WORKTREE_ROOT="$tmp/wts"

slug=cycle
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
before="$(tr -d '\r\n' < "requirements/${slug}/CYCLE")"
hash="$(./scripts/cycle-hash.sh "$slug")"
assert_eq "$before" "$hash" "CYCLE matches tree before orchestrator"
./scripts/run-orchestrator.sh "$slug"
git checkout "auto-feature/${slug}" >/dev/null
after="$(tr -d '\r\n' < "requirements/${slug}/CYCLE")"
assert_eq "$after" "$before" "CYCLE unchanged"
assert_eq "$(./scripts/cycle-hash.sh "$slug")" "$after" "CYCLE still hashes RequirementSet tree"
