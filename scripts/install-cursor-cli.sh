#!/usr/bin/env bash
# Install Cursor CLI for headless agent (CI or local).
set -euo pipefail

if command -v agent >/dev/null 2>&1; then
  echo "install-cursor-cli: agent already on PATH ($(command -v agent))"
  exit 0
fi

curl https://cursor.com/install -fsS | bash
export PATH="${HOME}/.cursor/bin:${HOME}/.local/bin:${PATH}"
if ! command -v agent >/dev/null 2>&1; then
  echo "install-cursor-cli: agent not on PATH after install" >&2
  exit 1
fi
agent --version || true
