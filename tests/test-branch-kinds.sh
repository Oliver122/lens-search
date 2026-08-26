#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

assert_ok "auto-feature allowed" ./scripts/assert-agent-branch.sh auto-feature/demo
assert_ok "auto-fix allowed" ./scripts/assert-agent-branch.sh auto-fix/demo
assert_ok "missing-req allowed" ./scripts/assert-agent-branch.sh missing-req/demo
assert_fail "main refused" ./scripts/assert-agent-branch.sh main
assert_fail "req refused" ./scripts/assert-agent-branch.sh req/demo
assert_fail "other refused" ./scripts/assert-agent-branch.sh feat/demo

assert_ok "file policy skip on feature" ./scripts/missing-req-file-policy.sh auto-feature/demo README.md
assert_ok "MISSING.md only" ./scripts/missing-req-file-policy.sh missing-req/demo MISSING.md
assert_fail "extra file on missing-req" ./scripts/missing-req-file-policy.sh missing-req/demo MISSING.md README.md
assert_fail "GAPS on missing-req" ./scripts/missing-req-file-policy.sh missing-req/demo GAPS.md
