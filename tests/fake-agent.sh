#!/usr/bin/env bash
# Test stub for `agent`. Writes a marker file on the checkout and records the
# prompt and a START/END trace line per invocation.
set -euo pipefail

prompt="${*: -1}"
tree="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
n=""
if [[ "$prompt" =~ Subtask:\ specified\ test\ ([0-9]+) ]]; then
  n="${BASH_REMATCH[1]}"
fi

if [[ -n "${ORCH_PROMPT_DIR:-}" && -n "$n" ]]; then
  mkdir -p "$ORCH_PROMPT_DIR"
  printf '%s' "$prompt" > "${ORCH_PROMPT_DIR}/agent-prompt-${n}.txt"
fi

if [[ -n "${ORCH_TRACE:-}" ]]; then
  mkdir -p "$(dirname "$ORCH_TRACE")"
  echo "START ${n} ${tree} $$" >> "$ORCH_TRACE"
fi

sleep "${ORCH_AGENT_SLEEP:-0}"

echo "ok-${n}" > "${tree}/subtask-${n}.txt"

if [[ -n "${ORCH_TRACE:-}" ]]; then
  echo "END ${n} ${tree} $$" >> "$ORCH_TRACE"
fi
