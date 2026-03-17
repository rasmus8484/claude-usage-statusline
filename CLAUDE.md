# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Fetches Claude 5-hour session usage from Anthropic's OAuth API and displays it as a progress bar in Claude Code's terminal status bar, with a countdown to the next reset.

## Architecture

- **scraper.mjs** — Node.js script (no dependencies). Reads OAuth token from `~/.claude/.credentials.json`, makes a minimal Messages API call (`claude-haiku-4-5-20251001`, 1 max token) and extracts rate limit data from response headers. Writes result to `~/.claude/usage.json`.
- **statusline.sh** — Bash script invoked by Claude Code on each interaction. Reads `~/.claude/usage.json` (cached usage data) and displays a progress bar with the percentage centered inside and a time-until-reset label. Triggers background scraper refresh when data is >30s stale. Auto-expires orphaned lock files after 60s.
- **install.sh** — Checks prerequisites (Node.js), preserves existing statusline via a wrapper if present, updates `~/.claude/settings.json`, and runs an initial data fetch.

## Key Paths

- Credentials: `~/.claude/.credentials.json` (field: `claudeAiOauth.accessToken`)
- Cached usage: `~/.claude/usage.json`
- Lock file: `~/.claude/.scraper.lock` (prevents concurrent scraper runs; auto-expires after 60s)
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

The scraper uses the Messages API to extract rate limit data from response headers, avoiding the `/api/oauth/usage` endpoint which suffers from persistent 429 rate limiting.

- Endpoint: `POST https://api.anthropic.com/v1/messages`
- Model: `claude-haiku-4-5-20251001` (cheapest, ~$0.001 per probe)
- Payload: `{ max_tokens: 1, messages: [{ role: "user", content: "hi" }] }`
- Auth header: `Authorization: Bearer <oauth-token>`
- Required headers: `anthropic-version: 2023-06-01`, `anthropic-beta: oauth-2025-04-20`
- Rate limit headers returned:
  - `anthropic-ratelimit-unified-5h-utilization` (0-1 ratio, converted to 0-100)
  - `anthropic-ratelimit-unified-5h-reset` (Unix epoch seconds)
  - `anthropic-ratelimit-unified-7d-utilization` (0-1 ratio, converted to 0-100)
  - `anthropic-ratelimit-unified-7d-reset` (Unix epoch seconds)
