#!/usr/bin/env bash
# Hash of requirements/<slug>/ excluding CYCLE. Callers do not snapshot by hand.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
dir="${root}/requirements/${slug}"

if [[ ! -d "$dir" ]]; then
  echo "cycle-hash: missing requirements/${slug}/" >&2
  exit 1
fi

# Empty tree (no files, or only CYCLE) is an empty req.
mapfile -t files < <(find "$dir" -type f ! -name CYCLE | sort)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "cycle-hash: empty requirements/${slug}/" >&2
  exit 1
fi

hash="$(
  cd "$root"
  # Hash path + contents so renames change CYCLE.
  for f in "${files[@]}"; do
    rel="${f#"$root"/}"
    printf '%s\0' "$rel"
    cat "$f"
  done | sha256sum | awk '{print $1}'
)"
printf '%s\n' "$hash"
