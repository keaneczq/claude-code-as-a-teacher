#!/usr/bin/env bash
# new-topic.sh — create a new topic in the vault
#
# Usage: ./scripts/new-topic.sh [--mode learning|personal] <topic-slug> [topic title]
#   --mode:      mode to scaffold (default: learning)
#   topic-slug:  kebab-case directory name, e.g. "feature-engineering"
#   topic title: optional human-readable title (defaults to slug)
#
# What it does:
#   1. Ensures vault root exists and has CLAUDE.md (deploys from template if missing)
#   2. Creates topic directory tree under vault (mode-conditional layout)
#   3. Copies the per-mode CLAUDE.md to the topic root
#   4. Writes .cc-mode sentinel with the chosen mode name
#   5. Instantiates _map.md and _index.md from per-mode templates with title substituted
#   6. For personal mode: also instantiates _profile.md
#   7. Refuses to overwrite existing topic directory

set -euo pipefail

# --- config ---
VAULT_ROOT="${CC_CHAT_VAULT:-$HOME/Keane/cc-chat}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$PROJECT_ROOT/templates"

# --- parse --mode (must come before positional args) ---
MODE="learning"
if [[ "${1:-}" == "--mode" ]]; then
  if [[ $# -lt 2 ]]; then
    echo "--mode requires a value" >&2
    exit 1
  fi
  MODE="$2"
  shift 2
  case "$MODE" in
    learning|personal) ;;
    *) echo "Unknown mode: $MODE (must be learning or personal)" >&2; exit 1 ;;
  esac
fi

# --- args ---
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 [--mode learning|personal] <topic-slug> [topic title]" >&2
  exit 1
fi

SLUG="$1"
TITLE="${2:-$1}"

if [[ ! "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Error: slug must be kebab-case (lowercase, digits, hyphens), got: $SLUG" >&2
  exit 1
fi

# After --mode is consumed via shift, $1=slug and $2=title. Anything else is a mistake.
if [[ $# -gt 2 ]]; then
  echo "Error: unexpected extra argument: $3 (did you put --mode after the slug?)" >&2
  exit 1
fi

# --- per-mode templates dir ---
TEMPLATES_DIR="$TEMPLATES/modes/$MODE"
if [[ ! -d "$TEMPLATES_DIR" ]]; then
  echo "Error: mode templates dir missing: $TEMPLATES_DIR" >&2
  exit 1
fi

# --- ensure vault root ---
if [[ ! -d "$VAULT_ROOT" ]]; then
  echo "Error: vault root does not exist: $VAULT_ROOT" >&2
  echo "Set CC_CHAT_VAULT env var or create the directory first." >&2
  exit 1
fi

# --- deploy vault-level CLAUDE.md if missing ---
VAULT_CLAUDE="$VAULT_ROOT/CLAUDE.md"
if [[ ! -f "$VAULT_CLAUDE" ]]; then
  cp "$TEMPLATES/vault-CLAUDE.md" "$VAULT_CLAUDE"
  echo "Deployed: $VAULT_CLAUDE"
fi

# --- deploy vault-level .gitignore if missing ---
# Ignores _live.md (the Stop-hook scratch reading surface). Subtree-scoped so it
# matches every topic's _live.md without touching the wider Obsidian vault.
VAULT_GITIGNORE="$VAULT_ROOT/.gitignore"
if [[ ! -f "$VAULT_GITIGNORE" ]]; then
  cp "$TEMPLATES/vault-gitignore" "$VAULT_GITIGNORE"
  echo "Deployed: $VAULT_GITIGNORE"
fi

# --- topic dir ---
TOPIC_DIR="$VAULT_ROOT/$SLUG"
if [[ -e "$TOPIC_DIR" ]]; then
  echo "Error: topic already exists: $TOPIC_DIR" >&2
  exit 1
fi

mkdir -p "$TOPIC_DIR"

# --- copy mode-level CLAUDE.md and write sentinel ---
cp "$TEMPLATES_DIR/CLAUDE.md" "$TOPIC_DIR/CLAUDE.md"
echo "$MODE" > "$TOPIC_DIR/.cc-mode"

# --- mode-conditional layout ---
if [[ "$MODE" == "learning" ]]; then
  mkdir -p "$TOPIC_DIR"/{concepts,chapters,examples,refs,questions,transcripts}
  touch "$TOPIC_DIR/questions/open.md"
elif [[ "$MODE" == "personal" ]]; then
  mkdir -p "$TOPIC_DIR"/{positions,transcripts}
  sed "s/{{TOPIC_TITLE}}/$TITLE/g" "$TEMPLATES_DIR/topic-_profile.md" > "$TOPIC_DIR/_profile.md"
fi

# --- instantiate map & index from per-mode templates ---
sed "s/{{TOPIC_TITLE}}/$TITLE/g" "$TEMPLATES_DIR/topic-_map.md"   > "$TOPIC_DIR/_map.md"
sed "s/{{TOPIC_TITLE}}/$TITLE/g" "$TEMPLATES_DIR/topic-_index.md" > "$TOPIC_DIR/_index.md"

# --- done ---
echo "Created topic: $TOPIC_DIR (mode: $MODE)"
echo
echo "Next steps:"
if [[ "$MODE" == "learning" ]]; then
  echo "  1. Edit $TOPIC_DIR/_map.md — fill in 学习目标, 当前材料, 待开始"
  echo "  2. Edit $TOPIC_DIR/_index.md — write today's focus"
  echo "  3. cd $TOPIC_DIR && claude"
else
  echo "  1. Edit $TOPIC_DIR/_profile.md — fill in your profile"
  echo "  2. Edit $TOPIC_DIR/_map.md — outline scope and stance"
  echo "  3. Edit $TOPIC_DIR/_index.md — write today's focus"
  echo "  4. cd $TOPIC_DIR && claude"
fi
