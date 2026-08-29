#!/usr/bin/env bash
# Advance this slug's cycle by the next legal graph step and persist the record the PO opens.
set -euo pipefail

slug="${1:?slug required}"
if [[ ! "$slug" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "step-cycle: bad slug: ${slug}" >&2
  exit 1
fi

root="$(git rev-parse --show-toplevel)"
cd "$root"
# shellcheck source=cycle-record.sh
source "${root}/scripts/cycle-record.sh"

cycle_record_reload() {
  cycle_record_ensure_branch "$slug"
  cycle_record_parse CYCLE.md
  CR_SLUG="$slug"
}

cycle_record_write() {
  cycle_record_ensure_branch "$slug"
  CR_SLUG="$slug"
  cycle_record_render > CYCLE.md
  cycle_record_commit "cycle(${slug}): ${1}"
  cycle_record_push_ref "cycle/${slug}"
}

lease_held() {
  local now epoch
  now="$(date +%s)"
  [[ -n "${CR_LEASE:-}" ]] || return 1
  epoch="${CR_LEASE%%:*}"
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 1
  (( now - epoch < 7200 ))
}

signal_incomplete() {
  local reason="$1"
  bash "${root}/scripts/open-missing-req.sh" "$slug" "$reason"
  git -C "$root" checkout -f "cycle/${slug}" >/dev/null 2>&1 || true
  cycle_record_reload
  CR_INCOMPLETE="$reason"
  cycle_record_write "incomplete"
  echo "step-cycle: incomplete ${slug}"
}

req_has_numbered_tests() {
  local spec
  spec="$(git show "req/${slug}:requirements/${slug}/specified-tests.md" 2>/dev/null \
    || git show "origin/req/${slug}:requirements/${slug}/specified-tests.md" 2>/dev/null \
    || true)"
  echo "$spec" | grep -qE '^[0-9]+\. '
}

req_ref() {
  if git rev-parse --verify "refs/heads/req/${slug}" >/dev/null 2>&1; then
    echo "req/${slug}"
  elif git rev-parse --verify "refs/remotes/origin/req/${slug}" >/dev/null 2>&1; then
    echo "origin/req/${slug}"
  else
    return 1
  fi
}

assert_req_shape() {
  local ref wt err rc
  ref="$(req_ref)" || return 1
  wt="$(mktemp -d)"
  if ! git worktree add --detach "$wt" "$ref" >/dev/null 2>&1; then
    rm -rf "$wt"
    return 1
  fi
  err="$(cd "$wt" && bash "${root}/scripts/assert-req-shape.sh" "$slug" 2>&1)" && rc=0 || rc=$?
  git worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"
  if [[ "$rc" -ne 0 ]]; then
    echo "${err:-requirement shape failed}"
    return 1
  fi
  return 0
}

cycle_record_observe "$slug" >/dev/null
cycle_record_reload

if lease_held; then
  echo "step-cycle: ${slug} busy"
  exit 0
fi

CR_LEASE="$(date +%s):$$"
cycle_record_write "lease"

release_lease() {
  cycle_record_reload
  CR_LEASE=""
  cycle_record_write "release"
}
trap release_lease EXIT

cycle_record_observe "$slug" >/dev/null
cycle_record_reload

if [[ -n "${CR_INCOMPLETE:-}" ]]; then
  echo "step-cycle: ${slug} halted (incomplete)"
  exit 0
fi

if [[ -z "${CR_DELTA:-}" ]]; then
  if ! git rev-parse --verify "refs/heads/req/${slug}" >/dev/null 2>&1 \
    && ! git rev-parse --verify "refs/remotes/origin/req/${slug}" >/dev/null 2>&1; then
    signal_incomplete "missing req/${slug}"
    exit 0
  fi
  if ! req_has_numbered_tests && ! git cat-file -e "req/${slug}:requirements/${slug}/overview.md" 2>/dev/null; then
    signal_incomplete "empty req/${slug}"
    exit 0
  fi
  bash "${root}/scripts/save-req-delta.sh" "$slug"
  echo "step-cycle: ${slug} saved delta"
  exit 0
fi

if [[ -z "${CR_ORCH:-}" ]]; then
  if ! err="$(assert_req_shape)"; then
    signal_incomplete "${err:-requirement shape failed}"
    exit 0
  fi
  bash "${root}/scripts/open-orchestrator.sh" "$slug"
  echo "step-cycle: ${slug} opened orchestrator"
  exit 0
fi

if [[ ${#CR_N[@]} -eq 0 ]]; then
  signal_incomplete "specified-tests.md has no numbered tests; too thin to split without guessing."
  exit 0
fi

in_review=""
pending=""
unmerged=0
if [[ ${#CR_N[@]} -gt 0 ]]; then
  for i in "${!CR_N[@]}"; do
    case "${CR_STATE[$i]}" in
      in-review)
        in_review="$i"
        unmerged=1
        ;;
      pending|respawned)
        [[ -n "$pending" ]] || pending="$i"
        unmerged=1
        ;;
      merged) ;;
      *)
        unmerged=1
        ;;
    esac
  done
fi

if [[ -n "$in_review" ]]; then
  bash "${root}/scripts/apply-worker-review.sh" "$slug"
  echo "step-cycle: ${slug} applied review"
  exit 0
fi

if [[ -n "$pending" ]]; then
  bash "${root}/scripts/open-worker.sh" "$slug"
  echo "step-cycle: ${slug} opened worker"
  exit 0
fi

if [[ "$unmerged" -eq 0 && -z "${CR_REQ_PR:-}" ]]; then
  bash "${root}/scripts/open-requirement-pr.sh" "$slug"
  echo "step-cycle: ${slug} opened requirement PR"
  exit 0
fi

echo "step-cycle: ${slug} waiting"
exit 0
