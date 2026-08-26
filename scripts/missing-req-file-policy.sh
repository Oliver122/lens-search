#!/usr/bin/env bash
# On missing-req/<slug>, the only allowed path is MISSING.md.
set -euo pipefail

branch="${1:-}"
if [[ -z "$branch" ]]; then
  if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
    branch="$GITHUB_REF_NAME"
  else
    branch="$(git rev-parse --abbrev-ref HEAD)"
  fi
fi

case "$branch" in
  missing-req/*) ;;
  *)
    echo "missing-req-file-policy: skip (not missing-req/*): ${branch}"
    exit 0
    ;;
esac

shift || true
files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    mapfile -t files < <(git diff --cached --name-only)
    if [[ ${#files[@]} -eq 0 ]]; then
      mapfile -t files < <(git ls-files)
    fi
  fi
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "missing-req-file-policy: no files to check" >&2
  exit 1
fi

for f in "${files[@]}"; do
  if [[ "$f" != "MISSING.md" ]]; then
    echo "missing-req-file-policy: only MISSING.md allowed, got ${f}" >&2
    exit 1
  fi
done
