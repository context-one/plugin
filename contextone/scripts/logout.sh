#!/usr/bin/env bash
set -euo pipefail

CRED_FILE="$HOME/.contextone/credentials.json"

# Resolve CLI
if command -v contextone >/dev/null 2>&1; then
  CLI=contextone
elif [ -x "$HOME/.local/bin/contextone" ]; then
  CLI="$HOME/.local/bin/contextone"
else
  echo "CLI not found. Nothing to log out from." >&2
  rm -f "$CRED_FILE"
  exit 0
fi

"$CLI" logout || true
rm -f "$CRED_FILE"
echo "Logged out and credentials cleared."
