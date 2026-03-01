# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Fetches Claude usage limits (5-hour session, 7-day weekly) from Anthropic's OAuth API and displays them in Claude Code's terminal status bar alongside context window usage.

## Architecture

- **scraper.mjs** — Node.js script (no dependencies). Reads OAuth token from `~/.claude/.credentials.json`, calls `GET https://api.anthropic.com/api/oauth/usage`, writes result to `~/.claude/usage.json`.
- **statusline.sh** — Bash script invoked by Claude Code on each interaction. Reads Claude Code's JSON from stdin (context window data) and `~/.claude/usage.json` (cached usage data). Triggers background scraper refresh when data is >10s stale. Shows a red `!` when data is >30s old.
- **install.sh** — Updates `~/.claude/settings.json` with a wrapper command that captures terminal width before piping, then points at `statusline.sh`.

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

Three progress bars with percentages centered inside, dynamically scaled to terminal width:

```
ctx ▰▰▰▰▰▰▰ 42% ▱▱▱▱▱▱▱  ·  5h ▰▰▰▰▰▰▰ 68% ▰▰▱▱▱▱▱  ·  7d ▰▰▰▰▰▰▰ 45% ▱▱▱▱▱▱▱
```

- **ctx** — context window usage (from Claude Code stdin JSON)
- **5h** — 5-hour session utilization
- **7d** — 7-day weekly utilization
- Filled `▰` segments are colored: green (<50%), yellow (50-79%), red (80%+)
- Empty `▱` segments are dark gray
- Labels are dimmed, separators (`·`) are gray
- A red `!` appears at the end when data is >30s old

## API Details

- Endpoint: `GET https://api.anthropic.com/api/oauth/usage`
- Auth header: `Authorization: Bearer <oauth-token>`
- Required header: `anthropic-beta: oauth-2025-04-20`
- Returns JSON with `five_hour.utilization`, `seven_day.utilization` (0-100 percentages), and `resets_at` timestamps.
