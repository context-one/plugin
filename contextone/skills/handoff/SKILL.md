---
name: handoff
description: Hand off the current Claude Code session to the Contextone cloud sandbox
disable-model-invocation: true
---

# Contextone Handoff

Transfer this session to the cloud sandbox so work can continue from the web UI.

Run the following command using the Bash tool:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/handoff.sh" "${CLAUDE_SESSION_ID}"
```

Display the result. If it succeeds, show the dashboard URL. If it fails, show the error and suggest next steps.
