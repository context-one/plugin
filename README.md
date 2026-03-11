# Context One Plugin for Claude Code

Official Claude Code plugin for [Context One](https://contextone.dev). Provides CLI integration via slash commands and automatic binary installation.

## Installation

```
/plugin marketplace add context-one/plugin
/plugin install contextone
```

The CLI binary is automatically downloaded and installed to `~/.local/bin` during plugin installation.

## Commands

| Command | Description |
|---------|-------------|
| `/contextone:login` | Authenticate via OAuth2 browser flow |
| `/contextone:logout` | Clear stored credentials |
| `/contextone:whoami` | Show the currently authenticated user |

## Configuration

The install script supports these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `CONTEXTONE_CHANNEL` | `stable` | Release channel |
| `CONTEXTONE_INSTALL_DIR` | `~/.local/bin` | Binary install location |
| `CONTEXTONE_API_URL` | `https://contextone.dev` | API base URL |

## Platform Support

macOS only (Apple Silicon and Intel).

## Troubleshooting

**CLI not found after install:** Ensure `~/.local/bin` is in your PATH. The installer prints instructions if it detects this.

**Re-install CLI:** Reinstall the plugin to re-trigger the post-install hook:
```
/plugin install contextone
```

## License

Proprietary. All Rights Reserved. See [LICENSE](LICENSE).
