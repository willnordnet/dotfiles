#!/bin/bash
# Log all user interactions with Claude Code to <project>/.claude/prompt-log.jsonl
#
# Hooks: UserPromptSubmit (user prompts), PostToolUse:AskUserQuestion (Q&A)
# Prompts over 1000 chars (e.g. expanded skills) are truncated to the first line.
# Output format: one JSON object per line with prompt/questions first for readability.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd')
LOG_DIR="$CWD/.claude"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')

if [ "$EVENT" = "PostToolUse" ]; then
  echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" '{questions: .tool_input.questions, answers: .tool_response, timestamp: $ts, type: "ask_user", session_id: .session_id, cwd: .cwd}' >> "$LOG_DIR/prompt-log.jsonl"
else
  MAX_LEN=1000
  PROMPT_LEN=$(echo "$INPUT" | jq -r '.prompt | length')
  if [ "$PROMPT_LEN" -gt "$MAX_LEN" ]; then
    FIRST_LINE=$(echo "$INPUT" | jq -r '.prompt' | head -1 | cut -c1-200)
    echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" --arg fl "$FIRST_LINE" --argjson len "$PROMPT_LEN" '{prompt: $fl, expanded_chars: $len, truncated: true, timestamp: $ts, type: "prompt", session_id: .session_id, cwd: .cwd}' >> "$LOG_DIR/prompt-log.jsonl"
  else
    echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" '{prompt: .prompt, timestamp: $ts, type: "prompt", session_id: .session_id, cwd: .cwd}' >> "$LOG_DIR/prompt-log.jsonl"
  fi
fi
