#!/usr/bin/env bash
# Subtask coder: one specified test, in a git worktree (not the primary checkout).
set -euo pipefail

slug="${1:?slug required}"
n="${2:?subtask number required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git rev-parse --show-toplevel)"
cd "$root"

git_dir_abs="$(git rev-parse --absolute-git-dir)"
common_abs="$(git rev-parse --absolute-git-common-dir)"
if [[ "$git_dir_abs" == "$common_abs" ]]; then
  echo "run-subtask-coder: must run in a distinct git worktree, not the primary tree" >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
"${script_dir}/assert-agent-branch.sh" "$branch"

req="requirements/${slug}"
if [[ ! -f "${req}/CYCLE" ]]; then
  echo "run-subtask-coder: missing CYCLE; openAutoFeature must run first" >&2
  exit 1
fi

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "run-subtask-coder: CURSOR_API_KEY is unset" >&2
  exit 1
fi

if [[ -n "${AGENT_BIN:-}" ]]; then
  agent_bin="$AGENT_BIN"
else
  if ! command -v agent >/dev/null 2>&1; then
    export PATH="${HOME}/.cursor/bin:${HOME}/.local/bin:${PATH}"
  fi
  if ! command -v agent >/dev/null 2>&1; then
    echo "run-subtask-coder: agent not on PATH; run scripts/install-cursor-cli.sh" >&2
    exit 1
  fi
  agent_bin="$(command -v agent)"
fi

prompt="$("${script_dir}/build-subtask-prompt.sh" "$slug" "$n")"
if [[ -n "${ORCH_PROMPT_DIR:-}" ]]; then
  mkdir -p "$ORCH_PROMPT_DIR"
  printf '%s' "$prompt" > "${ORCH_PROMPT_DIR}/prompt-${n}.txt"
fi

author_email="${GIT_AUTHOR_EMAIL:-bot@local}"
author_name="${GIT_AUTHOR_NAME:-auto-feature}"

model="${CURSOR_AGENT_MODEL:-cursor-grok-4.6-medium}"
log="${script_dir}/ci-agent-log.py"
echo "run-subtask-coder: slug=${slug} subtask=${n} model=${model} tree=${root}"

# Subtask worktrees are not the MR head; never push from here.
unset OPEN_AUTO_FEATURE_PUSH || true

agent_cmd=("$agent_bin" -p --force --model "$model" --output-format stream-json)
if [[ -f "$log" ]]; then
  "${agent_cmd[@]}" "$prompt" | python3 "$log"
else
  "${agent_cmd[@]}" "$prompt"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git -c user.email="$author_email" \
      -c user.name="$author_name" \
      commit -m "coder(${slug}): ${n} leftover"
fi
