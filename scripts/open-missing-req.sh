#!/usr/bin/env bash
# Halt AF/AX. Branch missing-req/<slug> contains MISSING.md only. Comment on the feature MR.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"
script_dir="$(cd "$(dirname "$0")" && pwd)"
tool_tmp="$(mktemp -d)"
cp "${script_dir}/assert-agent-branch.sh" "${script_dir}/missing-req-file-policy.sh" "$tool_tmp/"
trap 'rm -rf "$tool_tmp"' EXIT

reason="${2:-Spec too thin. Human must specify; do not invent Gherkin.}"
mr="missing-req/${slug}"

base="${OPEN_MISSING_REQ_BASE:-main}"
if git rev-parse --verify "refs/heads/${base}" >/dev/null 2>&1; then
  git checkout "$base"
elif git rev-parse --verify "refs/remotes/origin/${base}" >/dev/null 2>&1; then
  git checkout -B "$base" "origin/${base}"
fi

git checkout -B "$mr"
if git ls-files | grep -q .; then
  git rm -rf . >/dev/null
fi
printf '%s\n' "$reason" > MISSING.md
git add MISSING.md

"${tool_tmp}/assert-agent-branch.sh" "$mr"
"${tool_tmp}/missing-req-file-policy.sh" "$mr" MISSING.md

git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
    -c user.name="${GIT_AUTHOR_NAME:-missing-req}" \
    commit -m "openMissingReq: ${slug}" -- MISSING.md

if [[ -n "${OPEN_MISSING_REQ_PUSH:-}" ]]; then
  git push -u origin "$mr"
fi

if command -v gh >/dev/null 2>&1 && [[ -n "${OPEN_MISSING_REQ_COMMENT:-}" ]]; then
  pr="$(gh pr list --head "auto-feature/${slug}" --base main --json number --jq '.[0].number // empty')"
  if [[ -n "$pr" ]]; then
    gh pr comment "$pr" --body "Halt: \`missing-req/${slug}\` is open. Specify, then push \`req/${slug}\` (new CYCLE). See \`MISSING.md\`."
  fi
fi

echo "openMissingReq: ${mr}"
