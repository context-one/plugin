---
name: whoami
description: Show the currently authenticated Contextone user
---

# Contextone Whoami

Run the Contextone CLI whoami command to display the current user.

First, ensure the CLI is installed. Use the Bash tool to execute:

```bash
command -v contextone >/dev/null 2>&1 || ~/.local/bin/contextone --help >/dev/null 2>&1 || bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-cli.sh"
```

Then run:

```bash
contextone whoami || ~/.local/bin/contextone whoami
```

Display the user information returned by the command. If the command fails with an authentication error, suggest running `/contextone:login` first.
