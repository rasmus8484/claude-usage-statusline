# Claude Usage Statusline

Shows your Claude 5-hour session usage as a progress bar in Claude Code's status bar, with a countdown to the next reset.

```
3h10m ████████ 52% ████░░░░░░░░
```

## How it works

1. **scraper.mjs** — Reads your OAuth token from `~/.claude/.credentials.json`, calls Anthropic's usage API, and caches the result to `~/.claude/usage.json`.
2. **statusline.sh** — Displays the session usage as a color-coded progress bar with percentage centered inside and a time-until-reset label. Auto-refreshes in the background every 10 seconds.

## Install

```bash
bash install.sh
```

This will:
- Back up your existing statusline script
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

## Uninstall

Restore your original statusline:
```bash
cp ~/.claude/statusline-command.sh.bak ~/.claude/statusline-command.sh
```
Then update `~/.claude/settings.json` to point back to `bash ~/.claude/statusline-command.sh`.
