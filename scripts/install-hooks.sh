#!/usr/bin/env bash
# install-hooks.sh — idempotently inject SessionStart and SessionEnd hooks
# into ~/.claude/settings.json so that:
#
#   - SessionStart hooks call session-start-context.sh, which prints _index.md
#     handoff (and a recover-warning if last session looks unconsolidated).
#   - SessionEnd hooks call export-transcript.sh, which archives the JSONL +
#     a rendered MD into <topic>/transcripts/.
#
# Existing hooks (e.g. your Notification osascript) are preserved. Re-running
# this script overwrites only the cc-chat hook entries; it does not duplicate
# them.
#
# Requires: jq.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
SESSION_START_CMD="$SCRIPT_DIR/session-start-context.sh"
SESSION_END_CMD="$SCRIPT_DIR/export-transcript.sh"

# --- preflight ---
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required (brew install jq)" >&2; exit 1; }
[[ -x "$SESSION_START_CMD" ]] || { echo "Error: $SESSION_START_CMD not executable" >&2; exit 1; }
[[ -x "$SESSION_END_CMD"   ]] || { echo "Error: $SESSION_END_CMD not executable" >&2; exit 1; }

mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

# --- backup ---
BACKUP="$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS" "$BACKUP"
echo "Backup -> $BACKUP"

# --- transform ---
# We identify our hooks by command path (the absolute path to scripts/*).
# Re-running this script strips any existing entry with that command and
# re-adds a fresh one, so the operation is idempotent without needing a
# custom marker field that CC's schema might not accept.
TMP="$(mktemp)"
jq \
  --arg start_cmd "$SESSION_START_CMD" \
  --arg end_cmd   "$SESSION_END_CMD" \
  '
    # Strip any handler whose command equals our $cmd, then drop empty groups
    def strip_cmd($cmd):
      if type == "array" then
        map(.hooks |= (map(select((.command // "") != $cmd))))
        | map(select((.hooks | length) > 0))
      else . end;

    .hooks |= (. // {})
    | .hooks.SessionStart |= ((. // []) | strip_cmd($start_cmd))
    | .hooks.SessionEnd   |= ((. // []) | strip_cmd($end_cmd))
    | .hooks.SessionStart += [{
        "matcher": "startup|resume|clear",
        "hooks": [{
          "type": "command",
          "command": $start_cmd,
          "timeout": 5
        }]
      }]
    | .hooks.SessionEnd += [{
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": $end_cmd,
          "timeout": 10
        }]
      }]
  ' "$SETTINGS" > "$TMP"

mv "$TMP" "$SETTINGS"
echo "Installed cc-chat hooks into $SETTINGS"
echo
echo "Verify with: jq '.hooks' $SETTINGS"
