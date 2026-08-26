#!/usr/bin/env bash
# Create auto-feature/<slug> from main + requirements/<slug>/, write CYCLE, open or update one MR to main.
# No-op if missing-req/<slug> exists. Never enables auto-merge.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

remote_has_branch() {
  local name="$1"
  git remote get-url origin >/dev/null 2>&1 || return 1
  git ls-remote --exit-code --heads origin "$name" >/dev/null 2>&1
}

if git rev-parse --verify "refs/heads/missing-req/${slug}" >/dev/null 2>&1 \
  || remote_has_branch "missing-req/${slug}"; then
  echo "openAutoFeature: skip, missing-req/${slug} is open"
  exit 0
fi

req_dir="requirements/${slug}"
if [[ ! -d "$req_dir" ]]; then
  echo "openAutoFeature: empty req (missing ${req_dir})" >&2
  exit 1
fi

hash="$("${root}/scripts/cycle-hash.sh" "$slug")"

snap="$(mktemp -d)"
trap 'rm -rf "$snap"' RETURN
cp -a "$req_dir" "$snap/tree"

default_base="${OPEN_AUTO_FEATURE_BASE:-main}"
if git rev-parse --verify "refs/heads/${default_base}" >/dev/null 2>&1; then
  base_ref="$default_base"
elif git rev-parse --verify "refs/remotes/origin/${default_base}" >/dev/null 2>&1; then
  base_ref="origin/${default_base}"
else
  base_ref="HEAD"
fi

feat="auto-feature/${slug}"
git checkout -B "$feat" "$base_ref"

rm -rf "$req_dir"
mkdir -p "$(dirname "$req_dir")"
cp -a "$snap/tree" "$req_dir"
printf '%s\n' "$hash" > "${req_dir}/CYCLE"

git add "$req_dir"
if git diff --cached --quiet; then
  echo "openAutoFeature: no changes to commit on ${feat}"
else
  git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
      -c user.name="${GIT_AUTHOR_NAME:-auto-feature}" \
      commit -m "openAutoFeature: ${slug} CYCLE ${hash}"
fi

if [[ -n "${OPEN_AUTO_FEATURE_PUSH:-}" ]]; then
  git push -u origin "$feat"
fi

if command -v gh >/dev/null 2>&1 && [[ -n "${OPEN_AUTO_FEATURE_MR:-}" ]]; then
  existing="$(gh pr list --head "$feat" --base main --json number --jq '.[0].number // empty')"
  if [[ -z "$existing" ]]; then
    gh pr create --base main --head "$feat" \
      --title "auto-feature/${slug}" \
      --body "RequirementSet \`${slug}\` CYCLE \`${hash}\`. Reviewer freeze: approve and merge. Bots do not merge."
    existing="$(gh pr list --head "$feat" --base main --json number --jq '.[0].number // empty')"
  fi
  if [[ -n "$existing" ]]; then
    gh pr merge --disable-auto "$existing" >/dev/null 2>&1 || true
    automerge="$(gh pr view "$existing" --json autoMergeRequest --jq '.autoMergeRequest // empty')"
    if [[ -n "$automerge" ]]; then
      echo "openAutoFeature: MR must not have auto-merge enabled" >&2
      exit 1
    fi
  fi
fi

echo "openAutoFeature: ${feat} CYCLE ${hash}"
