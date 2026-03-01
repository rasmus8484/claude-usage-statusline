# Claude Session Limit Scraper

Shows your Claude usage limits (5-hour session, 7-day weekly) directly in Claude Code's status bar.

## How it works

1. **scraper.mjs** — Reads your OAuth token from `~/.claude/.credentials.json`, calls Anthropic's usage API, and caches the result to `~/.claude/usage.json`.
2. **statusline.sh** — Replaces Claude Code's default status bar script. Displays context window usage (from Claude Code) plus session/weekly utilization (from the cached usage data). Auto-refreshes in the background every 5 minutes.

## Install

```bash
bash install.sh
```

This will:
- Back up your existing statusline script
- Point Claude Code's settings to the new statusline
- Run an initial data fetch

Restart Claude Code (or start a new session) for the status bar to appear.

## Manual refresh

```bash
node scraper.mjs
```

## Status bar format

```
ctx [████████░░░░░░░░░░░░]  42%  5h:44% 7d:35%
```

- **ctx bar** — context window usage (how full your conversation is)
- **5h** — 5-hour session utilization (green <50%, yellow 50-79%, red 80%+)
- **7d** — 7-day weekly utilization

When data is stale (>5 min) or missing, values show as `??` and a background refresh is triggered.

## Uninstall

Restore your original statusline:
```bash
cp ~/.claude/statusline-command.sh.bak ~/.claude/statusline-command.sh
```
Then update `~/.claude/settings.json` to point back to `bash ~/.claude/statusline-command.sh`.
