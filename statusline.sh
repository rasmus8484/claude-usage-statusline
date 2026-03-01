#!/usr/bin/env bash
# Claude Code status line — session usage limits
# Pure sed parsing (no jq, no grep -P)
# Reads usage.json from ~/.claude/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USAGE_FILE="$HOME/.claude/usage.json"
SCRAPER="$SCRIPT_DIR/scraper.mjs"
LOCK_FILE="$HOME/.claude/.scraper.lock"
STALE_SECONDS=10  # 10 seconds

cat > /dev/null  # consume stdin

# --- ANSI colors ---
RST='\033[0m'
DIM='\033[2m'
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

# --- Bar width ---
# Fixed width that fits most terminals (two bars + labels + separator)
bar_width=20

# Build a bar with the percentage centered inside it
make_bar() {
  local pct=$1 width=$2
  local filled=$(( pct * width / 100 ))
  [ "$filled" -gt "$width" ] && filled=$width
  local color
  color=$(color_for_pct "$pct")

  local label
  if [ "$pct" = "??" ]; then
    label=" ?? "
  else
    label=$(printf " %d%% " "$pct")
  fi
  local label_len=${#label}
  local label_start=$(( (width - label_len) / 2 ))
  local label_end=$(( label_start + label_len ))

  if [ "$label_len" -ge "$width" ]; then
    label_start=0
    label_end=$width
    label="${label:0:$width}"
  fi

  local bar=""
  local i=0

  while [ "$i" -lt "$label_start" ]; do
    if [ "$i" -lt "$filled" ]; then
      bar="${bar}${color}█"
    else
      bar="${bar}${GRAY}░"
    fi
    i=$((i + 1))
  done

  bar="${bar}${BOLD_WHITE}${label}${RST}"
  i=$label_end

  while [ "$i" -lt "$width" ]; do
    if [ "$i" -lt "$filled" ]; then
      bar="${bar}${color}█"
    else
      bar="${bar}${GRAY}░"
    fi
    i=$((i + 1))
  done

  bar="${bar}${RST}"
  printf "%b" "$bar"
}

# --- Usage data (from cached usage.json) ---
h5="??"
reset_label="??"

if [ -f "$USAGE_FILE" ]; then
  if command -v stat >/dev/null 2>&1; then
    file_epoch=$(stat -c %Y "$USAGE_FILE" 2>/dev/null || date -r "$USAGE_FILE" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    age=$(( now_epoch - file_epoch ))
  else
    age=9999
  fi

  usage_data=$(cat "$USAGE_FILE")
  raw_h5=$(echo "$usage_data" | sed -n 's/.*"five_hour".*"utilization":\s*\([0-9.]*\).*/\1/p' | head -1)
  raw_d7=$(echo "$usage_data" | sed -n 's/.*"seven_day".*"utilization":\s*\([0-9.]*\).*/\1/p' | head -1)

  if [ -z "$raw_h5" ]; then
    raw_h5=$(echo "$usage_data" | sed -n '/"five_hour"/,/}/{ s/.*"utilization":\s*\([0-9.]*\).*/\1/p; }' | head -1)
  fi
  if [ -z "$raw_d7" ]; then
    raw_d7=$(echo "$usage_data" | sed -n '/"seven_day"/,/}/{ s/.*"utilization":\s*\([0-9.]*\).*/\1/p; }' | head -1)
  fi

  [ -n "$raw_h5" ] && h5="${raw_h5%%.*}"

  # Parse resets_at timestamp to calculate time remaining
  raw_reset=$(echo "$usage_data" | sed -n '/"five_hour"/,/}/{ s/.*"resets_at":\s*"\([^"]*\)".*/\1/p; }' | head -1)
  if [ -n "$raw_reset" ]; then
    reset_epoch=$(date -d "$raw_reset" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$(echo "$raw_reset" | sed 's/\.[0-9]*+.*//')" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    remaining=$(( reset_epoch - now_epoch ))
    if [ "$remaining" -le 0 ]; then
      reset_label="0m"
    else
      reset_h=$(( remaining / 3600 ))
      reset_m=$(( (remaining % 3600) / 60 ))
      if [ "$reset_h" -gt 0 ]; then
        reset_label="${reset_h}h${reset_m}m"
      else
        reset_label="${reset_m}m"
      fi
    fi
  else
    reset_label="??"
  fi

  if [ "$age" -gt "$STALE_SECONDS" ] && [ ! -f "$LOCK_FILE" ]; then
    (
      touch "$LOCK_FILE"
      node "$SCRAPER" >/dev/null 2>&1
      rm -f "$LOCK_FILE"
    ) &
  fi
else
  if [ ! -f "$LOCK_FILE" ] && [ -f "$SCRAPER" ]; then
    (
      touch "$LOCK_FILE"
      node "$SCRAPER" >/dev/null 2>&1
      rm -f "$LOCK_FILE"
    ) &
  fi
fi

# --- Build bar ---
h5_bar=$(make_bar "$h5" "$bar_width")

# --- Output ---
printf "%b%s%b %b" "$DIM" "$reset_label" "$RST" "$h5_bar"
