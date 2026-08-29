#!/usr/bin/env bash
# Start the next unmerged subtask as a worker branch and PR.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"
# shellcheck source=cycle-record.sh
source "${root}/scripts/cycle-record.sh"

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "open-worker: CURSOR_API_KEY is unset" >&2
  exit 1
fi

cycle_record_ensure_branch "$slug"
cycle_record_parse CYCLE.md
CR_SLUG="$slug"

if [[ -z "${CR_ORCH:-}" ]] || ! cycle_record_ref_exists "$CR_ORCH"; then
  echo "open-worker: orchestrator branch is not open" >&2
  exit 1
fi

pick=""
if [[ ${#CR_N[@]} -gt 0 ]]; then
  for i in "${!CR_N[@]}"; do
    if [[ "${CR_STATE[$i]}" == "in-review" ]]; then
      echo "open-worker: subtask ${CR_N[$i]} already in-review" >&2
      exit 1
    fi
  done
  for i in "${!CR_N[@]}"; do
    case "${CR_STATE[$i]}" in
      pending|respawned)
        pick="$i"
        break
        ;;
    esac
  done
fi

if [[ -z "$pick" ]]; then
  echo "open-worker: no pending subtask" >&2
  exit 1
fi

n="${CR_N[$pick]}"
att="${CR_ATTEMPT[$pick]}"
if [[ "$att" -eq 0 ]]; then
  att=1
fi
worker="worker/${slug}/${n}-${att}"

wt="$(mktemp -d)"
cleanup() {
  git -C "$root" worktree remove --force "$wt" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if cycle_record_ref_exists "$worker"; then
  git worktree add "$wt" "$worker" >/dev/null 2>&1
else
  git worktree add -b "$worker" "$wt" "$CR_ORCH" >/dev/null 2>&1
fi

(
  cd "$wt"
  bash "${root}/scripts/run-subtask-coder.sh" "$slug" "$n"
)

pr=""
if command -v gh >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
  cycle_record_push_ref "$worker"
  existing="$(gh pr list --head "$worker" --base "$CR_ORCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [[ -z "$existing" ]]; then
    gh pr create --base "$CR_ORCH" --head "$worker" \
      --title "worker/${slug} ${n} attempt ${att}" \
      --body "Subtask ${n} of \`${slug}\`. Review: approve to merge into \`${CR_ORCH}\`, or reject to respawn." \
      >/dev/null || true
    existing="$(gh pr list --head "$worker" --base "$CR_ORCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  fi
  pr="$existing"
fi

cycle_record_ensure_branch "$slug"
cycle_record_parse CYCLE.md
CR_SLUG="$slug"
if [[ ${#CR_N[@]} -gt 0 ]]; then
  for i in "${!CR_N[@]}"; do
    if [[ "${CR_N[$i]}" == "$n" ]]; then
      CR_STATE[$i]="in-review"
      CR_WORKER[$i]="$worker"
      CR_PR[$i]="$pr"
      CR_ATTEMPT[$i]="$att"
    fi
  done
fi
cycle_record_render > CYCLE.md
cycle_record_commit "cycle(${slug}): worker ${n}-${att}"
cycle_record_push_ref "cycle/${slug}"
echo "open-worker: ${worker}"
