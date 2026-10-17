#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

git -C "$REPO_DIR" submodule update --init --recursive

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
  rm -rf "$SKILLS_DIR/$name"
  cp -R "$dir" "$SKILLS_DIR/$name"
done

# Install agent definitions (if any)
if [[ -d "$REPO_DIR/agents" ]]; then
  mkdir -p "$HOME/.claude/agents"
  for f in "$REPO_DIR"/agents/*.md; do
    [[ -f "$f" ]] || continue
    cp "$f" "$HOME/.claude/agents/$(basename "$f")"
    echo "  -> agent $(basename "$f")"
  done
  echo "Installed agent(s) to $HOME/.claude/agents"
fi

# This script never writes ~/.claude/settings.json or ~/.claude/CLAUDE.md.
# Those are personal config, kept and linked from a private dotfiles repo.

echo "Done. Restart Claude Code to pick up changes."
