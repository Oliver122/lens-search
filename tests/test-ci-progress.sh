#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tests/helpers.sh

got="$(printf '%s\n' \
  '{"type":"system","subtype":"init","model":"cursor-grok-4.6-medium"}' \
  '{"type":"tool_call","subtype":"started","tool_call":{"readToolCall":{"args":{"path":"README.md"}}}}' \
  '{"type":"result","subtype":"success","duration_ms":12}' \
  | python3 scripts/ci-agent-log.py)"

echo "$got" | grep -q 'ci-agent: start model=cursor-grok-4.6-medium'
echo "$got" | grep -q 'ci-agent: tool started read README.md'
echo "$got" | grep -q 'ci-agent: result success duration_ms=12'

wf=.github/workflows/auto-feature.yml
grep -q 'run-name:' "$wf"
grep -q 'coder:' "$wf"
grep -q 'harden:' "$wf"
grep -q 'ci-pr-progress.sh' "$wf"
grep -q 'stream-json' scripts/run-coder.sh
