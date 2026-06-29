#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "Session start hook running..."

# --- Add dependency installation here as the project grows ---
# Examples:
#   pip install -r requirements.txt
#   npm install
#   poetry install

echo "Session start hook complete."
