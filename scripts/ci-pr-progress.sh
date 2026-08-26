#!/usr/bin/env bash
# Post a progress note on the auto-feature MR (Actions run URL). No-op without gh/GH_TOKEN/PR.
set -euo pipefail

slug="${1:?slug required}"
phase="${2:?phase required}"
feat="auto-feature/${slug}"

if ! command -v gh >/dev/null 2>&1 || [[ -z "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
  echo "ci-pr-progress: skip (no gh token)"
  exit 0
fi

number="$(gh pr list --head "$feat" --base main --json number --jq '.[0].number // empty' || true)"
if [[ -z "$number" ]]; then
  echo "ci-pr-progress: skip (no MR for ${feat})"
  exit 0
fi

run_url=""
if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_RUN_ID:-}" ]]; then
  run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
fi

model="${CURSOR_AGENT_MODEL:-cursor-grok-4.6-medium}"
body="**${phase}** \`${feat}\`
Model: \`${model}\`
"
if [[ -n "$run_url" ]]; then
  body+="Actions: ${run_url}
"
fi
body+="Live tool calls are in the **coder** job log (\`ci-agent:\` lines)."

gh pr comment "$number" --body "$body"
echo "ci-pr-progress: commented on PR ${number}"
