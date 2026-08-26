#!/usr/bin/env bash
# Orchestrator: sequential subtask loop on auto-feature/<slug> with an executable
# verify gate. Per subtask: coder → verify (build + accumulated test suite); on
# red the coder is re-invoked once with the failure output (2 attempts total);
# still red → GAPS.md entry + gap state, loop continues. Each completed subtask
# is committed and pushed immediately with the board updated in the same commit,
# so a restarted run resumes from the board (done/gap rows are skipped).
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

board="${root}/scripts/progress-board.sh"
mapfile -t rows < <("${root}/scripts/split-specified-tests.sh" "$slug")
if [[ ${#rows[@]} -eq 0 ]]; then
  echo "run-orchestrator: specified-tests.md has no numbered tests; too thin to split" >&2
  "${root}/scripts/open-missing-req.sh" "$slug" \
    "specified-tests.md has no numbered tests; too thin to split without guessing."
  exit 0
fi

"$board" init "$slug"
commit_if_dirty "orchestrator(${slug}): board"
push_feat

record_gap() {
  local n="$1" text="$2"
  if [[ ! -f "${root}/GAPS.md" ]]; then
    { echo "# Gaps — ${slug}"; echo; } > "${root}/GAPS.md"
  fi
  echo "- ${n}. ${text} (verify red after 2 attempts)" >> "${root}/GAPS.md"
}

for row in "${rows[@]}"; do
  n="${row%%$'\t'*}"
  text="${row#*$'\t'}"

  state="$("$board" get "$slug" "$n")"
  if [[ "$state" == done || "$state" == gap ]]; then
    echo "run-orchestrator: subtask ${n} already ${state}; skip"
    continue
  fi

  "$board" set "$slug" "$n" in-progress
  green_ref="$(git rev-parse HEAD)"
  failure_log="$(mktemp)"
  verified=0

  for attempt in 1 2; do
    echo "::group::subtask ${n} attempt ${attempt}"
    rc=0
    if [[ "$attempt" -eq 1 ]]; then
      "${root}/scripts/run-subtask-coder.sh" "$slug" "$n" || rc=$?
    else
      "${root}/scripts/run-subtask-coder.sh" "$slug" "$n" "$failure_log" || rc=$?
    fi
    echo "::endgroup::"
    if [[ "$rc" -eq 2 ]]; then
      echo "run-orchestrator: coder environment problem on subtask ${n}; aborting" >&2
      exit 1
    fi
    # Any other coder crash folds into the red-attempt path: verify decides.
    t0="$(date +%s)"
    vrc=0
    "${root}/scripts/verify-subtask.sh" >"$failure_log" 2>&1 || vrc=$?
    t1="$(date +%s)"
    if [[ "$vrc" -eq 0 ]]; then
      echo "run-orchestrator: subtask ${n} attempt ${attempt} verify=green duration=$((t1 - t0))s"
      verified=1
      break
    fi
    echo "run-orchestrator: subtask ${n} attempt ${attempt} verify=red duration=$((t1 - t0))s"
  done

  if [[ "$verified" -eq 1 ]]; then
    "$board" set "$slug" "$n" done
    commit_if_dirty "coder(${slug}): ${n} done"
    push_feat
  else
    echo "run-orchestrator: subtask ${n} red after 2 attempts; recording gap" >&2
    cat "$failure_log" >&2 || true
    # Discard the unverified work so the accumulated suite stays green.
    git reset --hard "$green_ref" >/dev/null
    git clean -fd >/dev/null
    record_gap "$n" "$text"
    "$board" set "$slug" "$n" gap
    commit_if_dirty "orchestrator(${slug}): ${n} gap"
    push_feat
  fi
  rm -f "$failure_log"
done

echo "run-orchestrator: ${feat} subtasks=${#rows[@]} complete"
