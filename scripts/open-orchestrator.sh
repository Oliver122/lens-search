#!/usr/bin/env bash
# Open the integration branch and the subtask list from the specified tests.
set -euo pipefail

slug="${1:?slug required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib="${CYCLE_SCRIPTS:-$script_dir}"
root="$(git rev-parse --show-toplevel)"
cd "$root"
# shellcheck source=cycle-record.sh
source "${lib}/cycle-record.sh"

req_br="req/${slug}"
if git rev-parse --verify "refs/heads/${req_br}" >/dev/null 2>&1; then
  req_ref="$req_br"
elif git rev-parse --verify "refs/remotes/origin/${req_br}" >/dev/null 2>&1; then
  req_ref="origin/${req_br}"
else
  echo "open-orchestrator: missing ${req_br}" >&2
  exit 1
fi

orch="orchestrator/${slug}"
base="$(cycle_record_base_ref)"
git checkout -f -B "$orch" "$base" >/dev/null
bash "${lib}/assert-agent-branch.sh" "$orch"

git checkout "$req_ref" -- "requirements/${slug}"
if [[ ! -f "requirements/${slug}/specified-tests.md" ]]; then
  echo "open-orchestrator: missing specified-tests.md" >&2
  exit 1
fi
bash "${lib}/checkout-req-defs.sh" "$slug"

hash="$(bash "${lib}/cycle-hash.sh" "$slug")"
printf '%s\n' "$hash" > "requirements/${slug}/CYCLE"
git add "requirements/${slug}"
if [[ -d requirements/_defs ]]; then
  git add requirements/_defs
fi
if [[ -n "$(git status --porcelain -- "requirements/${slug}" requirements/_defs)" ]]; then
  git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
    -c user.name="${GIT_AUTHOR_NAME:-orchestrator}" \
    commit -m "openOrchestrator: ${slug} CYCLE ${hash}" >/dev/null
fi

new_n=()
new_text=()
while IFS= read -r row; do
  [[ -n "$row" ]] || continue
  n="${row%%$'\t'*}"
  rest="${row#*$'\t'}"
  text="${rest#*$'\t'}"
  new_n+=("$n")
  new_text+=("$text")
done < <(bash "${lib}/split-specified-tests.sh" "$slug")

cycle_record_ensure_branch "$slug"
cycle_record_parse CYCLE.md
declare -A old_state=() old_worker=() old_pr=() old_attempt=()
if [[ ${#CR_N[@]} -gt 0 ]]; then
  for i in "${!CR_N[@]}"; do
    key="${CR_N[$i]}|${CR_TEXT[$i]}"
    old_state["$key"]="${CR_STATE[$i]}"
    old_worker["$key"]="${CR_WORKER[$i]}"
    old_pr["$key"]="${CR_PR[$i]}"
    old_attempt["$key"]="${CR_ATTEMPT[$i]}"
  done
fi

CR_N=()
CR_TEXT=()
CR_STATE=()
CR_WORKER=()
CR_PR=()
CR_ATTEMPT=()
if [[ ${#new_n[@]} -gt 0 ]]; then
  for i in "${!new_n[@]}"; do
    key="${new_n[$i]}|${new_text[$i]}"
    CR_N+=("${new_n[$i]}")
    CR_TEXT+=("${new_text[$i]}")
    CR_STATE+=("${old_state[$key]:-pending}")
    CR_WORKER+=("${old_worker[$key]:-}")
    CR_PR+=("${old_pr[$key]:-}")
    CR_ATTEMPT+=("${old_attempt[$key]:-0}")
  done
fi

CR_SLUG="$slug"
CR_ORCH="$orch"
[[ -n "${CR_HASH:-}" ]] || CR_HASH="$hash"
cycle_record_render > CYCLE.md
cycle_record_commit "cycle(${slug}): orchestrator"
cycle_record_push_ref "$orch"
cycle_record_push_ref "cycle/${slug}"
echo "open-orchestrator: ${orch} subtasks=${#new_n[@]}"
