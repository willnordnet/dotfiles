#!/bin/bash
# Read JSON data that Claude Code sends to stdin
input=$(cat)

# Extract fields using jq
MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

COST_FMT=$(printf '$%.2f' "$COST")
DURATION_SEC=$((DURATION_MS / 1000))
MINS=$((DURATION_SEC / 60))
SECS=$((DURATION_SEC % 60))

LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
SESSION_ID=$(echo "$input" | jq -r '.session_id')
TURNS=$(grep -c "\"sessionId\":\"$SESSION_ID\"" ~/.claude/history.jsonl 2>/dev/null || echo 0)

BRANCH=""
DIRTY=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH="🌿  $(git --no-optional-locks branch --show-current 2>/dev/null)"
  [ -n "$(git --no-optional-locks status --porcelain 2>/dev/null)" ] && DIRTY=" ✏️"
fi

# Output the status line - ${DIR##*/} extracts just the folder name
printf '%s\n' "🤖  [$MODEL] | 📁  ${DIR##*/} | ${BRANCH}${DIRTY}"
printf '%s\n' "🧠  ${PCT}% context | 💰  $COST_FMT | ⏱  ${MINS}m ${SECS}s | 📝  +${LINES_ADDED}/-${LINES_REMOVED} | 💬  ${TURNS} turns"
