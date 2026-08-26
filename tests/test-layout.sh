#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=helpers.sh
source tests/helpers.sh

# Template layout
test -f requirements/_template/overview.md
test -f requirements/_template/specified-tests.md
test ! -e requirements/_template/CYCLE

# Copied set layout: overview + specified-tests, no CYCLE until openAutoFeature
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
slug=demo
mkdir -p "$tmp/repo/requirements/${slug}"
cp "$tmp/repo/requirements/_template/"* "$tmp/repo/requirements/${slug}/"
test -f "$tmp/repo/requirements/${slug}/overview.md"
test -f "$tmp/repo/requirements/${slug}/specified-tests.md"
test ! -e "$tmp/repo/requirements/${slug}/CYCLE"

# specify command exists
test -f .cursor/commands/specify.md
grep -q 'requirements/<slug>/' .cursor/commands/specify.md
grep -q 'req/<slug>' .cursor/commands/specify.md
grep -q 'missing-req/<slug>' .cursor/commands/specify.md
grep -q 'Do not create `CYCLE`' .cursor/commands/specify.md
