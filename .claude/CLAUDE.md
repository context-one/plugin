# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Context One Plugin for Claude Code — a Claude Code plugin that integrates the Context One CLI for authentication and identity management. This is **not** a traditional Node.js/TypeScript project; it's a metadata-driven plugin using Claude Code's plugin framework.

## Architecture

Two-tier plugin registration:
- `.claude-plugin/marketplace.json` — registers the plugin collection for marketplace distribution
- `contextone/.claude-plugin/plugin.json` — individual plugin metadata (name, version, description)

Three skills defined as `SKILL.md` files in `contextone/skills/`:
- `auth/SKILL.md` — OAuth2 browser authentication via `contextone login`
- `logout/SKILL.md` — clears stored credentials via `contextone logout`
- `whoami/SKILL.md` — displays authenticated user via `contextone whoami`

All skills set `disable-model-invocation: true` since they are explicit user actions (auth flows) that Claude should not auto-invoke.

Each skill checks CLI availability with a fallback path (`contextone` → `~/.local/bin/contextone`), and triggers installation if the CLI is missing.

A `SessionStart` hook (`contextone/hooks/hooks.json`) runs `install-cli.sh` automatically to install/update the CLI binary on session start.

## CLI Installation Script

`contextone/scripts/install-cli.sh` downloads the Context One CLI binary:
- macOS only (arm64 and x86_64)
- Downloads from `CONTEXTONE_API_URL` (default: `https://contextone.dev`)
- Installs to `CONTEXTONE_INSTALL_DIR` (default: `~/.local/bin`)
- Channel controlled by `CONTEXTONE_CHANNEL` (default: `stable`)
- Uses `set -euo pipefail`; falls back from `jq` to `python3` for JSON parsing
- Idempotent — skips download if current version already installed

## Event Tracking

`contextone/scripts/event.sh` dispatches activity events to the Context One API:
- Called by all lifecycle hooks defined in `contextone/hooks/hooks.json`
- Receives event type as `$1` (e.g., `session.start`, `tool.read`)
- Uses `CLAUDE_SESSION_ID` from the hook environment
- Pre-flight checks: silently exits if no session ID, no credentials, or no CLI
- Sync for `session.start` and `session.stop`; async (backgrounded) for all other events
- **Exception to `set -euo pipefail` convention**: this script intentionally uses no strict mode — all failures must be silent to avoid breaking Claude Code sessions
- Design spec: `docs/superpowers/specs/2026-03-11-activity-dashboard-design.md`

## Development

There is no build step, linter, or automated test suite. Validation is manual:
- Test commands via `/contextone:auth`, `/contextone:logout`, `/contextone:whoami` in Claude Code
- Install script self-validates with `contextone --help`

## Conventions

- Conventional commits: `fix:`, `feat:`, `chore:`, etc.
- Shell scripts use `set -euo pipefail` with explicit stderr error messages (exception: `event.sh` uses no strict mode — see Event Tracking)
- Skills use YAML frontmatter for metadata

## Versioning

The plugin version in `contextone/.claude-plugin/plugin.json` follows semantic versioning and **must be bumped with every commit to main**:
- `fix:` → patch bump (e.g., 1.0.0 → 1.0.1)
- `feat:` → minor bump (e.g., 1.0.0 → 1.1.0)
- Breaking changes (`!` suffix or renamed/removed skills/commands) → major bump (e.g., 1.0.0 → 2.0.0)
- `chore:`, `docs:`, `refactor:` → patch bump
