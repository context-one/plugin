# Activity Dashboard — Design Spec

## Overview

A team activity dashboard for Context One that tracks Claude Code session activity across team members. The plugin captures a full event stream from Claude Code lifecycle hooks, sends events to the contextone.dev API, and displays them on a web-based dashboard.

## Audience

**Individual + team**: Each user sees their own detailed stats (sessions, tool counts, activity rate) with a compact feed of teammate activity below.

## Architecture

### Event Pipeline

```
Claude Code Hooks → event.sh → contextone event CLI → POST /api/v1/events → contextone.dev DB
```

- **Approach**: Thin hook scripts with direct API calls (Approach A)
- **Delivery**: Async / fire-and-forget — `event.sh` backgrounds the API call internally (via subshell `(...) &`), so Claude Code's hook runner does not need to support shell `&` syntax. The `Stop` hook runs synchronously (with a 3-second timeout) to ensure delivery before process exit. The `session.start` hook also runs synchronously since it carries critical metadata (repo, worktree) and the one-time latency at session start is negligible.
- **Session identity**: Uses `CLAUDE_SESSION_ID` provided by Claude Code's hook environment

### Event Types

| Hook Matcher | Event Type | Notes |
|---|---|---|
| SessionStart | `session.start` | Synchronous; includes repo, worktree metadata |
| Stop | `session.stop` | Synchronous (3s timeout) |
| Notification | `notification` | Background |
| SubagentStop | `subagent.stop` | Background |
| PostToolUse:Read | `tool.read` | Background |
| PostToolUse:Edit | `tool.edit` | Background |
| PostToolUse:Write | `tool.write` | Background |
| PostToolUse:Bash | `tool.bash` | Background |
| PostToolUse:Glob | `tool.glob` | Background |
| PostToolUse:Grep | `tool.grep` | Background |
| PostToolUse:Task | `tool.task` | Background |

### Event Payload

Standard payload for all events:

```json
{
  "v": 1,
  "session_id": "claude-session-uuid",
  "event_type": "tool.read",
  "project": "plugin",
  "timestamp": "2026-03-11T15:30:00Z"
}
```

The `session.start` event includes additional metadata:

```json
{
  "v": 1,
  "session_id": "claude-session-uuid",
  "event_type": "session.start",
  "project": "plugin",
  "timestamp": "2026-03-11T15:30:00Z",
  "repo": "context-one/plugin",
  "worktree": false
}
```

- **`v`**: Schema version, always `1` for this version
- **`project`**: Derived via `basename $(git rev-parse --show-toplevel 2>/dev/null || pwd)`
- **`repo`**: `owner/repo` parsed from `git remote get-url origin` (session.start only)
- **`worktree`**: Boolean, detected by comparing `git rev-parse --git-dir` vs `--git-common-dir` (session.start only)
- No file paths, content, or PII in any payload

### API Endpoint

```
POST /api/v1/events
Authorization: Bearer <access_token>
Content-Type: application/json
```

The backend identifies the user from the bearer token and groups events by user, session, and team.

## Plugin Changes

### hooks.json

Extends the existing hooks.json (which currently has only `SessionStart` for CLI install) to register matchers for all lifecycle events. The format follows the existing nested-object structure where each top-level key is a hook type, and each entry has a `matcher` field:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/install-cli.sh" },
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh session.start" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "shutdown",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh session.stop" }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "notification",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh notification" }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "subagent",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh subagent.stop" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.read" }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.edit" }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.write" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.bash" }
        ]
      },
      {
        "matcher": "Glob",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.glob" }
        ]
      },
      {
        "matcher": "Grep",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.grep" }
        ]
      },
      {
        "matcher": "Task",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/event.sh tool.task" }
        ]
      }
    ]
  }
}
```

**Note on async execution**: The `event.sh` script handles backgrounding internally via `(...) &` subshells rather than relying on shell `&` in the command string. This ensures async behavior works regardless of how Claude Code's hook runner invokes the command. The exceptions are `session.start` and `session.stop` which run synchronously (see event.sh section).

**Note on SessionStart coupling**: The install and event hooks share a single `"startup"` matcher entry. If `install-cli.sh` fails (e.g., unsupported architecture), `event.sh` may not run. This is acceptable because if the CLI is not installed, the event command cannot execute anyway. To decouple them in the future, add a second entry under `"SessionStart"` with a different matcher name.

### contextone/scripts/event.sh

A single shell script that handles all event types. Receives the event type as `$1`.

Responsibilities:
1. Resolve the CLI binary (same pattern as existing scripts: `command -v contextone` → `~/.local/bin/contextone`)
2. Pre-flight check: verify `~/.contextone/credentials.json` exists (exit 0 silently if not — user not logged in)
3. For `session.start`: detect git repo (`git remote get-url origin` → parse to `owner/repo`) and worktree status
4. Derive project name via `basename $(git rev-parse --show-toplevel 2>/dev/null || pwd)`
5. Call `contextone event --type $1 --session-id $CLAUDE_SESSION_ID --project <project> [--repo <owner/repo>] [--worktree]`

The CLI itself reads the access token from credentials — the script only checks credentials exist as a pre-flight gate.

Key behaviors:
- `set -euo pipefail` is NOT used here (unlike other scripts) — failures must be silent
- If `CLAUDE_SESSION_ID` is unset or empty, exit 0 silently
- If no credentials found, exit 0 silently (user not logged in)
- If CLI not found, exit 0 silently (not yet installed)
- For `session.start` and `session.stop`: runs the CLI call synchronously (blocking). `session.stop` uses a 3-second timeout so a hung API cannot freeze session teardown. Since macOS does not ship GNU `timeout`, the script uses a Perl one-liner as a portable alternative: `perl -e 'alarm 3; exec @ARGV' -- contextone event ...`
- For all other event types: runs the CLI call in a backgrounded subshell (`(contextone event ... &)`) so hook execution returns immediately
- Token expiry: the CLI is responsible for handling token refresh. If the token is expired and cannot be refreshed, the CLI exits 0 silently (fire-and-forget)

### CLI Command: `contextone event`

New subcommand added to the Context One CLI binary:

```
contextone event \
  --type <event_type> \
  --session-id <session_id> \
  --project <project_name> \
  [--repo <owner/repo>] \
  [--worktree]
```

The CLI:
1. Reads the stored token from credentials
2. Constructs the JSON payload with current UTC timestamp
3. POSTs to `/api/v1/events`
4. Exits with 0 regardless of API response (fire-and-forget)

## Frontend: Activity Dashboard

### Location

Web page at `https://contextone.dev/activity` (or similar route), accessible after authentication.

### Layout: Personal + Team Feed

The dashboard has two sections:

**1. Your Stats Card** (prominent, top)
- Status indicator (green dot = active session exists)
- Username
- Activity sparkline (bar chart showing recent event density)
- Session count
- Aggregate stats: total events, events/min rate, total active time
- Tool breakdown pills (Read N, Edit N, Bash N, etc.)
- Session list: each row shows:
  - Active/inactive dot
  - GitHub repo link (`owner/repo` linking to `https://github.com/owner/repo`)
  - Worktree badge (small pill) if the session is in a git worktree
  - Last event type pill
  - Relative timestamp ("just now", "3m ago")

**2. Team Activity Feed** (compact list, below)
- One row per teammate with recent activity
- Each row: status dot, username, GitHub repo link, worktree badge (if applicable), event count, relative timestamp
- Inactive members are visually dimmed (reduced opacity)
- Sorted by recency (most recently active first)

### Derived Metrics (computed server-side)

- **Active session**: Has `session.start` without `session.stop`, AND received an event in the last 5 minutes
- **Active time**: Sum of intervals between consecutive events within a session (capped at 5-minute gaps)
- **Events/min**: Total events / active time in minutes
- **Tool counts**: Count of events grouped by `event_type` prefix `tool.*`

### Visual Design

- Dark theme matching contextone.dev
- GitHub-style color palette: `#0d1117` background, `#161b22` card backgrounds, `#30363d` borders
- Green `#3fb950` for active indicators, `#484f58` for inactive
- Blue `#58a6ff` for GitHub repo links
- Monospace-adjacent system font stack

### Real-time Updates

The dashboard polls the API on a regular interval (e.g., every 10 seconds) to refresh the activity feed. SSE or WebSocket can be added later for true real-time if needed, but polling is sufficient for v1.

## Files Changed

| File | Action | Description |
|---|---|---|
| `contextone/hooks/hooks.json` | Modify | Add matchers for all lifecycle hooks |
| `contextone/scripts/event.sh` | Create | New script to send events via CLI |
| CLI binary (separate repo) | Modify | Add `contextone event` subcommand |
| Backend API (separate repo) | Modify | Add `POST /api/v1/events` endpoint |
| Frontend (separate repo) | Create | Activity dashboard page |

## Known Limitations & Future Considerations

- **macOS only**: The CLI install script (and therefore the entire event pipeline) only supports macOS (arm64 and x86_64). Linux/Windows support requires expanding the install script and CLI distribution.
- **`CLAUDE_PLUGIN_ROOT`**: Resolves to the `contextone/` directory (the individual plugin root, not the repo root), consistent with how `install-cli.sh` is already referenced in the existing hooks.json.
- **Excluded tool types**: WebSearch, WebFetch, NotebookEdit, and MCP tool invocations are not tracked in v1. Additional PostToolUse matchers can be added incrementally without schema changes.
- **No client-side throttling**: High-frequency tool use (rapid Glob/Grep during search) spawns many background processes. If this becomes a problem, `event.sh` can implement simple throttling (skip if last event of same type was <1s ago using a lockfile). The backend should also rate-limit per session.
- **Sleep/resume**: If a machine sleeps for >5 minutes then resumes, the session may briefly appear inactive then snap back to active on next tool use. This is expected behavior — no new `session.start` is needed.
- **Heartbeat**: Active time is computed from inter-event gaps capped at 5 minutes. Long reading periods with no tool use will undercount active time. A periodic heartbeat could improve accuracy in v2.

## Scope Boundaries

**In scope (this plugin repo)**:
- hooks.json changes
- event.sh script
- API contract definition

**Out of scope (separate repos/work)**:
- CLI `event` subcommand implementation
- Backend API endpoint and database schema
- Frontend dashboard implementation
- Real-time delivery (WebSocket/SSE) — v2
