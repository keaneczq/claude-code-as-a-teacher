#!/usr/bin/env bash
# new-topic.sh — create a new learning topic in the vault
#
# Usage: ./scripts/new-topic.sh <topic-slug> [topic title]
#   topic-slug:  kebab-case directory name, e.g. "feature-engineering"
#   topic title: optional human-readable title (defaults to slug)
#
# What it does:
#   1. Ensures vault root exists and has CLAUDE.md (deploys from template if missing)
#   2. Creates topic directory tree under vault
#   3. Instantiates _map.md and _index.md from templates with title substituted
#   4. Refuses to overwrite existing topic directory

set -euo pipefail

# --- config ---
VAULT_ROOT="${CC_CHAT_VAULT:-$HOME/Keane/cc-chat}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$PROJECT_ROOT/templates"

# --- args ---
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <topic-slug> [topic title]" >&2
  exit 1
fi

SLUG="$1"
TITLE="${2:-$1}"

if [[ ! "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Error: slug must be kebab-case (lowercase, digits, hyphens), got: $SLUG" >&2
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

# --- topic dir ---
TOPIC_DIR="$VAULT_ROOT/$SLUG"
if [[ -e "$TOPIC_DIR" ]]; then
  echo "Error: topic already exists: $TOPIC_DIR" >&2
  exit 1
fi

mkdir -p "$TOPIC_DIR"/{concepts,chapters,examples,refs,questions,transcripts}
touch "$TOPIC_DIR/questions/open.md"

# --- instantiate map & index ---
sed "s/{{TOPIC_TITLE}}/$TITLE/g" "$TEMPLATES/topic-_map.md"   > "$TOPIC_DIR/_map.md"
sed "s/{{TOPIC_TITLE}}/$TITLE/g" "$TEMPLATES/topic-_index.md" > "$TOPIC_DIR/_index.md"

# --- done ---
echo "Created topic: $TOPIC_DIR"
echo
echo "Next steps:"
echo "  1. Edit $TOPIC_DIR/_map.md — fill in 学习目标, 当前材料, 待开始"
echo "  2. Edit $TOPIC_DIR/_index.md — write today's focus"
echo "  3. cd $TOPIC_DIR && claude"
