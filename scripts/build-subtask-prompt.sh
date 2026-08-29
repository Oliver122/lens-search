#!/usr/bin/env bash
# Build one test plus pointed defs: overview + this subtask only (no sibling tests or prompts).
set -euo pipefail

slug="${1:?slug required}"
n="${2:?subtask number required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git rev-parse --show-toplevel)"
req="requirements/${slug}"
overview="${root}/${req}/overview.md"
template="${script_dir}/subtask-coder-prompt.md"

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
mapfile -t rows < <("${script_dir}/split-specified-tests.sh" "$slug")
for row in "${rows[@]}"; do
  num="${row%%$'\t'*}"
  rest="${row#*$'\t'}"
  line="${rest#*$'\t'}"
  if [[ "$num" == "$n" ]]; then
    text="$line"
    found=1
    break
  fi
done

if [[ "$found" -ne 1 ]]; then
  echo "build-subtask-prompt: no specified test ${n}" >&2
  exit 1
fi

row="$("${script_dir}/read-catalog.sh" "$slug")"
defs="${row#*$'\t'}"
defs="${defs#*$'\t'}"

cat "$template"
echo
echo "Slug: ${slug}"
echo "RequirementSet path: ${req}/"
echo "Subtask: specified test ${n}"
echo
echo "--- overview.md ---"
cat "$overview"
echo
if [[ -n "$defs" ]]; then
  echo "--- pointed defs ---"
  IFS=',' read -ra ids <<< "$defs"
  "${script_dir}/read-defs.sh" "${ids[@]}"
  echo
fi
echo "--- your subtask (specified test ${n} only) ---"
echo "${n}. ${text}"
echo
echo "Do not include or implement any other numbered specified test."
