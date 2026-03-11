#!/usr/bin/env bash
# Event dispatch script for Context One activity tracking.
# Called by Claude Code lifecycle hooks. Receives event type as $1.
# Hook JSON payload is read from stdin (see https://code.claude.com/docs/en/hooks).
#
# Unlike other scripts in this repo, this script does NOT use
# set -euo pipefail — all failures must be silent to avoid
# breaking Claude Code sessions.

EVENT_TYPE="${1:-}"
CRED_FILE="$HOME/.contextone/credentials.json"

# Pre-flight: event type is required
if [ -z "$EVENT_TYPE" ]; then
  exit 0
fi

# Read hook JSON payload from stdin
HOOK_INPUT="$(cat)"

# Extract session_id from the hook payload
SESSION_ID="$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
if [ -z "$SESSION_ID" ]; then
  # Fallback: try python3 if jq is not available
  SESSION_ID="$(echo "$HOOK_INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)"
fi

# Pre-flight: session ID must be present in the hook payload
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# Pre-flight: user must be logged in
if [ ! -f "$CRED_FILE" ]; then
  exit 0
fi

# Resolve CLI binary (same pattern as whoami.sh, login.sh)
if command -v contextone >/dev/null 2>&1; then
  CLI=contextone
elif [ -x "$HOME/.local/bin/contextone" ]; then
  CLI="$HOME/.local/bin/contextone"
else
  exit 0
fi

# Derive project name from the hook payload cwd, falling back to git/pwd
HOOK_CWD="$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
if [ -n "$HOOK_CWD" ]; then
  PROJECT="$(basename "$(git -C "$HOOK_CWD" rev-parse --show-toplevel 2>/dev/null || echo "$HOOK_CWD")")"
else
  PROJECT="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
fi

# Build base arguments — CLI auto-detects repo and worktree from --cwd
ARGS=(event --type "$EVENT_TYPE" --session-id "$SESSION_ID" --project "$PROJECT")
if [ -n "$HOOK_CWD" ]; then
  ARGS+=(--cwd "$HOOK_CWD")
fi

# Dispatch: sync for session lifecycle, async for everything else
case "$EVENT_TYPE" in
  session.start)
    # 3-second timeout using Perl (macOS doesn't have GNU timeout)
    perl -e 'alarm 3; exec @ARGV' -- "$CLI" "${ARGS[@]}" 2>/dev/null || true
    ;;
  memory.extract)
    HOOK_CWD_RESOLVED="${HOOK_CWD:-$(pwd)}"
    ("$CLI" extract --session-id "$SESSION_ID" --cwd "$HOOK_CWD_RESOLVED" --mode incremental 2>/dev/null || true) &
    disown
    ;;
  session.stop)
    # Send event synchronously (3s timeout)
    perl -e 'alarm 3; exec @ARGV' -- "$CLI" "${ARGS[@]}" 2>/dev/null || true
    # Launch final memory extraction in background (fire-and-forget)
    HOOK_CWD_RESOLVED="${HOOK_CWD:-$(pwd)}"
    ("$CLI" extract --session-id "$SESSION_ID" --cwd "$HOOK_CWD_RESOLVED" --mode final 2>/dev/null || true) &
    disown
    ;;
  *)
    # Background subshell — returns immediately; disown survives hook runner exit
    ("$CLI" "${ARGS[@]}" 2>/dev/null || true) &
    disown
    ;;
esac

exit 0
