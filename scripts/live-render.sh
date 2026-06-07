#!/usr/bin/env bash
# live-render.sh — invoked by the Stop hook (fires after each assistant reply).
# Re-renders the in-progress transcript into <topic>/_live.md so the user can
# read the running conversation — LaTeX, code, everything — in Obsidian's
# reading view instead of squinting at the terminal.
#
# Why a hook and not the model double-writing: the transcript JSONL already
# exists and grows every turn. Re-rendering it costs zero model tokens and
# never depends on the model remembering to mirror its own output.
#
# _live.md is scratch. It lives at the topic root (not transcripts/, which is
# the durable archive) and is wiped by export-transcript.sh on SessionEnd.
#
# Self-defense mirrors export-transcript.sh: if cwd is not inside the vault, or
# the directory doesn't look like a topic dir, exit 0 silently. This script
# must NEVER fail or delay the session — the Stop hook runs on every turn.

set -uo pipefail

VAULT_ROOT="${CC_CHAT_VAULT:-$HOME/Keane/cc-chat}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER="$SCRIPT_DIR/render-transcript.py"

# Read hook input JSON from stdin (CC sends this for Stop)
INPUT="$(cat 2>/dev/null || true)"

read -r CWD TRANSCRIPT_PATH < <(python3 - <<'PY' "$INPUT"
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    print("  ")
    sys.exit(0)
print(d.get("cwd", ""), d.get("transcript_path", ""))
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

OUT_MD="$CWD/_live.md"

# Race guard: the Stop hook can fire before this turn's final assistant message
# is flushed to the transcript JSONL. If we render immediately we capture only
# through the *previous* turn, so _live.md trails reality by one round. Poll
# until the last meaningful message (skipping system/meta/attachment tails) is
# an assistant entry, then render. Bounded well under the 10s hook timeout;
# normally returns on the first try with no perceptible delay.
wait_for_assistant() {
  local i
  for ((i = 0; i < 10; i++)); do
    last_role="$(python3 - "$TRANSCRIPT_PATH" <<'PY' 2>/dev/null
import json, sys
last = ""
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            t = d.get("type")
            if t == "assistant":
                last = "assistant"
            elif t == "user" and not d.get("isMeta"):
                last = "user"
            # system / attachment / meta tails are ignored
except Exception:
    pass
print(last)
PY
)"
    [[ "$last_role" == "assistant" ]] && return 0
    sleep 0.25
  done
  return 0  # give up quietly; render whatever we have rather than stall
}

# Render straight from the live transcript path. Best-effort; a render failure
# must not surface to the user mid-session.
if [[ -f "$RENDERER" ]]; then
  wait_for_assistant
  python3 "$RENDERER" "$TRANSCRIPT_PATH" "$OUT_MD" 2>/dev/null || true
fi

exit 0
