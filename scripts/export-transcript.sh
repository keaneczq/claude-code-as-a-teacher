#!/usr/bin/env bash
# export-transcript.sh — invoked by the SessionEnd hook. Reads CC's hook JSON
# from stdin, then archives the transcript into <topic>/transcripts/ as both
# .jsonl (lossless) and .md (Obsidian-friendly).
#
# Self-defense: if cwd is not inside the vault, or the directory does not look
# like a topic dir (no _index.md or no transcripts/ subdir), exit 0 silently.
# This script must NEVER fail the session.
#
# Hook timeout default is 1.5s. We aim well under that: copy is ~ms, python
# render is ~tens of ms for typical sessions. If it ever runs long, the hook
# config sets a per-hook timeout to relax the budget.

set -uo pipefail

VAULT_ROOT="${CC_CHAT_VAULT:-$HOME/Keane/cc-chat}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER="$SCRIPT_DIR/render-transcript.py"

# Read hook input JSON from stdin (CC always sends this for SessionEnd)
INPUT="$(cat)"

# Extract fields with python (more portable than requiring jq for users)
read -r CWD TRANSCRIPT_PATH SESSION_ID < <(python3 - <<'PY' "$INPUT"
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    print("  ")
    sys.exit(0)
print(d.get("cwd", ""), d.get("transcript_path", ""), d.get("session_id", ""))
PY
)

# Bail conditions — all silent (exit 0 so we never disturb the user)
[[ -z "$CWD" || -z "$TRANSCRIPT_PATH" ]] && exit 0
[[ ! -f "$TRANSCRIPT_PATH" ]] && exit 0

# cwd must be inside the vault root
case "$CWD/" in
  "$VAULT_ROOT"/*) ;;
  *) exit 0 ;;
esac

# cwd must look like a topic dir
[[ -f "$CWD/_index.md" ]] || exit 0
[[ -d "$CWD/transcripts" ]] || exit 0

# Compose output filenames
TS="$(date +%Y%m%d-%H%M%S)"
SHORT_ID="${SESSION_ID:0:8}"
[[ -z "$SHORT_ID" ]] && SHORT_ID="unknown"
BASENAME="${TS}-${SHORT_ID}"
OUT_JSONL="$CWD/transcripts/${BASENAME}.jsonl"
OUT_MD="$CWD/transcripts/${BASENAME}.md"

# 1. Lossless copy
cp "$TRANSCRIPT_PATH" "$OUT_JSONL" 2>/dev/null || exit 0

# 2. Render MD (best-effort; failure here doesn't invalidate the JSONL copy)
if [[ -x "$RENDERER" ]] || [[ -f "$RENDERER" ]]; then
  python3 "$RENDERER" "$OUT_JSONL" "$OUT_MD" 2>/dev/null || true
fi

# stderr is shown to the user briefly on session exit; keep it concise
echo "[cc-chat] archived transcript -> $(basename "$OUT_JSONL"), $(basename "$OUT_MD")" >&2
exit 0
