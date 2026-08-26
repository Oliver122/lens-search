#!/usr/bin/env bash
# Subtask coder: one specified test, sequentially on the primary checkout
# (accumulated code; no worktrees). Sole owner of the agent environment checks.
# Exit 2 = environment problem (the orchestrator aborts instead of counting it
# as a red attempt). Any other failure folds into the red-attempt path.
set -euo pipefail

slug="${1:?slug required}"
n="${2:?subtask number required}"
failure_log="${3:-}"
root="$(git rev-parse --show-toplevel)"
cd "$root"

# Note: --absolute-git-common-dir does not exist; realpath both for comparison.
git_dir_abs="$(realpath "$(git rev-parse --git-dir)")"
common_abs="$(realpath "$(git rev-parse --git-common-dir)")"
if [[ "$git_dir_abs" != "$common_abs" ]]; then
  echo "run-subtask-coder: must run on the primary checkout, not a worktree" >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
"${root}/scripts/assert-agent-branch.sh" "$branch"

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "run-subtask-coder: CURSOR_API_KEY is unset" >&2
  exit 2
fi

if [[ -n "${AGENT_BIN:-}" ]]; then
  agent_bin="$AGENT_BIN"
else
  if ! command -v agent >/dev/null 2>&1; then
    export PATH="${HOME}/.cursor/bin:${HOME}/.local/bin:${PATH}"
  fi
  if ! command -v agent >/dev/null 2>&1; then
    echo "run-subtask-coder: agent not on PATH; run scripts/install-cursor-cli.sh" >&2
    exit 2
  fi
  agent_bin="$(command -v agent)"
fi

prompt="$("${root}/scripts/build-subtask-prompt.sh" "$slug" "$n" ${failure_log:+"$failure_log"})"
if [[ -n "${ORCH_PROMPT_DIR:-}" ]]; then
  mkdir -p "$ORCH_PROMPT_DIR"
  printf '%s' "$prompt" > "${ORCH_PROMPT_DIR}/prompt-${n}.txt"
fi

model="${CURSOR_AGENT_MODEL:-cursor-grok-4.6-medium}"
log="${root}/scripts/ci-agent-log.py"
echo "run-subtask-coder: slug=${slug} subtask=${n} model=${model} retry=$([[ -n "$failure_log" ]] && echo yes || echo no)"

agent_cmd=("$agent_bin" -p --force --model "$model" --output-format stream-json)
if [[ -f "$log" ]]; then
  "${agent_cmd[@]}" "$prompt" | python3 "$log"
else
  "${agent_cmd[@]}" "$prompt"
fi
