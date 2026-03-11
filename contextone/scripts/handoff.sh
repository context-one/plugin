#!/usr/bin/env bash
set -euo pipefail

CRED_FILE="$HOME/.contextone/credentials.json"

# Check credentials
if [ ! -f "$CRED_FILE" ]; then
  echo "No credentials found. Run /contextone:login first." >&2
  exit 1
fi

# Check session ID
SESSION_ID="${1:-}"
if [ -z "$SESSION_ID" ]; then
  echo "No session ID found. CLAUDE_SESSION_ID is not set." >&2
  exit 1
fi

# Check git repo
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "No git origin remote configured." >&2
  exit 1
fi

# Resolve CLI
if command -v contextone >/dev/null 2>&1; then
  CLI=contextone
elif [ -x "$HOME/.local/bin/contextone" ]; then
  CLI="$HOME/.local/bin/contextone"
else
  echo "CLI not found. Run /contextone:login to install and authenticate." >&2
  exit 1
fi

# Extract token
TOKEN=$(grep -o '"access_token":"[^"]*"' "$CRED_FILE" | cut -d'"' -f4)
if [ -z "$TOKEN" ]; then
  echo "Invalid credentials. Run /contextone:login first." >&2
  exit 1
fi

"$CLI" handoff \
  --session-id "$SESSION_ID" \
  --cwd "$PWD" \
  --token="$TOKEN"
