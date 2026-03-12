---
name: whoami
description: Show the currently authenticated Contextone user
disable-model-invocation: true
---

# Contextone Whoami

Run the following command using the Bash tool:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/whoami.sh"
```

Display the user info. If it fails with a 401 or authentication error, automatically invoke `/contextone:auth` and then retry the whoami command above.
