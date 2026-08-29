#!/usr/bin/env bash
# Orchestrator: split specified-tests into subtasks, run subtask coders in parallel
# worktrees, merge onto auto-feature/<slug>. Not a single coder for the whole set.
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
  echo "run-orchestrator: missing CYCLE; openAutoFeature must run first" >&2
  exit 1
fi

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "run-orchestrator: CURSOR_API_KEY is unset" >&2
  exit 1
fi

if [[ -z "${AGENT_BIN:-}" ]]; then
  if ! command -v agent >/dev/null 2>&1; then
    export PATH="${HOME}/.cursor/bin:${HOME}/.local/bin:${PATH}"
  fi
  if ! command -v agent >/dev/null 2>&1; then
    echo "run-orchestrator: agent not on PATH; run scripts/install-cursor-cli.sh" >&2
    exit 1
  fi
fi

author_email="${GIT_AUTHOR_EMAIL:-bot@local}"
author_name="${GIT_AUTHOR_NAME:-auto-feature}"
commit_if_dirty() {
  local msg="$1"
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git -c user.email="$author_email" -c user.name="$author_name" commit -m "$msg"
  fi
}

push_feat() {
  if [[ -n "${OPEN_AUTO_FEATURE_PUSH:-}" ]]; then
    git push origin "$feat"
  fi
}

split="${root}/scripts/split-specified-tests.sh"
mapfile -t rows < <("$split" "$slug")
if [[ ${#rows[@]} -eq 0 ]]; then
  echo "run-orchestrator: specified-tests.md has no numbered tests; too thin to split" >&2
  "${root}/scripts/open-missing-req.sh" "$slug" \
    "specified-tests.md has no numbered tests; too thin to split without guessing."
  exit 0
fi

"${root}/scripts/init-progress.sh" "$slug"
"${root}/scripts/write-orchestration.sh" "$slug"
commit_if_dirty "orchestrator(${slug}): board"
push_feat

wt_root="${ORCHESTRATOR_WORKTREE_ROOT:-$(mktemp -d)}"
mkdir -p "$wt_root"
nums=()
declare -A texts=()
cleanup() {
  local n wt
  git -C "$root" checkout "$feat" >/dev/null 2>&1 || true
  for n in "${nums[@]+"${nums[@]}"}"; do
    wt="${wt_root}/t${n}"
    git -C "$root" worktree remove --force "$wt" >/dev/null 2>&1 || true
    git -C "$root" branch -D "auto-feature/${slug}--t${n}" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

for row in "${rows[@]}"; do
  n="${row%%$'\t'*}"
  rest="${row#*$'\t'}"
  texts["$n"]="${rest#*$'\t'}"
  nums+=("$n")
done

for n in "${nums[@]}"; do
  "${root}/scripts/write-orchestration.sh" "$slug" "$n" running
done
commit_if_dirty "orchestrator(${slug}): subtasks running"
push_feat

declare -A pids=()
for n in "${nums[@]}"; do
  wt="${wt_root}/t${n}"
  br="auto-feature/${slug}--t${n}"
  git worktree add -b "$br" "$wt" "$feat"
  (
    cd "$wt"
    "${root}/scripts/run-subtask-coder.sh" "$slug" "$n"
  ) >"${wt_root}/log-${n}.txt" 2>&1 &
  pids["$n"]=$!
done

merge_one() {
  local n="$1"
  local br="auto-feature/${slug}--t${n}"
  git -C "$root" checkout "$feat"
  if "${root}/scripts/merge-subtask-worktree.sh" "$slug" "$n" "$br"; then
    "${root}/scripts/write-orchestration.sh" "$slug" "$n" done
    "${root}/scripts/set-progress-state.sh" "$slug" "$n" done
    commit_if_dirty "orchestrator(${slug}): ${n} done"
    push_feat
    return 0
  fi
  git -C "$root" merge --abort >/dev/null 2>&1 || true
  "${root}/scripts/write-orchestration.sh" "$slug" "$n" blocked
  commit_if_dirty "orchestrator(${slug}): ${n} blocked conflict"
  push_feat
  return 1
}

pending=()
coder_failed=()
alive=("${nums[@]}")
while [[ ${#alive[@]} -gt 0 ]]; do
  still=()
  for n in "${alive[@]}"; do
    if kill -0 "${pids[$n]}" 2>/dev/null; then
      still+=("$n")
      continue
    fi
    rc=0
    wait "${pids[$n]}" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      if ! merge_one "$n"; then
        pending+=("$n")
      fi
    else
      echo "run-orchestrator: subtask ${n} coder failed" >&2
      cat "${wt_root}/log-${n}.txt" >&2 || true
      git checkout "$feat"
      "${root}/scripts/write-orchestration.sh" "$slug" "$n" blocked
      commit_if_dirty "orchestrator(${slug}): ${n} blocked coder"
      push_feat
      coder_failed+=("$n")
    fi
  done
  if [[ ${#still[@]} -eq ${#alive[@]} ]]; then
    sleep 0.2
  fi
  alive=("${still[@]+"${still[@]}"}")
done

progress=1
while [[ "$progress" -eq 1 && ${#pending[@]} -gt 0 ]]; do
  progress=0
  still=()
  for n in "${pending[@]}"; do
    if merge_one "$n"; then
      progress=1
    else
      still+=("$n")
    fi
  done
  pending=("${still[@]+"${still[@]}"}")
done

if [[ ${#pending[@]} -gt 0 || ${#coder_failed[@]} -gt 0 ]]; then
  git checkout "$feat"
  {
    echo "# Gaps — ${slug}"
    echo
    if [[ ${#pending[@]} -gt 0 ]]; then
      echo "Unmet specified tests (worktree merge conflict; orchestrator did not invent a spec or force-merge):"
      echo
      for n in "${pending[@]}"; do
        echo "- ${n}. ${texts[$n]}"
      done
      echo
    fi
    if [[ ${#coder_failed[@]} -gt 0 ]]; then
      echo "Unmet specified tests (subtask coder failed):"
      echo
      for n in "${coder_failed[@]}"; do
        echo "- ${n}. ${texts[$n]}"
      done
    fi
  } >>"${root}/GAPS.md"
  for n in "${pending[@]+"${pending[@]}"}" "${coder_failed[@]+"${coder_failed[@]}"}"; do
    [[ -n "$n" ]] || continue
    "${root}/scripts/write-orchestration.sh" "$slug" "$n" blocked
    "${root}/scripts/set-progress-state.sh" "$slug" "$n" gap
  done
  commit_if_dirty "orchestrator(${slug}): GAPS after conflict"
  push_feat
fi

git checkout "$feat"
echo "run-orchestrator: ${feat} subtasks=${#nums[@]}"
