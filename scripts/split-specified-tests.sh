#!/usr/bin/env bash
# List numbered tests with slices as: <n><TAB><slice><TAB><text>
# One subtask per numbered item. Untagged lines have an empty slice.
# No items → empty stdout (caller may open missing-req).
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
tests="${root}/requirements/${slug}/specified-tests.md"

if [[ ! -f "$tests" ]]; then
  echo "split-specified-tests: missing ${tests}" >&2
  exit 1
fi

while IFS= read -r line; do
  if [[ "$line" =~ ^([0-9]+)\.\ \[([^]]+)\][[:space:]]+(.*)$ ]]; then
    printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  elif [[ "$line" =~ ^([0-9]+)\.\ (.+)$ ]]; then
    printf '%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "" "${BASH_REMATCH[2]}"
  fi
done < "$tests"
