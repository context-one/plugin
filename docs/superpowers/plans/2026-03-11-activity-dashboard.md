# Activity Dashboard — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Claude Code lifecycle hooks and an event dispatch script so the plugin sends activity events to the contextone.dev API.

**Architecture:** All Claude Code lifecycle hooks (SessionStart, Stop, Notification, SubagentStop, PostToolUse) call a single `event.sh` script that resolves the CLI binary, performs pre-flight checks, and dispatches `contextone event` commands. Synchronous for session start/stop, async (backgrounded subshell) for everything else.

**Tech Stack:** Bash shell scripts, Claude Code plugin hooks (JSON), `contextone` CLI binary

**Spec:** `docs/superpowers/specs/2026-03-11-activity-dashboard-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `contextone/scripts/event.sh` | Create | Single event dispatch script — resolves CLI, pre-flight checks, routes sync vs async |
| `contextone/hooks/hooks.json` | Modify | Register all lifecycle hooks pointing to `event.sh` |

---

## Chunk 1: event.sh Script

### Task 1: Create event.sh with pre-flight checks

**Files:**
- Create: `contextone/scripts/event.sh`

- [ ] **Step 1: Create event.sh with the full implementation**

```bash
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
    "$CLI" "${ARGS[@]}" 2>/dev/null || true
    ;;
  session.stop)
    # 3-second timeout using Perl (macOS doesn't have GNU timeout)
    perl -e 'alarm 3; exec @ARGV' -- "$CLI" "${ARGS[@]}" 2>/dev/null || true
    ;;
  *)
    # Background subshell — returns immediately
    ("$CLI" "${ARGS[@]}" 2>/dev/null || true) &
    ;;
esac

exit 0
```

- [ ] **Step 2: Make event.sh executable**

Run: `chmod +x contextone/scripts/event.sh`

- [ ] **Step 3: Verify script syntax**

Run: `bash -n contextone/scripts/event.sh`
Expected: No output (no syntax errors)

- [ ] **Step 4: Verify script handles missing args gracefully**

Run: `bash contextone/scripts/event.sh`
Expected: Exits silently with code 0 (no event type provided)

Run: `echo $?`
Expected: `0`

- [ ] **Step 5: Verify script handles missing CLAUDE_SESSION_ID gracefully**

Run: `unset CLAUDE_SESSION_ID && bash contextone/scripts/event.sh session.start`
Expected: Exits silently with code 0

Run: `echo $?`
Expected: `0`

- [ ] **Step 6: Commit**

```bash
git add contextone/scripts/event.sh
git commit -m "feat: add event dispatch script for activity tracking

Single script called by all lifecycle hooks. Resolves CLI, checks
credentials and session ID, then dispatches contextone event command.
Sync for session start/stop, async for tool events."
```

---

## Chunk 2: hooks.json Registration

### Task 2: Update hooks.json to register all lifecycle hooks

**Files:**
- Modify: `contextone/hooks/hooks.json`

The existing file has only a `SessionStart` hook for `install-cli.sh`. We need to:
1. Add `event.sh session.start` to the existing `SessionStart` entry
2. Add new entries for `Stop`, `Notification`, `SubagentStop`, and `PostToolUse`

- [ ] **Step 1: Replace hooks.json with the full configuration**

Replace the entire contents of `contextone/hooks/hooks.json` with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/install-cli.sh"
          },
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh session.start"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "shutdown",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh session.stop"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "notification",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh notification"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "subagent",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh subagent.stop"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.read"
          }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.edit"
          }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.write"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.bash"
          }
        ]
      },
      {
        "matcher": "Glob",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.glob"
          }
        ]
      },
      {
        "matcher": "Grep",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.grep"
          }
        ]
      },
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.task"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate JSON syntax**

Run: `python3 -m json.tool contextone/hooks/hooks.json > /dev/null`
Expected: No output (valid JSON)

- [ ] **Step 3: Verify the existing SessionStart install hook is preserved**

Run: `grep -c "install-cli.sh" contextone/hooks/hooks.json`
Expected: `1`

- [ ] **Step 4: Verify all event types are registered**

Run: `grep -c "event.sh" contextone/hooks/hooks.json`
Expected: `11` (session.start, session.stop, notification, subagent.stop, tool.read, tool.edit, tool.write, tool.bash, tool.glob, tool.grep, tool.task)

- [ ] **Step 5: Commit**

```bash
git add contextone/hooks/hooks.json
git commit -m "feat: register all lifecycle hooks for activity tracking

Extends hooks.json with Stop, Notification, SubagentStop, and
PostToolUse matchers (Read, Edit, Write, Bash, Glob, Grep, Task).
All hooks call event.sh with the appropriate event type."
```

---

## Chunk 3: Documentation Update

### Task 3: Update CLAUDE.md to document the new hook and script

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add event tracking section to CLAUDE.md**

Add after the "CLI Installation Script" section:

```markdown
## Event Tracking

`contextone/scripts/event.sh` dispatches activity events to the Context One API:
- Called by all lifecycle hooks defined in `contextone/hooks/hooks.json`
- Receives event type as `$1` (e.g., `session.start`, `tool.read`)
- Uses `CLAUDE_SESSION_ID` from the hook environment
- Pre-flight checks: silently exits if no session ID, no credentials, or no CLI
- Sync for `session.start` and `session.stop`; async (backgrounded) for all other events
- **Exception to `set -euo pipefail` convention**: this script intentionally uses no strict mode — all failures must be silent to avoid breaking Claude Code sessions
- Design spec: `docs/superpowers/specs/2026-03-11-activity-dashboard-design.md`
```

- [ ] **Step 2: Update Conventions section to note the exception**

In the Conventions section, change the shell scripts line to:

```markdown
- Shell scripts use `set -euo pipefail` with explicit stderr error messages (exception: `event.sh` uses no strict mode — see Event Tracking)
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document event tracking in CLAUDE.md"
```
