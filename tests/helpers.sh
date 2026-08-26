#!/usr/bin/env bash
# Shared fixtures for policy tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Policy tests are local-only; do not inherit CI push flags or orchestrator seams.
unset OPEN_AUTO_FEATURE_PUSH OPEN_AUTO_FEATURE_MR OPEN_MISSING_REQ_PUSH OPEN_MISSING_REQ_COMMENT OPEN_AUTO_FIX_PUSH
unset ORCH_VERIFY_BIN ORCH_TRACE ORCH_PROMPT_DIR ORCH_AGENT_SLEEP FAKE_VERIFIER_PLAN FAKE_VERIFIER_COUNT

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

install_test_agent() {
  local dest="$1"
  mkdir -p "$dest"
  cp "$ROOT/tests/fake-agent.sh" "$dest/agent"
  chmod +x "$dest/agent"
  export AGENT_BIN="$dest/agent"
  export PATH="${dest}:${PATH}"
}

install_test_verifier() {
  export ORCH_VERIFY_BIN="$ROOT/tests/fake-verifier.sh"
}

# make_repo + two-test spec + open-auto-feature; leaves cwd on auto-feature/<slug>.
make_feature_repo() {
  local dir="$1" slug="$2"
  make_repo "$dir"
  cd "$dir"
  mkdir -p "requirements/${slug}"
  echo "overview for ${slug}" > "requirements/${slug}/overview.md"
  printf '1. First check for %s\n2. Second check for %s\n' "$slug" "$slug" \
    > "requirements/${slug}/specified-tests.md"
  git add requirements && git commit -m "spec ${slug}" >/dev/null
  git checkout -b "req/${slug}" >/dev/null
  ./scripts/open-auto-feature.sh "$slug" >/dev/null
  git checkout "auto-feature/${slug}" >/dev/null
}
