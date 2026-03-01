#!/usr/bin/env bash
# Install script for Claude Session Limit Scraper
# Updates ~/.claude/settings.json to use the new statusline
# and runs an initial data fetch.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSLINE_SRC="$SCRIPT_DIR/statusline.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "=== Claude Session Limit Scraper — Install ==="
echo ""

# Verify files exist
if [ ! -f "$STATUSLINE_SRC" ]; then
  echo "ERROR: statusline.sh not found at $STATUSLINE_SRC"
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/scraper.mjs" ]; then
  echo "ERROR: scraper.mjs not found at $SCRIPT_DIR"
  exit 1
fi

# Make scripts executable
chmod +x "$STATUSLINE_SRC"

# Backup current statusline if it exists
if [ -f "$HOME/.claude/statusline-command.sh" ]; then
  cp "$HOME/.claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh.bak"
  echo "Backed up existing statusline to statusline-command.sh.bak"
fi

# Update settings.json to point to our statusline
if [ -f "$SETTINGS_FILE" ]; then
  # Use node to safely modify JSON — pass paths via env vars to avoid shell/Windows path issues
  SETTINGS_PATH="$SETTINGS_FILE" STATUSLINE_PATH="$STATUSLINE_SRC" node -e '
    const fs = require("fs");
    const path = require("path");
    const settingsPath = path.resolve(process.env.SETTINGS_PATH);
    const statuslinePath = process.env.STATUSLINE_PATH.replace(/\\/g, "/");
    const settings = JSON.parse(fs.readFileSync(settingsPath, "utf-8"));
    // Wrapper captures terminal width before Claude Code pipes stdin
    const cmd = "bash -c " + JSON.stringify("COLS=$(tput cols 2>/dev/null || echo 80); cat | COLS=$COLS bash " + statuslinePath);
    settings.statusLine = { type: "command", command: cmd };
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
    console.log("Updated settings.json statusLine command");
  '
else
  echo "WARNING: $SETTINGS_FILE not found. Create it manually or run Claude Code first."
fi

# Run initial scrape
echo ""
echo "Running initial data fetch..."
node "$SCRIPT_DIR/scraper.mjs"

echo ""
echo "Installation complete!"
echo "The status bar will update on your next Claude Code interaction."
echo "To manually refresh usage data: node $SCRIPT_DIR/scraper.mjs"
