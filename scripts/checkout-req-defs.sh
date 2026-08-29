#!/usr/bin/env bash
# Copy Catalog-pointed _defs from req/<slug> into the current tree.
# --list: print those paths only (needs overview.md in the current tree).
set -euo pipefail

list=0
if [[ "${1:-}" == "--list" ]]; then
  list=1
  shift
fi

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"

row="$(bash "${root}/scripts/read-catalog.sh" "$slug")"
defs="${row#*$'\t'}"
defs="${defs#*$'\t'}"

paths=()
if [[ -n "$defs" ]]; then
  IFS=',' read -ra ids <<< "$defs"
  for id in "${ids[@]}"; do
    [[ -n "$id" ]] || continue
    paths+=("requirements/_defs/${id}.md")
  done
fi

if [[ "$list" -eq 1 ]]; then
  if [[ ${#paths[@]} -gt 0 ]]; then
    printf '%s\n' "${paths[@]}"
  fi
  exit 0
fi

cd "$root"
if [[ ${#paths[@]} -eq 0 ]]; then
  exit 0
fi

if git rev-parse --verify "refs/heads/req/${slug}" >/dev/null 2>&1; then
  ref="req/${slug}"
elif git rev-parse --verify "refs/remotes/origin/req/${slug}" >/dev/null 2>&1; then
  ref="origin/req/${slug}"
else
  echo "checkout-req-defs: missing req/${slug}" >&2
  exit 1
fi

git checkout "$ref" -- "${paths[@]}"
