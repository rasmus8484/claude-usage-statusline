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

# Check prerequisites
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js is required but not installed."
  echo "Install it from https://nodejs.org/"
  exit 1
fi

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

WRAPPER="$HOME/.claude/statusline-wrapper.sh"

# Update settings.json to point to our statusline
if [ -f "$SETTINGS_FILE" ]; then
  # Use node to safely modify JSON — pass paths via env vars to avoid shell/Windows path issues
  SETTINGS_PATH="$SETTINGS_FILE" STATUSLINE_PATH="$STATUSLINE_SRC" WRAPPER_PATH="$WRAPPER" node -e '
    const fs = require("fs");
    const path = require("path");
    const settingsPath = path.resolve(process.env.SETTINGS_PATH);
    const statuslinePath = process.env.STATUSLINE_PATH.replace(/\\/g, "/");
    const wrapperPath = process.env.WRAPPER_PATH.replace(/\\/g, "/");
    const settings = JSON.parse(fs.readFileSync(settingsPath, "utf-8"));
    const ourCmd = "bash " + statuslinePath;
    const wrapperCmd = "bash " + wrapperPath;
    const existing = settings.statusLine?.command;

    if (existing && existing !== ourCmd && existing !== wrapperCmd) {
      // Existing statusline found — create a wrapper that runs both
      console.log("Existing statusLine command found: " + existing);
      console.log("Creating wrapper to combine both statuslines");
      const wrapper = [
        "#!/usr/bin/env bash",
        "# Auto-generated wrapper — runs existing statusline + usage bar",
        "# Existing: " + existing,
        "",
        "STDIN_DATA=$(cat)",
        "EXISTING_OUT=$(echo \"$STDIN_DATA\" | " + existing + " 2>/dev/null)",
        "USAGE_OUT=$(echo \"$STDIN_DATA\" | bash " + statuslinePath + " 2>/dev/null)",
        "",
        "if [ -n \"$EXISTING_OUT\" ] && [ -n \"$USAGE_OUT\" ]; then",
        "  printf \"%s  %s\" \"$EXISTING_OUT\" \"$USAGE_OUT\"",
        "elif [ -n \"$USAGE_OUT\" ]; then",
        "  printf \"%s\" \"$USAGE_OUT\"",
        "else",
        "  printf \"%s\" \"$EXISTING_OUT\"",
        "fi",
      ].join("\n") + "\n";
      fs.writeFileSync(wrapperPath, wrapper);
      settings.statusLine = { type: "command", command: wrapperCmd };
    } else {
      // No existing statusline or already ours — point directly
      settings.statusLine = { type: "command", command: ourCmd };
    }

    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
    console.log("Updated settings.json statusLine command");
  '
else
  echo "WARNING: $SETTINGS_FILE not found. Create it manually or run Claude Code first."
fi

# Run initial scrape (non-fatal — install is already complete at this point)
echo ""
echo "Running initial data fetch..."
if node "$SCRIPT_DIR/scraper.mjs"; then
  echo ""
  echo "Installation complete!"
else
  echo ""
  echo "WARNING: Initial data fetch failed (network error, rate limit, or invalid token)."
  echo "Installation is complete — the statusline will retry automatically on next Claude Code interaction."
fi
echo "To manually refresh usage data: node $SCRIPT_DIR/scraper.mjs"
