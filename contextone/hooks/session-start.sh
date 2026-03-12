#!/usr/bin/env bash
# SessionStart hook — injects the using-contextone meta-skill into Claude's context

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SKILL_FILE="${PLUGIN_ROOT}/skills/using-contextone/SKILL.md"
SKILL_CONTENT=$(cat "$SKILL_FILE" 2>&1 || echo "Error reading using-contextone skill")

# Escape string for JSON embedding
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

escaped=$(escape_for_json "$SKILL_CONTENT")
context="<IMPORTANT>\nYou have contextone skills installed.\n\n**Below is your meta-skill for auto-invoking contextone skills. Follow it exactly:**\n\n${escaped}\n</IMPORTANT>"

cat <<EOF
{
  "additional_context": "${context}",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${context}"
  }
}
EOF

exit 0
