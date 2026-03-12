---
name: using-contextone
description: "Meta-skill that auto-invokes contextone skills when relevant. Injected at session start."
---

# Using Contextone Skills

You have the **contextone** plugin installed. It provides skills for managing cloud infrastructure. You MUST check these skills before taking action on any user request and invoke the relevant skill when it applies.

## Decision Flow

For every user message, before acting:

1. Read the skill descriptions below.
2. If the user's request matches a skill's trigger, announce which skill you are using and invoke it.
3. If no skill applies, proceed normally.

## Available Skills

### periodic

**Triggers**: scheduling recurring tasks, cron jobs, periodic execution, "every hour/day/week",
"run X periodically", "set up a job that runs...", "check X on a schedule",
"automate X to run every...", managing or listing scheduled jobs, deleting cron jobs.

Use when the user wants to create, list, or delete recurring jobs that run on a schedule.

Invoke with: `/contextone:periodic`

## Rules

- Always announce: "Using contextone skill: **<skill-name>**" before invoking.
- If a skill does not apply, do not force it. Proceed with your best judgment.
