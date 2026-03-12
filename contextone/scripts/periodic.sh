#!/usr/bin/env bash
set -euo pipefail

CRED_FILE="$HOME/.contextone/credentials.json"

# Check credentials
if [ ! -f "$CRED_FILE" ]; then
  echo "No credentials found. Run /contextone:login first." >&2
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

ACTION="${1:-list}"
shift || true

case "$ACTION" in
  list)
    "$CLI" periodic-list --token="$TOKEN"
    ;;
  workspaces)
    "$CLI" workspace-list --token="$TOKEN"
    ;;
  create)
    "$CLI" periodic-create --token="$TOKEN" "$@"
    ;;
  run)
    "$CLI" periodic-run --token="$TOKEN" "$@"
    ;;
  delete)
    "$CLI" periodic-delete --token="$TOKEN" "$@"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    echo "Usage: periodic.sh <list|workspaces|create|run|delete> [args...]" >&2
    exit 1
    ;;
esac
