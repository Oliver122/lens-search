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
slug=cycle
make_feature_repo "$tmp/repo" "$slug"

install_test_agent "$tmp/bin"
install_test_verifier
export CURSOR_API_KEY=test-key

before="$(tr -d '\r\n' < "requirements/${slug}/CYCLE")"
hash="$(./scripts/cycle-hash.sh "$slug")"
assert_eq "$before" "$hash" "CYCLE matches tree before orchestrator"
./scripts/run-orchestrator.sh "$slug"
git checkout "auto-feature/${slug}" >/dev/null
after="$(tr -d '\r\n' < "requirements/${slug}/CYCLE")"
assert_eq "$after" "$before" "CYCLE unchanged"
assert_eq "$(./scripts/cycle-hash.sh "$slug")" "$after" "CYCLE still hashes RequirementSet tree"
