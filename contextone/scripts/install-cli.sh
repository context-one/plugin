#!/usr/bin/env bash
set -euo pipefail

CHANNEL="${CONTEXTONE_CHANNEL:-stable}"
INSTALL_DIR="${CONTEXTONE_INSTALL_DIR:-$HOME/.local/bin}"
API_URL="${CONTEXTONE_API_URL:-https://contextone.dev}"

# Detect platform
ARCH=$(uname -m)
case "$ARCH" in
  arm64|aarch64) TARGET="aarch64-apple-darwin" ;;
  x86_64)        TARGET="x86_64-apple-darwin" ;;
  *)             echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

echo "Fetching latest $CHANNEL release for $TARGET..."

# Query the public downloads endpoint
RELEASE_JSON=$(curl -fsSL "$API_URL/downloads.json")

# Extract version and download URL using jq, falling back to python3
parse_json() {
  local field="$1"
  if command -v jq >/dev/null 2>&1; then
    echo "$RELEASE_JSON" | jq -r "$field"
  else
    echo "$RELEASE_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
channel = data.get('$CHANNEL')
if not channel:
    print('No release in $CHANNEL channel', file=sys.stderr)
    sys.exit(1)
$([ "$field" = ".version" ] && echo "print(channel['version'])" || echo "
platforms = channel.get('platforms', {})
p = platforms.get('$TARGET')
if not p:
    print('No binary for $TARGET in $CHANNEL channel', file=sys.stderr)
    sys.exit(1)
print(p['download_url'])
")
"
  fi
}

VERSION=$(parse_json ".$CHANNEL.version")
DOWNLOAD_URL=$(parse_json ".$CHANNEL.platforms.\"$TARGET\".download_url")

if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  echo "No release found in $CHANNEL channel" >&2
  exit 1
fi

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
  echo "No binary for $TARGET in $CHANNEL channel" >&2
  exit 1
fi

# Check if already installed at this version
if [ -x "$INSTALL_DIR/contextone" ]; then
  INSTALLED_VERSION=$("$INSTALL_DIR/contextone" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
  if [ "$INSTALLED_VERSION" = "$VERSION" ]; then
    echo "contextone v$VERSION is already installed. Skipping download."
    exit 0
  fi
fi

echo "Installing contextone v$VERSION for $TARGET..."

# Download and install
mkdir -p "$INSTALL_DIR"
curl -fsSL "$DOWNLOAD_URL" | tar xz -C "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/contextone"

echo "Installed contextone v$VERSION to $INSTALL_DIR/contextone"

# Verify
if "$INSTALL_DIR/contextone" --help >/dev/null 2>&1; then
  echo "Verification passed."
else
  echo "Warning: contextone installed but --help check failed." >&2
fi

# Check PATH
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo ""
    echo "Warning: $INSTALL_DIR is not in your PATH."
    echo "Add it to your shell profile:"
    echo ""
    echo "  # bash (~/.bashrc or ~/.bash_profile)"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
    echo "  # zsh (~/.zshrc)"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
    echo "  # fish (~/.config/fish/config.fish)"
    echo "  fish_add_path $INSTALL_DIR"
    echo ""
    ;;
esac
