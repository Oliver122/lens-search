#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"
slug=iso
mkdir -p "requirements/${slug}" requirements/_defs
cat > "requirements/${slug}/overview.md" <<'EOF'
Overview unique-overview-token for isolation.

## Catalog

### group

demo

### slices

process

### defs

colors
EOF
cat > "requirements/${slug}/specified-tests.md" <<'EOF'
1. [process] Alpha unique-alpha-token must hold
2. [process] Bravo unique-bravo-token must hold
EOF
cat > requirements/_defs/colors.md <<'EOF'
# colors

unique-colors-def-token
EOF
git add requirements && git commit -m spec >/dev/null

p1="$(./scripts/build-subtask-prompt.sh "$slug" 1)"
p2="$(./scripts/build-subtask-prompt.sh "$slug" 2)"
echo "$p1" | grep -q 'unique-overview-token'
echo "$p1" | grep -q 'unique-alpha-token'
echo "$p1" | grep -q 'unique-colors-def-token'
if echo "$p1" | grep -q 'unique-bravo-token'; then
  echo "subtask 1 prompt must not contain sibling test text" >&2
  exit 1
fi
echo "$p2" | grep -q 'unique-bravo-token'
echo "$p2" | grep -q 'unique-colors-def-token'
if echo "$p2" | grep -q 'unique-alpha-token'; then
  echo "subtask 2 prompt must not contain sibling test text" >&2
  exit 1
fi
