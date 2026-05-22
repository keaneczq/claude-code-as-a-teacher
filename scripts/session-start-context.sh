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

# Builds the additionalContext payload for Learning Mode.
# Args: $1 = topic_dir (unused for now; reserved for parity with build_context_personal in Task 8)
#       $2 = HANDOFF (already read by caller — the tail-30 of _index.md)
#       $3 = WARNING (may be empty)
# Stdout: the additionalContext string.
# This refactor preserves byte-for-byte the original inline composition. Do NOT change the wire format.
build_context_learning() {
  local topic_dir="$1" handoff="$2" warning="${3:-}"
  printf '## Handoff from _index.md\n\n%s' "$handoff"
  if [[ -n "$warning" ]]; then
    printf '\n\n## 上次整理状态\n\n%s' "$warning"
  fi
}

# Reads <topic>/.cc-mode. Echoes the trimmed mode name on stdout.
# Echoes "learning" if the file is missing.
# Echoes "learning" + emits a stderr warning if the value is unknown.
# Args: $1 = topic_dir
# Stdout: mode name (always one of: learning, personal)
# Stderr (optional): WARN_INVALID_MODE=<raw> — for the dispatcher to attach to systemMessage
read_mode() {
  local topic_dir="$1"
  local f="$topic_dir/.cc-mode"
  if [[ ! -f "$f" ]]; then
    echo learning
    return
  fi
  local raw
  raw=$(tr -d '[:space:]' < "$f")
  case "$raw" in
    learning|personal) echo "$raw" ;;
    *) echo "WARN_INVALID_MODE=$raw" >&2; echo learning ;;
  esac
}

# Builds the additionalContext for Personal Mode.
# Injects: _index handoff (tail-30) + optional warning + full _profile.md + full positions/<focus>.md.
# Args: $1 = topic_dir, $2 = HANDOFF, $3 = WARNING (may be empty)
# Stdout: additionalContext string.
# Stderr (optional): WARN_MISSING_FOCUS=<relpath> if focus is named but the file is missing.
build_context_personal() {
  local topic_dir="$1" handoff="$2" warning="${3:-}"
  printf '## Handoff from _index.md\n\n%s' "$handoff"
  if [[ -n "$warning" ]]; then
    printf '\n\n## 上次整理状态\n\n%s' "$warning"
  fi
  if [[ -f "$topic_dir/_profile.md" ]]; then
    printf '\n\n## _profile.md\n\n'
    cat "$topic_dir/_profile.md"
  fi
  # Find first "- positions/<name>" under "## 焦点子主题", outside HTML comment blocks.
  local focus
  focus=$(awk '
    BEGIN { in_focus=0; in_comment=0 }
    /<!--/ { in_comment=1 }
    /-->/  { in_comment=0; next }
    !in_comment && /^## 焦点子主题/ { in_focus=1; next }
    in_focus && !in_comment && /^## / { exit }
    in_focus && !in_comment && /^- positions\// {
      sub(/^- positions\//, "")
      sub(/[[:space:]]+$/, "")
      sub(/\.md$/, "")
      sub(/[[:space:]]*#.*/, "")
      print
      exit
    }
  ' "$topic_dir/_index.md")
  if [[ -n "$focus" ]]; then
    local fp="$topic_dir/positions/$focus.md"
    if [[ -f "$fp" ]]; then
      printf '\n\n## positions/%s.md (focus)\n\n' "$focus"
      cat "$fp"
    else
      echo "WARN_MISSING_FOCUS=positions/$focus.md" >&2
    fi
  fi
}

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

# Read mode (with stderr → temp file to capture WARN_INVALID_MODE).
# Ensure temp warning files are cleaned up even on SIGINT / unexpected exit.
MODE_WARN_FILE=""
CTX_WARN_FILE=""
trap '[[ -n "${MODE_WARN_FILE:-}" ]] && rm -f "$MODE_WARN_FILE"; [[ -n "${CTX_WARN_FILE:-}" ]] && rm -f "$CTX_WARN_FILE"' EXIT
MODE_WARN_FILE=$(mktemp)
MODE=$(read_mode "$CWD" 2>"$MODE_WARN_FILE")
MODE_WARN=$(cat "$MODE_WARN_FILE"); rm -f "$MODE_WARN_FILE"

# Dispatch by mode (with stderr → temp file to capture build-time warnings).
CTX_WARN_FILE=$(mktemp)
case "$MODE" in
  personal)
    CONTEXT="$(build_context_personal "$CWD" "$HANDOFF" "$WARNING" 2>"$CTX_WARN_FILE")"
    ;;
  *)
    CONTEXT="$(build_context_learning "$CWD" "$HANDOFF" "$WARNING" 2>"$CTX_WARN_FILE")"
    ;;
esac
CTX_WARN=$(cat "$CTX_WARN_FILE"); rm -f "$CTX_WARN_FILE"

# --- 3. Build the user-visible systemMessage ---
# Concise, single-line. Visible in the terminal when CC starts.
if [[ -n "$WARNING" ]]; then
  SYSMSG="📌 cc-chat: 已注入 [${TOPIC}] handoff (${HANDOFF_LINES} 行)  ⚠ 上次未 /consolidate，建议恢复 transcripts/${LAST_MD_NAME}"
else
  SYSMSG="📌 cc-chat: 已注入 [${TOPIC}] handoff (${HANDOFF_LINES} 行)"
fi

# Append mode-related warnings, if any.
if [[ "$MODE_WARN" =~ WARN_INVALID_MODE=(.*) ]]; then
  SYSMSG="${SYSMSG}  ⚠ .cc-mode 值无效（\"${BASH_REMATCH[1]}\"），按 learning 处理"
fi
if [[ "$CTX_WARN" =~ WARN_MISSING_FOCUS=(.*) ]]; then
  SYSMSG="${SYSMSG}  ⚠ 焦点文件不存在: ${BASH_REMATCH[1]}"
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
