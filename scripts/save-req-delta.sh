#!/usr/bin/env bash
# Store the requirement's delta versus main for the PO and later steps.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"
# shellcheck source=cycle-record.sh
source "${root}/scripts/cycle-record.sh"

req_br="req/${slug}"
if ! git rev-parse --verify "refs/heads/${req_br}" >/dev/null 2>&1 \
  && ! git rev-parse --verify "refs/remotes/origin/${req_br}" >/dev/null 2>&1; then
  echo "save-req-delta: missing ${req_br}" >&2
  exit 1
fi
if git rev-parse --verify "refs/heads/${req_br}" >/dev/null 2>&1; then
  req_ref="$req_br"
else
  req_ref="origin/${req_br}"
fi

base="$(cycle_record_base_ref)"
delta="$(git diff --no-color "$base" "$req_ref" -- "requirements/${slug}" \
  ":(exclude)requirements/${slug}/CYCLE" || true)"

wt="$(mktemp -d)"
trap 'git -C "$root" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"' EXIT
git worktree add --detach "$wt" "$req_ref" >/dev/null 2>&1
hash="$(
  cd "$wt"
  bash "${root}/scripts/cycle-hash.sh" "$slug"
)"

cycle_record_ensure_branch "$slug"
cycle_record_parse CYCLE.md
CR_SLUG="$slug"
CR_HASH="$hash"
CR_DELTA="DELTA.md"
printf '%s\n' "$delta" > DELTA.md
cycle_record_render > CYCLE.md
git add CYCLE.md DELTA.md
if [[ -n "$(git status --porcelain -- CYCLE.md DELTA.md)" ]]; then
  git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
    -c user.name="${GIT_AUTHOR_NAME:-cycle}" \
    commit -m "cycle(${slug}): save delta" >/dev/null
fi
cycle_record_push_ref "cycle/${slug}"
echo "save-req-delta: cycle/${slug} hash ${hash}"
