#!/usr/bin/env bash
# rerender-transcripts.sh — re-render every archived transcript .md from its
# .jsonl source.
#
# Why this exists: obsidian-linter (lintOnSave / lintOnFileChange) rewrote the
# rendered .md files in place — inserting CJK spaces and, worse, rotating
# **bold** spans so content got scrambled. The .jsonl sources were never
# touched (the linter doesn't format .jsonl), so they are the ground truth.
# This script regenerates the .md files from those sources, undoing the damage.
#
# PRECONDITION: the linter must already be ignoring <topic>/transcripts/
# (filesToIgnore entry "cc-chat/.*/transcripts/") AND that ignore must be live
# (reload the plugin / restart Obsidian). Otherwise the freshly rendered .md
# gets re-corrupted on the next lint, and Obsidian-Git may auto-commit the bad
# version. Verify the ignore is active before running this.
#
# Safe to re-run: rendering is deterministic and overwrites only the .md.
# The .jsonl files are read-only here.
#
# Usage:
#   ./scripts/rerender-transcripts.sh           # all topics under the vault
#   ./scripts/rerender-transcripts.sh <topic>   # one topic dir (name or path)
#   DRY_RUN=1 ./scripts/rerender-transcripts.sh  # list what would change, no writes

set -uo pipefail

VAULT_ROOT="${CC_CHAT_VAULT:-$HOME/Keane/cc-chat}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER="$SCRIPT_DIR/render-transcript.py"
DRY_RUN="${DRY_RUN:-0}"

[[ -f "$RENDERER" ]] || { echo "Error: renderer not found: $RENDERER" >&2; exit 1; }
[[ -d "$VAULT_ROOT" ]] || { echo "Error: vault not found: $VAULT_ROOT" >&2; exit 1; }

# Resolve which transcripts/ dirs to process.
declare -a TX_DIRS=()
if [[ $# -ge 1 ]]; then
  # Accept either a bare topic name or a full path.
  arg="$1"
  if [[ -d "$arg/transcripts" ]]; then
    TX_DIRS+=("$arg/transcripts")
  elif [[ -d "$VAULT_ROOT/$arg/transcripts" ]]; then
    TX_DIRS+=("$VAULT_ROOT/$arg/transcripts")
  else
    echo "Error: no transcripts/ dir for: $arg" >&2; exit 1
  fi
else
  # All topic transcripts dirs under the vault.
  while IFS= read -r d; do
    TX_DIRS+=("$d")
  done < <(find "$VAULT_ROOT" -mindepth 2 -maxdepth 2 -type d -name transcripts | sort)
fi

[[ ${#TX_DIRS[@]} -gt 0 ]] || { echo "No transcripts/ directories found under $VAULT_ROOT"; exit 0; }

total=0; ok=0; fail=0; skip=0
for tx in "${TX_DIRS[@]}"; do
  shopt -s nullglob
  for jsonl in "$tx"/*.jsonl; do
    md="${jsonl%.jsonl}.md"
    total=$((total+1))
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "[dry-run] would render: $jsonl -> $(basename "$md")"
      skip=$((skip+1))
      continue
    fi
    if python3 "$RENDERER" "$jsonl" "$md" 2>/dev/null; then
      ok=$((ok+1))
      echo "rendered: ${jsonl#$VAULT_ROOT/} -> $(basename "$md")"
    else
      fail=$((fail+1))
      echo "FAILED:   ${jsonl#$VAULT_ROOT/}" >&2
    fi
  done
  shopt -u nullglob
done

echo
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] $skip transcript(s) across ${#TX_DIRS[@]} dir(s) would be re-rendered."
else
  echo "Done. $ok rendered, $fail failed, out of $total across ${#TX_DIRS[@]} dir(s)."
fi
