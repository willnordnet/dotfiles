#!/bin/bash

# Read stdin JSON
input=$(cat)

# Extract current directory from JSON
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')

# Get current directory (basename)
dir=$(basename "$current_dir")

# Get git branch if in a git repo
git_info=""
if git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$current_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check for changes (skip optional locks)
        if ! git -C "$current_dir" --no-optional-locks diff --quiet 2>/dev/null || ! git -C "$current_dir" --no-optional-locks diff --cached --quiet 2>/dev/null; then
            dirty="*"
        else
            dirty=""
        fi
        git_info=$(printf " \033[35m(%s%s)\033[0m" "$branch" "$dirty")
    fi
fi

# Dimmed pipe separator
sep=$(printf " \033[2m|\033[0m ")

# Model name (yellow) — strip "Claude " prefix for brevity
model=$(echo "$input" | jq -r '.model.display_name // .display_name // empty' | sed 's/^Claude //')

# Context remaining % (cyan)
ctx_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Build the prompt: dir (branch*) | Model | 95% ctx
line=$(printf "\033[34m%s\033[0m%s" "$dir" "$git_info")

if [ -n "$model" ]; then
    line="${line}${sep}$(printf "\033[33m%s\033[0m" "$model")"
fi

if [ -n "$ctx_pct" ]; then
    line="${line}${sep}$(printf "\033[36m%s%% ctx\033[0m" "$ctx_pct")"
fi

printf "%s" "$line"
