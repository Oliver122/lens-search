#!/usr/bin/env bash
# Open the requirement → main PR after every subtask has merged.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"
# shellcheck source=cycle-record.sh
source "${root}/scripts/cycle-record.sh"

cycle_record_ensure_branch "$slug"
cycle_record_parse CYCLE.md
CR_SLUG="$slug"

if [[ ${#CR_N[@]} -eq 0 ]]; then
  echo "open-requirement-pr: no subtasks; not opening" >&2
  exit 1
fi
if [[ ${#CR_N[@]} -gt 0 ]]; then
  for i in "${!CR_N[@]}"; do
    if [[ "${CR_STATE[$i]}" != "merged" ]]; then
      echo "open-requirement-pr: subtask ${CR_N[$i]} is ${CR_STATE[$i]}, not merged" >&2
      exit 1
    fi
  done
fi

orch="${CR_ORCH:-}"
req_br="req/${slug}"
if [[ -z "$orch" ]] || ! cycle_record_ref_exists "$orch"; then
  echo "open-requirement-pr: orchestrator branch missing" >&2
  exit 1
fi
if ! cycle_record_ref_exists "$req_br"; then
  echo "open-requirement-pr: missing ${req_br}" >&2
  exit 1
fi

git checkout "$req_br" >/dev/null 2>&1
if ! git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
  -c user.name="${GIT_AUTHOR_NAME:-cycle}" \
  merge --no-ff -m "req(${slug}): land orchestrator" "$orch"; then
  git merge --abort >/dev/null 2>&1 || true
  echo "open-requirement-pr: merge conflict; not inventing a spec" >&2
  exit 1
fi

req_pr="${req_br}"
if command -v gh >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
  cycle_record_push_ref "$req_br"
  existing="$(gh pr list --head "$req_br" --base main --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [[ -z "$existing" ]]; then
    gh pr create --base main --head "$req_br" \
      --title "req/${slug}" \
      --body "RequirementSet \`${slug}\`. Freeze: approve and merge to main. Bots do not merge." \
      >/dev/null || true
    existing="$(gh pr list --head "$req_br" --base main --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  fi
  if [[ -n "$existing" ]]; then
    gh pr merge --disable-auto "$existing" >/dev/null 2>&1 || true
    automerge="$(gh pr view "$existing" --json autoMergeRequest --jq '.autoMergeRequest // empty' 2>/dev/null || true)"
    if [[ -n "$automerge" ]]; then
      echo "open-requirement-pr: PR must not have auto-merge enabled" >&2
      exit 1
    fi
    req_pr="$existing"
  fi
fi

cycle_record_ensure_branch "$slug"
cycle_record_parse CYCLE.md
CR_SLUG="$slug"
CR_REQ_PR="$req_pr"
cycle_record_render > CYCLE.md
cycle_record_commit "cycle(${slug}): requirement PR"
cycle_record_push_ref "cycle/${slug}"
echo "open-requirement-pr: ${req_br} -> main (${req_pr})"
