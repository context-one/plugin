#!/usr/bin/env bash
set -euo pipefail

CRED_FILE="$HOME/.contextone/credentials.json"

# Check credentials exist
if [ ! -f "$CRED_FILE" ]; then
  echo "No credentials found. Run /contextone:auth first." >&2
  exit 1
fi

# Extract token
TOKEN=$(grep -o '"access_token":"[^"]*"' "$CRED_FILE" | cut -d'"' -f4)
if [ -z "$TOKEN" ]; then
  echo "Invalid credentials. Run /contextone:auth first." >&2
  exit 1
fi

# Resolve CLI
if command -v contextone >/dev/null 2>&1; then
  CLI=contextone
elif [ -x "$HOME/.local/bin/contextone" ]; then
  CLI="$HOME/.local/bin/contextone"
else
  echo "CLI not found. Run /contextone:auth to install and authenticate." >&2
  exit 1
fi

"$CLI" whoami --token "$TOKEN"
