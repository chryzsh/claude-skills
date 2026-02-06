#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
SETTINGS_DST="$HOME/.claude/settings.json"

# Skills to install (directories containing a SKILL.md)
SKILLS=()
for dir in "$REPO_DIR"/*/; do
  [[ -f "$dir/SKILL.md" ]] && SKILLS+=("$dir")
done

if [[ ${#SKILLS[@]} -eq 0 ]]; then
  echo "No skills found."
  exit 1
fi

mkdir -p "$SKILLS_DIR"

echo "Installing ${#SKILLS[@]} skill(s) to $SKILLS_DIR"
for dir in "${SKILLS[@]}"; do
  name="$(basename "$dir")"
  echo "  -> $name"
  cp -R "$dir" "$SKILLS_DIR/$name"
done

# Install settings.json (with backup)
if [[ -f "$REPO_DIR/settings.json" ]]; then
  if [[ -f "$SETTINGS_DST" ]]; then
    cp "$SETTINGS_DST" "$SETTINGS_DST.bak"
    echo "Backed up existing settings to $SETTINGS_DST.bak"
  fi
  cp "$REPO_DIR/settings.json" "$SETTINGS_DST"
  echo "Installed settings.json to $SETTINGS_DST"
fi

echo "Done. Restart Claude Code to pick up changes."
