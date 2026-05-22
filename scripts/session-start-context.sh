#!/usr/bin/env bash
# session-start-context.sh — invoked by the SessionStart hook.
#
# When cwd is a topic directory inside the vault, emit a JSON payload with:
#
#   - hookSpecificOutput.additionalContext  → injected silently into Claude's
#     context (the _index.md handoff tail + optional unconsolidated warning).
#   - systemMessage                         → a short line shown in the user's
#     terminal so it's obvious the hook fired and which topic is loaded. This
#     is the explicit confirmation that user and model are on the same page.
#
# When cwd is not a topic dir, exits silently (no context injected, no message).
#
# This script never calls an LLM. Cost is grep + ls + stat. Keep it under 1s.

set -uo pipefail

VAULT_ROOT="${CC_CHAT_VAULT:-$HOME/Keane/cc-chat}"

# Read hook JSON from stdin to discover cwd. Fallback to $PWD if parsing fails.
INPUT="$(cat 2>/dev/null || true)"
CWD="$(python3 - <<'PY' "$INPUT" 2>/dev/null
import json, sys
try:
    print(json.loads(sys.argv[1]).get("cwd", ""))
except Exception:
    print("")
PY
)"
[[ -z "$CWD" ]] && CWD="$PWD"

# Bail if not in a topic directory under the vault
case "$CWD/" in
  "$VAULT_ROOT"/*) ;;
  *) exit 0 ;;
esac
[[ -f "$CWD/_index.md" ]] || exit 0

INDEX="$CWD/_index.md"
TX_DIR="$CWD/transcripts"
TOPIC="$(basename "$CWD")"

# --- 1. Detect last consolidate state ---
WARNING=""
LAST_MD_NAME=""
if [[ -d "$TX_DIR" ]]; then
  LAST_JSONL="$(ls -t "$TX_DIR"/*.jsonl 2>/dev/null | head -1)"
  if [[ -n "$LAST_JSONL" ]]; then
    if grep -qE '/consolidate|整理一下|总结一下|consolidate now|归档一下' "$LAST_JSONL"; then
      CONSOLIDATED=1
    else
      CONSOLIDATED=0
    fi
    if [[ "$INDEX" -nt "$LAST_JSONL" ]]; then
      INDEX_FRESH=1
    else
      INDEX_FRESH=0
    fi
    if [[ $CONSOLIDATED -eq 0 && $INDEX_FRESH -eq 0 ]]; then
      LAST_MD_NAME="$(basename "${LAST_JSONL%.jsonl}.md")"
      WARNING="⚠ 上次 session 看不到 /consolidate 痕迹，且 _index.md 在 session 后未更新。\
建议：先读 \`transcripts/${LAST_MD_NAME}\` 回忆上次到哪，再 /consolidate，最后才进入今天的新焦点。\
（如果你确认上次已整理过、只是没用关键词，请忽略本提示。）"
    fi
  fi
fi

# --- 2. Build additionalContext (handoff + optional warning) ---
HANDOFF="$(tail -n 30 "$INDEX")"
HANDOFF_LINES="$(printf '%s\n' "$HANDOFF" | wc -l | tr -d ' ')"

CONTEXT="## Handoff from _index.md

$HANDOFF"

if [[ -n "$WARNING" ]]; then
  CONTEXT="$CONTEXT

## 上次整理状态

$WARNING"
fi

# --- 3. Build the user-visible systemMessage ---
# Concise, single-line. Visible in the terminal when CC starts.
if [[ -n "$WARNING" ]]; then
  SYSMSG="📌 cc-chat: 已注入 [${TOPIC}] handoff (${HANDOFF_LINES} 行)  ⚠ 上次未 /consolidate，建议恢复 transcripts/${LAST_MD_NAME}"
else
  SYSMSG="📌 cc-chat: 已注入 [${TOPIC}] handoff (${HANDOFF_LINES} 行)"
fi

# --- 4. Emit JSON for CC to consume ---
python3 - "$CONTEXT" "$SYSMSG" <<'PY'
import json, sys
context, sysmsg = sys.argv[1], sys.argv[2]
out = {
    "systemMessage": sysmsg,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    },
}
print(json.dumps(out, ensure_ascii=False))
PY

exit 0
