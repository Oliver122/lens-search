#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=iso
mkdir -p "requirements/${slug}"
cat > "requirements/${slug}/overview.md" <<'EOF'
Overview unique-overview-token for isolation.
EOF
cat > "requirements/${slug}/specified-tests.md" <<'EOF'
1. Alpha unique-alpha-token must hold
2. Bravo unique-bravo-token must hold
EOF
git add requirements && git commit -m spec >/dev/null
git checkout -b "req/${slug}" >/dev/null
./scripts/open-auto-feature.sh "$slug" >/dev/null
git checkout "auto-feature/${slug}" >/dev/null

p1="$(./scripts/build-subtask-prompt.sh "$slug" 1)"
p2="$(./scripts/build-subtask-prompt.sh "$slug" 2)"
echo "$p1" | grep -q 'unique-overview-token'
echo "$p1" | grep -q 'unique-alpha-token'
if echo "$p1" | grep -q 'unique-bravo-token'; then
  echo "subtask 1 prompt must not contain sibling test text" >&2
  exit 1
fi
echo "$p2" | grep -q 'unique-bravo-token'
if echo "$p2" | grep -q 'unique-alpha-token'; then
  echo "subtask 2 prompt must not contain sibling test text" >&2
  exit 1
fi
