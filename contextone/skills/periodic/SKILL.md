---
name: periodic
description: Manage periodic jobs — schedule recurring tasks that run on a cron schedule in dedicated cloud sessions
---

# Contextone Periodic Jobs

Manage recurring tasks that execute automatically on a cron schedule. Each job runs in its own cloud session that you can inspect from the dashboard.

## Understanding the request

The user wants to manage periodic jobs. Parse their natural language request into one of these actions:

### List jobs
If the user wants to see their jobs (e.g. "show my periodic jobs", "list cron jobs", "what's scheduled"):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/periodic.sh" list
```

### Create a job
If the user wants to create a new job, extract these parameters from their request:
- **name**: a short kebab-case identifier (e.g. "daily-sync", "check-deps")
- **schedule**: a cron expression (e.g. "0 9 * * *" for daily at 9am, "0 */6 * * *" for every 6 hours)
- **prompt**: what the job should do — can be a plain text instruction or a skill invocation like `/contextone:skill args`
- **timeout_seconds** (optional): kill the job if it runs longer than this
- **workspace_path** (optional): directory name inside ~/workspace to start in (e.g. "my-repo")

Common cron patterns:
- Every hour: `0 * * * *`
- Every 6 hours: `0 */6 * * *`
- Daily at 9am: `0 9 * * *`
- Every Monday at 8am: `0 8 * * 1`
- Every 30 minutes: `*/30 * * * *`

#### Workspace path — IMPORTANT

When the user mentions a repository or project by name, you MUST set `--workspace-path` so the job runs in the correct directory. To resolve the right value:

1. List available workspaces first:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/periodic.sh" workspaces
```
This returns tab-separated lines: `owner/repo\tworkspace_path`

2. Match the user's repo reference against the output. The user might say just "rekindled", "my rekindled repo", or "readwiseio/rekindled" — match flexibly against both the full repo name and the workspace_path.

3. Use the `workspace_path` value from the match as `--workspace-path`.

If no match is found, ask the user which repo they mean and show the available list.

Do NOT ask the user for a repo path if they already named a repository — look it up from the workspaces list instead. Do NOT skip workspace_path when a repo is mentioned.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/periodic.sh" create \
  --name "<name>" \
  --schedule "<cron>" \
  --prompt "<prompt>"
```

Add `--timeout-seconds <N>` if the user specified a timeout.
Add `--workspace-path <dir>` if the user mentioned a repository or project (resolved from the workspaces list).

### Run a job now
If the user wants to trigger a job immediately (e.g. "run my-job now", "test this job", "execute it"):

If they refer to it by name, first list jobs to find the ID, then run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/periodic.sh" run --id <ID>
```

### Delete a job
If the user wants to remove a job, they may refer to it by name or ID. If by name, first list jobs to find the ID, then delete:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/periodic.sh" delete --id <ID>
```

## Instructions

1. Parse the user's natural language into the appropriate action and parameters. Extract as much as possible from what the user said — do NOT ask for information that can be reasonably inferred.
2. If the user mentions a repo/project, run the `workspaces` command first to resolve the correct workspace_path. Never ask the user for a repo path when they've already named the repo.
3. Only ask for clarification when truly essential information is missing — e.g. the user said "set up a cron job" without saying what the job should do.
4. Run the appropriate command using the Bash tool
5. Display the result clearly — for list, format as a readable table; for create, confirm the details; for delete, confirm what was removed
6. If the command fails, show the error and suggest next steps (e.g. "Run /contextone:login first")
