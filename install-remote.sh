#!/usr/bin/env bash
# Remote installer for Claude Usage Statusline
# Usage: curl -fsSL https://raw.githubusercontent.com/rasmus8484/claude-usage-statusline/main/install-remote.sh | bash
set -e

INSTALL_DIR="$HOME/.claude/claude-usage-statusline"
REPO_URL="https://github.com/rasmus8484/claude-usage-statusline.git"

echo "=== Claude Usage Statusline — Remote Install ==="
echo ""

# Check prerequisites
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required but not installed."
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js is required but not installed."
  echo "Install it from https://nodejs.org/"
  exit 1
fi

if ! command -v bash >/dev/null 2>&1; then
  echo "ERROR: bash is required but not installed."
  exit 1
fi

# Clone or update
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Updating existing installation at $INSTALL_DIR..."
  git -C "$INSTALL_DIR" pull --ff-only
else
  if [ -d "$INSTALL_DIR" ]; then
    echo "ERROR: $INSTALL_DIR exists but is not a git repo. Remove it and try again."
    exit 1
  fi
  echo "Cloning to $INSTALL_DIR..."
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

echo ""

# Run the local install script
bash "$INSTALL_DIR/install.sh"
