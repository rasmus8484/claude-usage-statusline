# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Fetches Claude 5-hour session usage from Anthropic's OAuth API and displays it as a progress bar in Claude Code's terminal status bar, with a countdown to the next reset.

## Architecture

- **scraper.mjs** — Node.js script (no dependencies). Reads OAuth token from `~/.claude/.credentials.json`, calls `GET https://api.anthropic.com/api/oauth/usage`, writes result to `~/.claude/usage.json`.
- **statusline.sh** — Bash script invoked by Claude Code on each interaction. Reads `~/.claude/usage.json` (cached usage data) and displays a progress bar with the percentage centered inside and a time-until-reset label. Triggers background scraper refresh when data is >10s stale.
- **install.sh** — Updates `~/.claude/settings.json` to point at `statusline.sh`.

## Key Paths

- Credentials: `~/.claude/.credentials.json` (field: `claudeAiOauth.accessToken`)
- Cached usage: `~/.claude/usage.json`
- Settings: `~/.claude/settings.json` (field: `statusLine.command`)

## Commands

```bash
node scraper.mjs       # Fetch and cache usage data
bash install.sh        # Install statusline into Claude Code settings
bash statusline.sh     # Test statusline (pipe Claude Code JSON to stdin)
```

## Status Bar Design

A single progress bar with the percentage centered inside, prefixed by a countdown to reset:

```
3h10m ████████ 52% ████░░░░░░░░
```

- **3h10m** — time until the 5-hour session resets (dimmed label)
- Filled `█` segments are colored: green (<50%), yellow (50-79%), red (80%+)
- Empty `░` segments are dark gray
- Percentage is bold white, centered in the bar

## API Details

- Endpoint: `GET https://api.anthropic.com/api/oauth/usage`
- Auth header: `Authorization: Bearer <oauth-token>`
- Required header: `anthropic-beta: oauth-2025-04-20`
- Returns JSON with `five_hour.utilization` (0-100 percentage) and `five_hour.resets_at` (ISO timestamp).
