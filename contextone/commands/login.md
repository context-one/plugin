---
name: login
description: Log in to Contextone via OAuth2 browser flow
---

# Contextone Login

Run the Contextone CLI login command to authenticate via OAuth2.

First, ensure the CLI is installed. Use the Bash tool to execute:

```bash
command -v contextone >/dev/null 2>&1 || ~/.local/bin/contextone --help >/dev/null 2>&1 || bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-cli.sh"
```

Then run:

```bash
contextone login || ~/.local/bin/contextone login
```

If the command succeeds, tell the user they are now logged in. If it fails, show the error output and suggest:
- Checking that the `contextone` binary is installed and on PATH
- Running `contextone --help` to verify the installation
