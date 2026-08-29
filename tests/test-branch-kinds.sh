#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

assert_ok "cycle allowed" ./scripts/assert-agent-branch.sh cycle/demo
assert_ok "orchestrator allowed" ./scripts/assert-agent-branch.sh orchestrator/demo
assert_ok "worker allowed" ./scripts/assert-agent-branch.sh worker/demo/1-1
assert_ok "missing-req allowed" ./scripts/assert-agent-branch.sh missing-req/demo
assert_fail "main refused" ./scripts/assert-agent-branch.sh main
assert_fail "req refused" ./scripts/assert-agent-branch.sh req/demo
assert_fail "auto-feature refused" ./scripts/assert-agent-branch.sh auto-feature/demo
assert_fail "auto-fix refused" ./scripts/assert-agent-branch.sh auto-fix/demo
assert_fail "other refused" ./scripts/assert-agent-branch.sh feat/demo

assert_eq "$(./scripts/slug-from-ref.sh cycle/demo)" "demo" "slug cycle"
assert_eq "$(./scripts/slug-from-ref.sh orchestrator/demo)" "demo" "slug orch"
assert_eq "$(./scripts/slug-from-ref.sh worker/demo/1-2)" "demo" "slug worker"
assert_eq "$(./scripts/slug-from-ref.sh req/demo)" "demo" "slug req"

assert_ok "file policy skip on orch" ./scripts/missing-req-file-policy.sh orchestrator/demo README.md
assert_ok "MISSING.md only" ./scripts/missing-req-file-policy.sh missing-req/demo MISSING.md
assert_fail "extra file on missing-req" ./scripts/missing-req-file-policy.sh missing-req/demo MISSING.md README.md
assert_fail "GAPS on missing-req" ./scripts/missing-req-file-policy.sh missing-req/demo GAPS.md
