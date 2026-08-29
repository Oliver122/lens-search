#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_repo "$tmp/repo"
cd "$tmp/repo"

empty="$(./scripts/list-catalog.sh)"
assert_eq "$empty" "" "empty catalog is empty stdout"

write_set() {
  local slug="$1" group="$2" slices="$3"
  mkdir -p "requirements/${slug}"
  cat > "requirements/${slug}/overview.md" <<EOF
# ${slug}

## Catalog

### group

${group}

### slices

${slices}

### defs

EOF
}

write_set alpha marketplace $'ui\nbackend'
write_set beta marketplace $'process'
write_set gamma orchestrator $'process'

got="$(./scripts/list-catalog.sh)"
assert_eq "$got" $'alpha\nbeta\ngamma' "all slugs sorted"

got="$(./scripts/list-catalog.sh --group marketplace)"
assert_eq "$got" $'alpha\nbeta' "filter group"

got="$(./scripts/list-catalog.sh --slice process)"
assert_eq "$got" $'beta\ngamma' "filter slice"

got="$(./scripts/list-catalog.sh --group marketplace --slice ui)"
assert_eq "$got" "alpha" "group and slice"

got="$(./scripts/list-catalog.sh --group missing)"
assert_eq "$got" "" "no match is empty stdout"
