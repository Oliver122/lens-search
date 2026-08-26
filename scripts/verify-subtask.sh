#!/usr/bin/env bash
# Verify gate: decide whether the accumulated product builds and its whole test
# suite passes. No args. Exit 0 = green. Exit 1 = red, failure output on stdout.
# ORCH_VERIFY_BIN replaces the real verifier (test seam).
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

if [[ -n "${ORCH_VERIFY_BIN:-}" ]]; then
  exec "$ORCH_VERIFY_BIN"
fi

# The product is one crate somewhere in the tree; the shallowest Cargo.toml wins,
# so a workspace root covers member crates. None yet = red: subtask 1's coder
# must create the crate.
manifest="$(git ls-files --cached --others --exclude-standard -- 'Cargo.toml' '*/Cargo.toml' \
  | awk -F/ '{print NF "\t" $0}' | sort -n | head -1 | cut -f2-)"
if [[ -z "$manifest" ]]; then
  echo "verify-subtask: no Cargo.toml in the tree; the product crate does not exist yet"
  exit 1
fi

dir="$(dirname "$manifest")"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
if (cd "$dir" && cargo build --all-targets && cargo test) >"$log" 2>&1; then
  exit 0
fi
cat "$log"
exit 1
