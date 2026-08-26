#!/usr/bin/env bash
# Print one subtask coder prompt: overview + this subtask only (no sibling tests or prompts).
set -euo pipefail

slug="${1:?slug required}"
n="${2:?subtask number required}"
root="$(git rev-parse --show-toplevel)"
req="requirements/${slug}"
overview="${root}/${req}/overview.md"
template="${root}/scripts/subtask-coder-prompt.md"

if [[ ! -f "$overview" ]]; then
  echo "build-subtask-prompt: missing ${overview}" >&2
  exit 1
fi
if [[ ! -f "$template" ]]; then
  echo "build-subtask-prompt: missing ${template}" >&2
  exit 1
fi

text=""
found=0
while IFS=$'\t' read -r num line; do
  if [[ "$num" == "$n" ]]; then
    text="$line"
    found=1
    break
  fi
done < <("${root}/scripts/split-specified-tests.sh" "$slug")

if [[ "$found" -ne 1 ]]; then
  echo "build-subtask-prompt: no specified test ${n}" >&2
  exit 1
fi

cat "$template"
echo
echo "Slug: ${slug}"
echo "RequirementSet path: ${req}/"
echo "Subtask: specified test ${n}"
echo
echo "--- overview.md ---"
cat "$overview"
echo
echo "--- your subtask (specified test ${n} only) ---"
echo "${n}. ${text}"
echo
echo "Do not include or implement any other numbered specified test."
