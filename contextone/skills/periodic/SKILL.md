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

Common cron patterns:
- Every hour: `0 * * * *`
- Every 6 hours: `0 */6 * * *`
- Daily at 9am: `0 9 * * *`
- Every Monday at 8am: `0 8 * * 1`
- Every 30 minutes: `*/30 * * * *`

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/periodic.sh" create \
  --name "<name>" \
  --schedule "<cron>" \
  --prompt "<prompt>"
```

Add `--timeout-seconds <N>` if the user specified a timeout.

### Delete a job
If the user wants to remove a job, they may refer to it by name or ID. If by name, first list jobs to find the ID, then delete:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/periodic.sh" delete --id <ID>
```

## Instructions

1. Parse the user's natural language into the appropriate action and parameters
2. If the request is ambiguous (e.g. "set up a cron job" without details), ask what they want the job to do, how often, and what to name it
3. Run the appropriate command using the Bash tool
4. Display the result clearly — for list, format as a readable table; for create, confirm the details; for delete, confirm what was removed
5. If the command fails, show the error and suggest next steps (e.g. "Run /contextone:login first")
