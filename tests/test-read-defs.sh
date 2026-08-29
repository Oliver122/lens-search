#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

empty="$(./scripts/read-defs.sh)"
assert_eq "$empty" "" "no ids is empty stdout"

mkdir -p requirements/_defs
cat > requirements/_defs/colors.md <<'EOF'
# colors

unique-colors-token
EOF
cat > requirements/_defs/layout.md <<'EOF'
# layout

unique-layout-token
EOF

out="$(./scripts/read-defs.sh colors)"
echo "$out" | grep -q 'unique-colors-token'
if echo "$out" | grep -q 'unique-layout-token'; then
  echo "read-defs colors must not include layout" >&2
  exit 1
fi

both="$(./scripts/read-defs.sh colors layout)"
echo "$both" | grep -q 'unique-colors-token'
echo "$both" | grep -q 'unique-layout-token'

assert_fail "missing id" ./scripts/read-defs.sh no-such-def
assert_fail "path id" ./scripts/read-defs.sh '../x'
