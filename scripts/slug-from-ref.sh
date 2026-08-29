#!/usr/bin/env bash
# Print slug from req/, cycle/, orchestrator/, worker/<slug>/..., missing-req/.
set -euo pipefail

ref="${1:?ref required}"
ref="${ref#refs/heads/}"

case "$ref" in
  req/*) echo "${ref#req/}" ;;
  cycle/*) echo "${ref#cycle/}" ;;
  orchestrator/*) echo "${ref#orchestrator/}" ;;
  missing-req/*) echo "${ref#missing-req/}" ;;
  worker/*)
    rest="${ref#worker/}"
    echo "${rest%%/*}"
    ;;
  *)
    echo "slug-from-ref: not a cycle branch: ${ref}" >&2
    exit 1
    ;;
esac
