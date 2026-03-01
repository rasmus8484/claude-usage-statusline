# PRD: Claude Session Limit Scraper

## Overview

A lightweight tool that fetches Claude usage/session limit data from Anthropic's API and displays it in Claude Code's terminal status bar (statusline).

## Problem

Claude Pro/Max users have no easy way to see their current session usage (5-hour window) and weekly usage (7-day window) while working in Claude Code. The only way to check is to visit `claude.ai/settings/usage` in a browser or run `/usage` inside Claude Code, interrupting workflow.

## Solution

A two-part system:
1. **Scraper**: A Node.js script that calls Anthropic's usage API endpoint, retrieves utilization data, and caches it to a local JSON file.
2. **Statusline script**: A bash script that reads the cached usage data and formats it for display in Claude Code's status bar alongside the existing context window information.

## Data Source

### Primary: Anthropic OAuth Usage API
- **Endpoint**: `GET https://api.anthropic.com/api/oauth/usage`
- **Auth**: Bearer token using Claude Code's OAuth credential (`sk-ant-oat01-*`)
- **Response format**:
  ```json
  {
    "five_hour": {
      "utilization": 6.0,
      "resets_at": "2025-11-04T04:59:59+00:00"
    },
    "seven_day": {
      "utilization": 35.0,
      "resets_at": "2025-11-06T03:59:59+00:00"
    },
    "seven_day_opus": {
      "utilization": 0.0,
      "resets_at": null
    }
  }
  ```

### Credential Retrieval (Windows)
Claude Code stores its OAuth token in the Windows Credential Manager. The scraper will extract it using PowerShell's `CredRead` API or Node.js native addon.

**Note**: If OAuth tokens are restricted for third-party use (as reported Feb 2026), the tool will detect this and provide clear error messaging. The architecture supports swapping in alternative data sources (browser automation, manual token input) without changing the statusline integration.

## Architecture

```
┌─────────────────┐       ┌──────────────┐       ┌─────────────────────┐
│  scraper.mjs    │──────▶│  usage.json  │◀──────│  statusline.sh      │
│  (Node.js)      │ write │  (~/.claude/) │ read  │  (bash, called by   │
│  - fetch API    │       │              │       │   Claude Code)      │
│  - cache result │       └──────────────┘       │  - format & display │
└─────────────────┘                              └─────────────────────┘
        │                                                │
        ▼                                                ▼
  Anthropic API                                   Claude Code UI
  /api/oauth/usage                                (status bar)
```

## Statusline Display Format

The status bar will show (single line):
```
ctx [████████░░░░░░░░░░░░] 40%  ⏱ 5h:23% 7d:35%
```

- `ctx [bar] %` — existing context window usage (from Claude Code's stdin JSON)
- `5h:23%` — 5-hour session utilization
- `7d:35%` — 7-day weekly utilization

When data is stale (>10 minutes old) or unavailable, show `5h:?? 7d:??`.

## Scraper Behavior

- **Invocation**: Run manually via `node scraper.mjs`, or scheduled via the statusline script on a cooldown.
- **Caching**: Writes to `~/.claude/usage.json` with a timestamp. The statusline script checks freshness.
- **Cooldown**: The statusline script triggers a background refresh if data is older than 5 minutes.
- **Error handling**: On API failure, keeps existing cached data and logs errors to stderr.

## Non-Goals

- No daemon/service — this runs on-demand triggered by the statusline
- No GUI — terminal status bar only
- No historical tracking — only current utilization snapshot
- No support for API-key-based console usage (this is for claude.ai subscriber limits)

## Technical Stack

- **Runtime**: Node.js (v24 available on system)
- **Scraper**: Native `fetch()` (no external dependencies)
- **Statusline**: Bash script with `sed` parsing (no `jq` dependency, matching existing setup)
- **Credential access**: PowerShell interop for Windows Credential Manager

## File Layout

```
claude-session-limit-scraper/
├── CLAUDE.md
├── PRD.md
├── README.md
├── scraper.mjs          # Main scraper script
├── get-credential.ps1   # PowerShell helper to extract OAuth token
├── install.sh           # Sets up statusline in ~/.claude/
└── statusline.sh        # Combined statusline (context + usage)
```
