---
name: login
description: Log in to Contextone via OAuth2 browser flow
disable-model-invocation: true
---

# Contextone Login

Run the following command using the Bash tool:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/login.sh"
```

If the output contains `access_token`, confirm login succeeded. If it fails, show the error.
