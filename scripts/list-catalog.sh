#!/usr/bin/env bash
# List matching slugs. Optional --group G and --slice S. Hides tree scan.
# Empty match: empty stdout, not an error.
set -euo pipefail

group=""
slice=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --group)
      group="${2:?--group needs a value}"
      shift 2
      ;;
    --slice)
      slice="${2:?--slice needs a value}"
      shift 2
      ;;
    *)
      echo "list-catalog: usage: list-catalog.sh [--group G] [--slice S]" >&2
      exit 2
      ;;
  esac
done

root="$(git rev-parse --show-toplevel)"
shopt -s nullglob
slugs=()
for dir in "${root}/requirements/"*; do
  [[ -d "$dir" ]] || continue
  name="$(basename "$dir")"
  case "$name" in
    _template|_defs) continue ;;
  esac
  [[ -f "${dir}/overview.md" ]] || continue
  slugs+=("$name")
done

if [[ ${#slugs[@]} -eq 0 ]]; then
  exit 0
fi

IFS=$'\n' sorted=($(printf '%s\n' "${slugs[@]}" | sort))
for name in "${sorted[@]}"; do
  row="$("${root}/scripts/read-catalog.sh" "$name")"
  g="${row%%$'\t'*}"
  rest="${row#*$'\t'}"
  slices="${rest%%$'\t'*}"
  if [[ -n "$group" && "$g" != "$group" ]]; then
    continue
  fi
  if [[ -n "$slice" ]]; then
    hit=0
    IFS=',' read -ra parts <<< "$slices"
    for p in "${parts[@]}"; do
      if [[ "$p" == "$slice" ]]; then
        hit=1
        break
      fi
    done
    [[ "$hit" -eq 1 ]] || continue
  fi
  printf '%s\n' "$name"
done
