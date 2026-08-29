#!/usr/bin/env bash
# Return shelf entries for the given ids as markdown. Hides _defs/ path.
# No ids: empty stdout, not an error.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
if [[ $# -eq 0 ]]; then
  exit 0
fi

for id in "$@"; do
  if [[ ! "$id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "read-defs: bad id: ${id}" >&2
    exit 1
  fi
  file="${root}/requirements/_defs/${id}.md"
  if [[ ! -f "$file" ]]; then
    echo "read-defs: missing ${file}" >&2
    exit 1
  fi
  cat "$file"
  echo
done
