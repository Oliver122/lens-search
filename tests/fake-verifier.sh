#!/usr/bin/env bash
# Test stub for the verify gate, wired in via ORCH_VERIFY_BIN.
# FAKE_VERIFIER_PLAN: file with one result per line (green|red), consumed one per
# call; calls past the end of the plan are green. No plan set: always green.
# FAKE_VERIFIER_COUNT: counter file (default: <plan>.count).
set -euo pipefail

plan="${FAKE_VERIFIER_PLAN:-}"
if [[ -z "$plan" ]]; then
  exit 0
fi

count_file="${FAKE_VERIFIER_COUNT:-${plan}.count}"
calls=0
if [[ -f "$count_file" ]]; then
  calls="$(cat "$count_file")"
fi
echo $((calls + 1)) > "$count_file"

res="$(sed -n "$((calls + 1))p" "$plan")"
[[ -n "$res" ]] || res=green

if [[ "$res" == "red" ]]; then
  echo "FAKE-VERIFY-RED call=$((calls + 1))"
  exit 1
fi
exit 0
