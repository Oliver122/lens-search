#!/usr/bin/env bash
# Hardener: close stated GAPS on auto-fix/<slug>.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

fix="auto-fix/${slug}"
if git rev-parse --verify "$fix" >/dev/null 2>&1; then
  git checkout "$fix"
elif git rev-parse --verify "origin/${fix}" >/dev/null 2>&1; then
  git checkout -B "$fix" "origin/${fix}"
fi

"${root}/scripts/assert-agent-branch.sh" "$fix"

if [[ ! -f GAPS.md ]]; then
  echo "run-hardener: GAPS.md missing" >&2
  exit 1
fi

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "run-hardener: CURSOR_API_KEY is unset" >&2
  exit 1
fi

export PATH="${HOME}/.cursor/bin:${HOME}/.local/bin:${PATH}"
if ! command -v agent >/dev/null 2>&1; then
  echo "run-hardener: agent not on PATH; run scripts/install-cursor-cli.sh" >&2
  exit 1
fi

model="${CURSOR_AGENT_MODEL:-cursor-grok-4.6-medium}"
log="${root}/scripts/ci-agent-log.py"
echo "run-hardener: slug=${slug} model=${model}"
agent_cmd=(agent -p --force --model "$model" --output-format stream-json)
if [[ -f "$log" ]]; then
  "${agent_cmd[@]}" "$(cat "${root}/scripts/hardener-prompt.md")

Slug: ${slug}
" | python3 "$log"
else
  "${agent_cmd[@]}" "$(cat "${root}/scripts/hardener-prompt.md")

Slug: ${slug}
"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
      -c user.name="${GIT_AUTHOR_NAME:-auto-fix}" \
      commit -m "hardener: ${slug}"
fi

if [[ -n "${OPEN_AUTO_FIX_PUSH:-}" ]]; then
  git push origin "$fix"
fi
