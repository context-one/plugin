#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CRED_DIR="$HOME/.contextone"
CRED_FILE="$CRED_DIR/credentials.json"

# Resolve CLI binary
if command -v contextone >/dev/null 2>&1; then
  CLI=contextone
elif [ -x "$HOME/.local/bin/contextone" ]; then
  CLI="$HOME/.local/bin/contextone"
else
  echo "CLI not found. Installing..." >&2
  bash "$SCRIPT_DIR/install-cli.sh"
  CLI="$HOME/.local/bin/contextone"
fi

# Run login
OUTPUT=$("$CLI" login 2>&1)
echo "$OUTPUT"

# Persist credentials
mkdir -p "$CRED_DIR"
echo "$OUTPUT" > "$CRED_FILE"
chmod 600 "$CRED_FILE"
