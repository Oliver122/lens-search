#!/usr/bin/env bash
# Print slug from refs like req/<slug>, auto-feature/<slug>, auto-fix/<slug>, missing-req/<slug>.
set -euo pipefail

ref="${1:?ref required}"
ref="${ref#refs/heads/}"

case "$ref" in
  req/*) echo "${ref#req/}" ;;
  auto-feature/*) echo "${ref#auto-feature/}" ;;
  auto-fix/*) echo "${ref#auto-fix/}" ;;
  missing-req/*) echo "${ref#missing-req/}" ;;
  *)
    echo "slug-from-ref: not a six-pack branch: ${ref}" >&2
    exit 1
    ;;
esac
