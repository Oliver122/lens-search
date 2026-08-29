#!/usr/bin/env bash
# Return this set's group, slices, and pointers as: group<TAB>slices<TAB>defs
# Missing Catalog defaults to ungrouped / process / no defs.
set -euo pipefail

slug="${1:?slug required}"
root="$(git rev-parse --show-toplevel)"
overview="${root}/requirements/${slug}/overview.md"

if [[ ! -f "$overview" ]]; then
  echo "read-catalog: missing ${overview}" >&2
  exit 1
fi

normalize_list() {
  local raw="$1"
  local out="" tok
  raw="${raw//,/$'\n'}"
  while IFS= read -r tok; do
    tok="${tok#"${tok%%[![:space:]]*}"}"
    tok="${tok%"${tok##*[![:space:]]}"}"
    [[ -n "$tok" ]] || continue
    [[ "$tok" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || continue
    if [[ -n "$out" ]]; then
      out="${out},${tok}"
    else
      out="$tok"
    fi
  done <<< "$raw"
  printf '%s' "$out"
}

parsed="$(awk '
  BEGIN { in_cat=0; sec=""; found=0 }
  /^##[[:space:]]+Catalog[[:space:]]*$/ { in_cat=1; found=1; sec=""; next }
  in_cat && /^##[[:space:]]+/ { exit }
  in_cat && /^###[[:space:]]+group[[:space:]]*$/ { sec="group"; next }
  in_cat && /^###[[:space:]]+slices[[:space:]]*$/ { sec="slices"; next }
  in_cat && /^###[[:space:]]+defs[[:space:]]*$/ { sec="defs"; next }
  in_cat && sec != "" && $0 !~ /^[[:space:]]*$/ && $0 !~ /^#/ {
    if (sec == "group" && group == "") { group = $0 }
    else if (sec == "slices") { slices = slices (slices == "" ? "" : "\n") $0 }
    else if (sec == "defs") { defs = defs (defs == "" ? "" : "\n") $0 }
  }
  END {
    if (!found) { print "MISSING"; exit }
    print group
    print "---"
    print slices
    print "---"
    print defs
  }
' "$overview")"

if [[ "$parsed" == "MISSING" ]]; then
  printf '%s\t%s\t%s\n' "ungrouped" "process" ""
  exit 0
fi

group="$(printf '%s\n' "$parsed" | awk 'BEGIN{p=1} /^---$/{if(p==1){p=2; next} if(p==2){p=3; next}} p==1{print}')"
slices="$(printf '%s\n' "$parsed" | awk 'BEGIN{p=1} /^---$/{if(p==1){p=2; next} if(p==2){p=3; next}} p==2{print}')"
defs="$(printf '%s\n' "$parsed" | awk 'BEGIN{p=1} /^---$/{if(p==1){p=2; next} if(p==2){p=3; next}} p==3{print}')"

group="${group#"${group%%[![:space:]]*}"}"
group="${group%"${group##*[![:space:]]}"}"

printf '%s\t%s\t%s\n' "$group" "$(normalize_list "$slices")" "$(normalize_list "$defs")"
