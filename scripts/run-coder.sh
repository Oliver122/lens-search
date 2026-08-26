#!/usr/bin/env bash
# After openAutoFeature, the next agent is the orchestrator — not one coder
# holding the whole RequirementSet in a single context.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
if [[ -n "${OPEN_AUTO_FEATURE_PUSH:-}" ]]; then
  export OPEN_MISSING_REQ_PUSH="${OPEN_MISSING_REQ_PUSH:-1}"
  export OPEN_MISSING_REQ_COMMENT="${OPEN_MISSING_REQ_COMMENT:-1}"
fi
exec "${root}/scripts/run-orchestrator.sh" "$slug"
