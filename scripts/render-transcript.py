#!/usr/bin/env python3
"""Render a Claude Code transcript JSONL into a human-readable Markdown file.

Usage:
    render-transcript.py <input.jsonl> <output.md>

What it keeps:
    - user messages (text, command-name expansions)
    - assistant messages (text, thinking inside <details>, tool_use as compact blocks)
    - tool_result content as truncated quotes

What it drops:
    - file-history-snapshot, progress, system meta entries
    - sidechain (subagent) entries by default — they bloat the file and rarely
      matter for learning recap. Set CC_RENDER_SIDECHAIN=1 to include.

Designed for the Learning Mode vault: these MD files live in <topic>/transcripts/
and are searched/skimmed in Obsidian when needed, NOT loaded by default.
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

INCLUDE_SIDECHAIN = os.environ.get("CC_RENDER_SIDECHAIN") == "1"
TOOL_RESULT_CHARS = 800   # quote length per tool result
TOOL_INPUT_CHARS = 400    # summary length per tool input value


def fmt_ts(ts: str) -> str:
    """ISO timestamp -> HH:MM:SS in local time, fall back to raw on parse error."""
    try:
        # CC writes UTC ISO with trailing Z
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone()
        return dt.strftime("%H:%M:%S")
    except Exception:
        return ts


def truncate(s: str, n: int) -> str:
    if len(s) <= n:
        return s
    return s[:n] + f"\n…[truncated, {len(s) - n} more chars]"


def render_user(entry: dict[str, Any]) -> str:
    msg = entry.get("message") or {}
    content = msg.get("content")
    ts = fmt_ts(entry.get("timestamp", ""))
    parts: list[str] = []

    if isinstance(content, str):
        parts.append(content)
    elif isinstance(content, list):
        for item in content:
            if not isinstance(item, dict):
                continue
            t = item.get("type")
            if t == "text":
                parts.append(item.get("text", ""))
            elif t == "tool_result":
                tr = item.get("content")
                if isinstance(tr, list):
                    flat = "\n".join(
                        x.get("text", "") for x in tr if isinstance(x, dict) and x.get("type") == "text"
                    )
                else:
                    flat = str(tr) if tr is not None else ""
                quoted = "\n".join("> " + ln for ln in truncate(flat, TOOL_RESULT_CHARS).splitlines())
                parts.append(f"<sub>tool_result</sub>\n{quoted}")
    body = "\n\n".join(p for p in parts if p).strip()
    if not body:
        return ""
    return f"### 🧑 user · {ts}\n\n{body}\n"


def fmt_tool_input(inp: Any) -> str:
    if not isinstance(inp, dict):
        return truncate(str(inp), TOOL_INPUT_CHARS)
    lines = []
    for k, v in inp.items():
        if isinstance(v, str):
            sv = truncate(v, TOOL_INPUT_CHARS)
        else:
            try:
                sv = truncate(json.dumps(v, ensure_ascii=False), TOOL_INPUT_CHARS)
            except Exception:
                sv = truncate(str(v), TOOL_INPUT_CHARS)
        lines.append(f"- **{k}**: {sv}")
    return "\n".join(lines)


def render_assistant(entry: dict[str, Any]) -> str:
    msg = entry.get("message") or {}
    content = msg.get("content")
    ts = fmt_ts(entry.get("timestamp", ""))
    if not isinstance(content, list):
        return ""
    blocks: list[str] = []
    for item in content:
        if not isinstance(item, dict):
            continue
        t = item.get("type")
        if t == "text":
            txt = item.get("text", "").strip()
            if txt:
                blocks.append(txt)
        elif t == "thinking":
            th = item.get("thinking", "").strip()
            if th:
                blocks.append(
                    "<details><summary>💭 thinking</summary>\n\n"
                    + th
                    + "\n\n</details>"
                )
        elif t == "tool_use":
            name = item.get("name", "?")
            inp = item.get("input", {})
            blocks.append(f"**🔧 {name}**\n{fmt_tool_input(inp)}")
    body = "\n\n".join(blocks).strip()
    if not body:
        return ""
    return f"### 🤖 assistant · {ts}\n\n{body}\n"


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: render-transcript.py <input.jsonl> <output.md>", file=sys.stderr)
        return 2
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    if not src.is_file():
        print(f"Error: input not found: {src}", file=sys.stderr)
        return 1

    sections: list[str] = []
    first_ts: str | None = None
    last_ts: str | None = None
    cwd: str | None = None
    session_id: str | None = None

    with src.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            if entry.get("isSidechain") and not INCLUDE_SIDECHAIN:
                continue

            ts = entry.get("timestamp")
            if ts:
                if first_ts is None:
                    first_ts = ts
                last_ts = ts
            cwd = cwd or entry.get("cwd")
            session_id = session_id or entry.get("sessionId")

            t = entry.get("type")
            rendered = ""
            if t == "user" and not entry.get("isMeta"):
                rendered = render_user(entry)
            elif t == "assistant":
                rendered = render_assistant(entry)
            # other types (system meta, progress, file-history-snapshot) are dropped

            if rendered:
                sections.append(rendered)

    header = [
        "# Transcript",
        "",
        f"- **session_id**: `{session_id or 'unknown'}`",
        f"- **cwd**: `{cwd or 'unknown'}`",
        f"- **start**: {fmt_ts(first_ts) if first_ts else 'unknown'}",
        f"- **end**: {fmt_ts(last_ts) if last_ts else 'unknown'}",
        f"- **source**: `{src.name}`",
        "",
        "> 这是一份原始对话流的可读渲染。它存在 `transcripts/` 是为了 Obsidian 全文检索，而不是被 CC 默认加载。如果上次没 /consolidate，CC 会提示你回头读这个文件再整理。",
        "",
        "---",
        "",
    ]

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text("\n".join(header) + "\n\n".join(sections) + "\n", encoding="utf-8")
    print(f"Rendered {len(sections)} blocks -> {dst}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
