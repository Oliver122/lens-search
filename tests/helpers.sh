#!/usr/bin/env bash
# Shared fixtures for policy tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -b main >/dev/null
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  mkdir -p "$dir/scripts" "$dir/requirements/_template"
  cp -a "$ROOT/scripts/." "$dir/scripts/"
  cp -a "$ROOT/requirements/_template/." "$dir/requirements/_template/"
  echo x > "$dir/README.md"
  git -C "$dir" add README.md scripts requirements
  git -C "$dir" commit -m init >/dev/null
}

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [[ "$got" != "$want" ]]; then
    echo "assert_eq failed: ${msg}" >&2
    echo "  got:  ${got}" >&2
    echo "  want: ${want}" >&2
    return 1
  fi
}

assert_fail() {
  local msg="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "assert_fail: expected failure: ${msg}" >&2
    return 1
  fi
}

assert_ok() {
  local msg="$1"
  shift
  if ! "$@" >/dev/null 2>&1; then
    echo "assert_ok: expected success: ${msg}" >&2
    return 1
  fi
}
