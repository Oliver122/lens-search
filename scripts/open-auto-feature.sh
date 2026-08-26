#!/usr/bin/env bash
# Create auto-feature/<slug> from main + requirements/<slug>/, write CYCLE, open or update one MR to main.
# Same CYCLE: keep existing auto-feature (re-run). New CYCLE: reset from main and force-with-lease.
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

cycle_on_ref() {
  local ref="$1"
  git cat-file -e "${ref}:${req_dir}/CYCLE" 2>/dev/null || return 1
  git show "${ref}:${req_dir}/CYCLE" | tr -d '\r\n'
}

fetch_feat_tracking() {
  local feat="$1"
  git fetch origin "refs/heads/${feat}:refs/remotes/origin/${feat}" 2>/dev/null || true
}

push_feat() {
  local feat="$1"
  fetch_feat_tracking "$feat"
  if git rev-parse --verify "refs/remotes/origin/${feat}" >/dev/null 2>&1; then
    git push --force-with-lease="refs/heads/${feat}:$(git rev-parse "refs/remotes/origin/${feat}")" \
      origin "HEAD:refs/heads/${feat}"
  elif remote_has_branch "$feat"; then
    fetch_feat_tracking "$feat"
    git push --force-with-lease="refs/heads/${feat}:$(git rev-parse "refs/remotes/origin/${feat}")" \
      origin "HEAD:refs/heads/${feat}"
  else
    git push origin "HEAD:refs/heads/${feat}"
  fi
  git fetch origin "${feat}"
  git branch --set-upstream-to="origin/${feat}" "${feat}" >/dev/null 2>&1 || true
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

feat="auto-feature/${slug}"
fetch_feat_tracking "$feat"

existing_cycle=""
existing_ref=""
if git rev-parse --verify "refs/heads/${feat}" >/dev/null 2>&1 \
  && existing_cycle="$(cycle_on_ref "$feat")"; then
  existing_ref="$feat"
elif git rev-parse --verify "refs/remotes/origin/${feat}" >/dev/null 2>&1 \
  && existing_cycle="$(cycle_on_ref "origin/${feat}")"; then
  existing_ref="origin/${feat}"
fi

if [[ -n "$existing_ref" && "$existing_cycle" == "$hash" ]]; then
  if [[ "$existing_ref" == "$feat" ]]; then
    git checkout "$feat"
  else
    git checkout -B "$feat" "$existing_ref"
  fi
  echo "openAutoFeature: ${feat} already CYCLE ${hash}"
else
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

  git checkout --no-track -B "$feat" "$base_ref"

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
  trap - RETURN
  rm -rf "$snap"

  if [[ -n "${OPEN_AUTO_FEATURE_PUSH:-}" ]]; then
    push_feat "$feat"
  fi
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
