#!/usr/bin/env bash
# Event dispatch script for Context One activity tracking.
# Called by Claude Code lifecycle hooks. Receives event type as $1.
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

# Pre-flight: session ID must be set by Claude Code
if [ -z "${CLAUDE_SESSION_ID:-}" ]; then
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

# Derive project name from git repo or working directory
PROJECT="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"

# Build base arguments
ARGS=(event --type "$EVENT_TYPE" --session-id "$CLAUDE_SESSION_ID" --project "$PROJECT")

# For session.start: add repo and worktree metadata
if [ "$EVENT_TYPE" = "session.start" ]; then
  # Parse owner/repo from git remote URL
  REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
  if [ -n "$REMOTE_URL" ]; then
    # Handle both SSH (git@github.com:owner/repo.git) and HTTPS (https://github.com/owner/repo.git)
    REPO="$(echo "$REMOTE_URL" | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s#\.git$##')"
    if [ -n "$REPO" ]; then
      ARGS+=(--repo "$REPO")
    fi
  fi

  # Detect worktree: if --git-dir and --git-common-dir differ, this is a worktree
  GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || true)"
  GIT_COMMON="$(git rev-parse --git-common-dir 2>/dev/null || true)"
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
