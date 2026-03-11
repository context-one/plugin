---
name: logout
description: Log out of Contextone and clear stored credentials
---

# Contextone Logout

Run the Contextone CLI logout command to clear stored credentials.

First, ensure the CLI is installed. Use the Bash tool to execute:

```bash
command -v contextone >/dev/null 2>&1 || ~/.local/bin/contextone --help >/dev/null 2>&1 || bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-cli.sh"
```

Then run:

```bash
contextone logout || ~/.local/bin/contextone logout
```

If the command succeeds, tell the user they are now logged out. If it fails, show the error output.
