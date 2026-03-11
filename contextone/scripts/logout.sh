#!/usr/bin/env bash
set -euo pipefail

CRED_FILE="$HOME/.contextone/credentials.json"

if [ -f "$CRED_FILE" ]; then
  rm -f "$CRED_FILE"
  echo "Logged out and credentials cleared."
else
  echo "No credentials found. Already logged out."
fi
