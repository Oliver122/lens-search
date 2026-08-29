#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=helpers.sh
source tests/helpers.sh

# Template layout
test -f requirements/_template/overview.md
test -f requirements/_template/specified-tests.md
test ! -e requirements/_template/CYCLE
test -d requirements/_defs
grep -q '^## Catalog' requirements/_template/overview.md
grep -q '^### group' requirements/_template/overview.md
grep -q '^### slices' requirements/_template/overview.md
grep -q '^### defs' requirements/_template/overview.md
grep -qE '^[0-9]+\. \[[^]]+\]' requirements/_template/specified-tests.md

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

# All tracked shell scripts are executable (CI runs ./scripts/*.sh)
while read -r mode path; do
  if [[ "$mode" != "100755" ]]; then
    echo "script not executable: ${path} mode=${mode}" >&2
    exit 1
  fi
done < <(git ls-files -s -- '*.sh' | awk '{print $1, $NF}')

# specify command exists
test -f .cursor/commands/specify.md
grep -q 'requirements/<slug>/' .cursor/commands/specify.md
grep -q 'req/<slug>' .cursor/commands/specify.md
grep -q 'missing-req/<slug>' .cursor/commands/specify.md
grep -q 'Do not create `CYCLE.md`' .cursor/commands/specify.md
grep -q 'group' .cursor/commands/specify.md
grep -q 'slices' .cursor/commands/specify.md
grep -q 'shared-vs-local' .cursor/commands/specify.md
grep -q 'requirements/_defs/' .cursor/commands/specify.md
