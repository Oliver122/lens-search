#!/usr/bin/env bash
# Merge auto-fix/<slug> into auto-feature/<slug> (same MR). Then delete the fix branch.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

feat="auto-feature/${slug}"
fix="auto-fix/${slug}"

git checkout "$feat"
git merge --no-ff "$fix" -m "merge auto-fix/${slug} into ${feat}"

if [[ -n "${OPEN_AUTO_FIX_PUSH:-}" ]]; then
  git push origin "$feat"
  git push origin --delete "$fix" || true
fi

git branch -D "$fix" 2>/dev/null || true
echo "openAutoFix: merged ${fix} into ${feat} (same MR)"
