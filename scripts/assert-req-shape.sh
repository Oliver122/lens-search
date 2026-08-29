#!/usr/bin/env bash
# Fail unless tagged, sliced, and pointers resolve. Cycle sees thin spec only.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
overview="${root}/requirements/${slug}/overview.md"
tests="${root}/requirements/${slug}/specified-tests.md"

fail() {
  echo "assert-req-shape: ${slug}: $1" >&2
  exit 1
}

[[ -f "$overview" ]] || fail "missing overview.md"
[[ -f "$tests" ]] || fail "missing specified-tests.md"

if ! grep -qE '^##[[:space:]]+Catalog[[:space:]]*$' "$overview"; then
  fail "missing Catalog"
fi

row="$(bash "${root}/scripts/read-catalog.sh" "$slug")"
group="${row%%$'\t'*}"
rest="${row#*$'\t'}"
slices="${rest%%$'\t'*}"
defs="${rest#*$'\t'}"

if [[ ! "$group" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  fail "bad group '${group}'"
fi
if [[ -z "$slices" ]]; then
  fail "no slices"
fi

IFS=',' read -ra slice_list <<< "$slices"
for s in "${slice_list[@]}"; do
  case "$s" in
    ui|backend|process) ;;
    *) fail "unknown slice '${s}'" ;;
  esac
done

count=0
while IFS= read -r row; do
  [[ -n "$row" ]] || continue
  n="${row%%$'\t'*}"
  rest="${row#*$'\t'}"
  slice="${rest%%$'\t'*}"
  count=$((count + 1))
  if [[ -z "$slice" ]]; then
    fail "untagged test ${n}"
  fi
  case "$slice" in
    ui|backend|process) ;;
    *) fail "unknown slice '${slice}'" ;;
  esac
done < <(bash "${root}/scripts/split-specified-tests.sh" "$slug")

if [[ "$count" -eq 0 ]]; then
  fail "no numbered tests"
fi

if [[ -n "$defs" ]]; then
  IFS=',' read -ra ids <<< "$defs"
  for id in "${ids[@]}"; do
    [[ -n "$id" ]] || continue
    if [[ ! -f "${root}/requirements/_defs/${id}.md" ]]; then
      fail "dangling pointer '${id}'"
    fi
  done
fi
