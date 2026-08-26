#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="${root}/scripts:${PATH}"
fail=0
for t in "${root}/tests"/test-*.sh; do
  echo "== $(basename "$t")"
  if ! bash "$t"; then
    echo "FAIL $(basename "$t")"
    fail=1
  fi
done
if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK"
