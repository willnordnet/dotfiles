#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_SRC="$DOTFILES_DIR/claude"
CLAUDE_DIR="$HOME/.claude"

FILES=(
  "CLAUDE.md"
  "settings.json"
  "statusline-command.sh"
  "skills/tough-review"
  "hooks/claude-island-state.py"
)

link_item() {
  local src="$CLAUDE_SRC/$1"
  local dest="$CLAUDE_DIR/$1"

  if [ -L "$dest" ]; then
    echo "  skip (already linked): $1"
    return
  fi

  if [ -e "$dest" ]; then
    echo "  backup: $dest -> $dest.bak"
    mv "$dest" "$dest.bak"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -sf "$src" "$dest"
  echo "  linked: $1"
}

echo "Linking Claude Code config..."
for item in "${FILES[@]}"; do
  link_item "$item"
done
echo "Done."
