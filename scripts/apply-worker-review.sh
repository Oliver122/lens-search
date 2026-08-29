#!/usr/bin/env bash
# Merge an approved worker into the orchestrator, or respawn the same subtask.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"
# shellcheck source=cycle-record.sh
source "${root}/scripts/cycle-record.sh"

cycle_record_ensure_branch "$slug"
cycle_record_parse CYCLE.md
CR_SLUG="$slug"

pick=""
if [[ ${#CR_N[@]} -gt 0 ]]; then
  for i in "${!CR_N[@]}"; do
    if [[ "${CR_STATE[$i]}" == "in-review" ]]; then
      pick="$i"
      break
    fi
  done
fi

if [[ -z "$pick" ]]; then
  echo "apply-worker-review: no worker in-review" >&2
  exit 1
fi

n="${CR_N[$pick]}"
worker="${CR_WORKER[$pick]}"
orch="${CR_ORCH:-}"
if [[ -z "$worker" ]] || ! cycle_record_ref_exists "$worker"; then
  echo "apply-worker-review: worker branch missing" >&2
  exit 1
fi
if [[ -z "$orch" ]] || ! cycle_record_ref_exists "$orch"; then
  echo "apply-worker-review: orchestrator branch missing" >&2
  exit 1
fi

verdict="${WORKER_REVIEW:-}"
if [[ -z "$verdict" ]]; then
  if git cat-file -e "${worker}:GAPS.md" 2>/dev/null; then
    verdict="reject"
  else
    verdict="pending"
  fi
fi

case "$verdict" in
  pending)
    echo "apply-worker-review: waiting on review of ${worker}"
    exit 0
    ;;
  approve)
    git checkout -f "$orch" >/dev/null
    bash "${root}/scripts/assert-agent-branch.sh" "$orch"
    if ! git -c user.email="${GIT_AUTHOR_EMAIL:-bot@local}" \
      -c user.name="${GIT_AUTHOR_NAME:-orchestrator}" \
      merge --no-ff -m "orchestrator(${slug}): merge ${worker}" "$worker"; then
      git merge --abort >/dev/null 2>&1 || true
      echo "apply-worker-review: merge conflict on ${worker}; not inventing a spec" >&2
      exit 1
    fi
    cycle_record_ensure_branch "$slug"
    cycle_record_parse CYCLE.md
    CR_SLUG="$slug"
    if [[ ${#CR_N[@]} -gt 0 ]]; then
      for i in "${!CR_N[@]}"; do
        if [[ "${CR_N[$i]}" == "$n" ]]; then
          CR_STATE[$i]="merged"
        fi
      done
    fi
    cycle_record_render > CYCLE.md
    cycle_record_commit "cycle(${slug}): merged ${n}"
    cycle_record_push_ref "$orch"
    cycle_record_push_ref "cycle/${slug}"
    echo "apply-worker-review: merged ${worker}"
    ;;
  reject)
    att="${CR_ATTEMPT[$pick]}"
    att=$((att + 1))
    CR_STATE[$pick]="respawned"
    CR_ATTEMPT[$pick]="$att"
    cycle_record_render > CYCLE.md
    cycle_record_commit "cycle(${slug}): respawn ${n}"
    cycle_record_push_ref "cycle/${slug}"
    echo "apply-worker-review: respawn subtask ${n} attempt ${att}"
    ;;
  *)
    echo "apply-worker-review: verdict must be approve|reject|pending" >&2
    exit 1
    ;;
esac
