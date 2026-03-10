# Claude Usage Statusline

Shows your Claude 5-hour session usage as a progress bar in Claude Code's status bar, with a countdown to the next reset.

```
3h10m ████████ 52% ████░░░░░░░░
```

## How it works

1. **scraper.mjs** — Reads your OAuth token from `~/.claude/.credentials.json`, calls Anthropic's usage API, and caches the result to `~/.claude/usage.json`.
2. **statusline.sh** — Displays the session usage as a color-coded progress bar with percentage centered inside and a time-until-reset label. Auto-refreshes in the background every 30 seconds.

## Prerequisites

- **Node.js** (v18+ with native `fetch`)
- **Bash** (Linux/macOS built-in, Windows via Git Bash)
- **Claude Code** installed and logged in (needs `~/.claude/.credentials.json`)

## Install

One-liner:
```bash
curl -fsSL https://raw.githubusercontent.com/rasmus8484/claude-usage-statusline/main/install-remote.sh | bash
```

Or manually:
```bash
git clone https://github.com/rasmus8484/claude-usage-statusline.git
cd claude-usage-statusline
bash install.sh
```

This will:
- Check that Node.js is available
- Preserve your existing statusline (if any) by creating a wrapper that combines both
- Point Claude Code's settings to the new statusline
- Run an initial data fetch

Restart Claude Code for the status bar to appear.

## Manual refresh

```bash
node scraper.mjs
```

## Color coding

- **Green** — usage below 50%
- **Yellow** — usage between 50-79%
- **Red** — usage at 80% or above

## Note

This tool uses an undocumented Anthropic API endpoint (`/api/oauth/usage`) that is not part of the public API. It may break or be blocked at any time without notice.

## Uninstall

Remove the `statusLine` entry from `~/.claude/settings.json`, or replace it with your own command.
