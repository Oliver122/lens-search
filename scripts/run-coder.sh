#!/usr/bin/env bash
# Coder implements RequirementSet on auto-feature/<slug>.
# Unmet specified tests -> GAPS.md. Thin spec -> caller should open missing-req.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

feat="auto-feature/${slug}"
if git rev-parse --verify "$feat" >/dev/null 2>&1; then
  git checkout "$feat"
elif git rev-parse --verify "origin/${feat}" >/dev/null 2>&1; then
  git checkout -B "$feat" "origin/${feat}"
fi

"${root}/scripts/assert-agent-branch.sh" "$feat"

req="requirements/${slug}"
if [[ ! -f "${req}/CYCLE" ]]; then
  echo "run-coder: missing CYCLE; openAutoFeature must run first" >&2
  exit 1
fi

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "run-coder: CURSOR_API_KEY is unset" >&2
  exit 1
fi

export PATH="${HOME}/.cursor/bin:${HOME}/.local/bin:${PATH}"
if ! command -v agent >/dev/null 2>&1; then
  echo "run-coder: agent not on PATH; run scripts/install-cursor-cli.sh" >&2
  exit 1
fi

prompt_file="${root}/scripts/coder-prompt.md"
if [[ ! -f "$prompt_file" ]]; then
  echo "run-coder: missing ${prompt_file}" >&2
  exit 1
fi

agent -p --force "$(cat "$prompt_file")

Slug: ${slug}
RequirementSet path: ${req}/
"

if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
      -c user.name="${GIT_AUTHOR_NAME:-auto-feature}" \
      commit -m "coder: ${slug}"
fi

if [[ -n "${OPEN_AUTO_FEATURE_PUSH:-}" ]]; then
  git push origin "$feat"
fi
