#!/usr/bin/env bash
# Agents commit only on cycle/*, orchestrator/*, worker/*, or missing-req/*.
set -euo pipefail

branch="${1:-}"
if [[ -z "$branch" ]]; then
  if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
    branch="$GITHUB_REF_NAME"
  else
    branch="$(git rev-parse --abbrev-ref HEAD)"
  fi
fi

case "$branch" in
  cycle/* | orchestrator/* | worker/* | missing-req/*)
    exit 0
    ;;
  main | req/* | auto-feature/* | auto-fix/*)
    echo "assertAgentBranch: refuse commits on ${branch}" >&2
    exit 1
    ;;
  *)
    echo "assertAgentBranch: refuse commits on ${branch}" >&2
    exit 1
    ;;
esac
