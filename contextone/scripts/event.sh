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

# Build base arguments
ARGS=(event --type "$EVENT_TYPE" --session-id "$SESSION_ID" --project "$PROJECT")

# For session.start: add repo and worktree metadata
if [ "$EVENT_TYPE" = "session.start" ]; then
  GIT_OPTS=()
  if [ -n "$HOOK_CWD" ]; then
    GIT_OPTS=(-C "$HOOK_CWD")
  fi

  # Read owner/repo from git remote
  REMOTE_URL="$(git "${GIT_OPTS[@]}" remote get-url origin 2>/dev/null || true)"
  if [ -n "$REMOTE_URL" ]; then
    # Handle both SSH (git@github.com:owner/repo.git) and HTTPS (https://github.com/owner/repo.git)
    REPO="$(echo "$REMOTE_URL" | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s#\.git$##')"
    if [ -n "$REPO" ]; then
      ARGS+=(--repo "$REPO")
    fi
  fi

  # Detect worktree: if --git-dir and --git-common-dir differ, this is a worktree
  GIT_DIR="$(git "${GIT_OPTS[@]}" rev-parse --git-dir 2>/dev/null || true)"
  GIT_COMMON="$(git "${GIT_OPTS[@]}" rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$GIT_DIR" ] && [ -n "$GIT_COMMON" ] && [ "$GIT_DIR" != "$GIT_COMMON" ]; then
    ARGS+=(--worktree)
  fi
fi

# Dispatch: sync for session lifecycle, async for everything else
case "$EVENT_TYPE" in
  session.start)
    # 3-second timeout using Perl (macOS doesn't have GNU timeout)
    perl -e 'alarm 3; exec @ARGV' -- "$CLI" "${ARGS[@]}" 2>/dev/null || true
    ;;
  session.stop)
    # 3-second timeout using Perl (macOS doesn't have GNU timeout)
    perl -e 'alarm 3; exec @ARGV' -- "$CLI" "${ARGS[@]}" 2>/dev/null || true
    ;;
  *)
    # Background subshell — returns immediately; disown survives hook runner exit
    ("$CLI" "${ARGS[@]}" 2>/dev/null || true) &
    disown
    ;;
esac

exit 0
