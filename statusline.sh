#!/usr/bin/env bash
# Claude Code status line — context window + session usage limits
# Pure sed parsing (no jq, no grep -P)
# Reads Claude Code JSON from stdin, reads usage.json from ~/.claude/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USAGE_FILE="$HOME/.claude/usage.json"
SCRAPER="$SCRIPT_DIR/scraper.mjs"
LOCK_FILE="$HOME/.claude/.scraper.lock"
STALE_SECONDS=10  # 10 seconds

input=$(cat)

# --- ANSI colors ---
RST='\033[0m'
DIM='\033[2m'
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
GRAY='\033[90m'
BOLD_WHITE='\033[1;37m'

color_for_pct() {
  local pct=$1
  if [ "$pct" = "??" ]; then printf "%b" "$GRAY"
  elif [ "$pct" -ge 80 ] 2>/dev/null; then printf "%b" "$RED"
  elif [ "$pct" -ge 50 ] 2>/dev/null; then printf "%b" "$YELLOW"
  else printf "%b" "$GREEN"
  fi
}

# --- Terminal width ---
# COLS is passed by the wrapper command in settings.json (captured before pipe)
term_width=${COLS:-80}
# Fixed visible chars: "ctx " + "  ·  " + "5h " + "  ·  " + "7d " + stale buffer
#                        4        5        3        5        3        2     = 22
fixed=22
available=$(( term_width - fixed ))
[ "$available" -lt 12 ] && available=12
bar_width=$(( available / 3 ))

# --- Context window (from Claude Code stdin) ---
ctx_pct=$(echo "$input" | sed -n 's/.*"used_percentage":\([0-9]*\).*/\1/p')
: "${ctx_pct:=0}"

# Build a bar with the percentage centered inside it
make_bar() {
  local pct=$1 width=$2
  local filled=$(( pct * width / 100 ))
  [ "$filled" -gt "$width" ] && filled=$width
  local color
  color=$(color_for_pct "$pct")

  # Format the centered label
  local label
  if [ "$pct" = "??" ]; then
    label=" ?? "
  else
    label=$(printf " %d%% " "$pct")
  fi
  local label_len=${#label}
  local label_start=$(( (width - label_len) / 2 ))
  local label_end=$(( label_start + label_len ))

  # Clamp if bar is too narrow for the label
  if [ "$label_len" -ge "$width" ]; then
    label_start=0
    label_end=$width
    label="${label:0:$width}"
  fi

  local bar=""
  local i=0

  # Before label
  while [ "$i" -lt "$label_start" ]; do
    if [ "$i" -lt "$filled" ]; then
      bar="${bar}${color}▰"
    else
      bar="${bar}${GRAY}▱"
    fi
    i=$((i + 1))
  done

  # Label in bold white
  bar="${bar}${BOLD_WHITE}${label}${RST}"
  i=$label_end

  # After label
  while [ "$i" -lt "$width" ]; do
    if [ "$i" -lt "$filled" ]; then
      bar="${bar}${color}▰"
    else
      bar="${bar}${GRAY}▱"
    fi
    i=$((i + 1))
  done

  bar="${bar}${RST}"
  printf "%b" "$bar"
}

# --- Usage data (from cached usage.json) ---
h5="??"
d7="??"

if [ -f "$USAGE_FILE" ]; then
  # Check staleness
  if command -v stat >/dev/null 2>&1; then
    file_epoch=$(stat -c %Y "$USAGE_FILE" 2>/dev/null || date -r "$USAGE_FILE" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    age=$(( now_epoch - file_epoch ))
  else
    age=9999
  fi

  # Parse usage data with sed
  usage_data=$(cat "$USAGE_FILE")
  raw_h5=$(echo "$usage_data" | sed -n 's/.*"five_hour".*"utilization":\s*\([0-9.]*\).*/\1/p' | head -1)
  raw_d7=$(echo "$usage_data" | sed -n 's/.*"seven_day".*"utilization":\s*\([0-9.]*\).*/\1/p' | head -1)

  # If multiline JSON, try line-by-line after five_hour block
  if [ -z "$raw_h5" ]; then
    raw_h5=$(echo "$usage_data" | sed -n '/"five_hour"/,/}/{ s/.*"utilization":\s*\([0-9.]*\).*/\1/p; }' | head -1)
  fi
  if [ -z "$raw_d7" ]; then
    raw_d7=$(echo "$usage_data" | sed -n '/"seven_day"/,/}/{ s/.*"utilization":\s*\([0-9.]*\).*/\1/p; }' | head -1)
  fi

  # Strip decimal part
  [ -n "$raw_h5" ] && h5="${raw_h5%%.*}"
  [ -n "$raw_d7" ] && d7="${raw_d7%%.*}"

  # Show stale marker only when data is actually old (>30s)
  stale=""
  if [ "$age" -gt 30 ]; then
    stale="$(printf " %b!%b" "$RED" "$RST")"
  fi

  # Trigger background refresh if stale and not already running
  if [ "$age" -gt "$STALE_SECONDS" ] && [ ! -f "$LOCK_FILE" ]; then
    (
      touch "$LOCK_FILE"
      node "$SCRAPER" >/dev/null 2>&1
      rm -f "$LOCK_FILE"
    ) &
  fi
else
  stale="$(printf " %b!%b" "$RED" "$RST")"
  # No cached data yet — trigger initial fetch
  if [ ! -f "$LOCK_FILE" ] && [ -f "$SCRAPER" ]; then
    (
      touch "$LOCK_FILE"
      node "$SCRAPER" >/dev/null 2>&1
      rm -f "$LOCK_FILE"
    ) &
  fi
fi

# --- Build bars ---
ctx_bar=$(make_bar "$ctx_pct" "$bar_width")
h5_bar=$(make_bar "$h5" "$bar_width")
d7_bar=$(make_bar "$d7" "$bar_width")

sep=$(printf "%b  ·  %b" "$GRAY" "$RST")

# --- Output ---
printf "%bctx%b %b%s%b5h%b %b%s%b7d%b %b%b" \
  "$DIM" "$RST" "$ctx_bar" "$sep" \
  "$DIM" "$RST" "$h5_bar" "$sep" \
  "$DIM" "$RST" "$d7_bar" "$stale"
