#!/usr/bin/env bash
# Child of auto-feature/<slug> only. Error if auto-fix/<slug> already exists.
# Merges back into the feature branch (same MR to main).
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

remote_has_branch() {
  local name="$1"
  git remote get-url origin >/dev/null 2>&1 || return 1
  git ls-remote --exit-code --heads origin "$name" >/dev/null 2>&1
}

if git rev-parse --verify "refs/heads/auto-fix/${slug}" >/dev/null 2>&1 \
  || remote_has_branch "auto-fix/${slug}"; then
  echo "openAutoFix: auto-fix/${slug} already exists" >&2
  exit 1
fi

parent="auto-feature/${slug}"
if ! git rev-parse --verify "refs/heads/${parent}" >/dev/null 2>&1 \
  && ! git rev-parse --verify "refs/remotes/origin/${parent}" >/dev/null 2>&1; then
  echo "openAutoFix: parent ${parent} missing" >&2
  exit 1
fi

if [[ ! -f GAPS.md ]]; then
  echo "openAutoFix: GAPS.md required on ${parent}" >&2
  exit 1
fi

base="$parent"
git rev-parse --verify "refs/heads/${parent}" >/dev/null 2>&1 || base="origin/${parent}"

fix="auto-fix/${slug}"
git checkout -B "$fix" "$base"
"${root}/scripts/assert-agent-branch.sh" "$fix"

if [[ -n "${OPEN_AUTO_FIX_PUSH:-}" ]]; then
  git push -u origin "$fix"
fi

echo "openAutoFix: ${fix} from ${parent}"
