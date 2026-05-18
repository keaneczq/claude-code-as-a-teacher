# Vault Operating Rules — Learning Mode

This vault stores long-running learning topics and serious discussions. Each subdirectory is one topic. You (Claude) operate in **Learning Mode** here.

## Core Principle

**Transcripts are stream, insights are assets.**
- Raw conversation → `transcripts/` (append-only archive, not for reading later)
- Distilled knowledge → `concepts/`, `_map.md`, `chapters/`, etc.

Never load `transcripts/` into context unless the user explicitly asks.

## File Layout (per topic)

```
<topic>/
├── _map.md              # Knowledge map — STATUS of what's learned, in progress, pending. Always read.
├── _index.md            # "Where am I right now, what's today's focus." Always read.
├── concepts/            # One concept per file. Atomic. Can be long.
├── chapters/            # When studying a book: one file per chapter as a guided map.
├── examples/            # Code, derivations, worked problems.
├── questions/open.md    # Unresolved questions, parking lot.
├── refs/                # Book progress, paper notes, external links.
└── transcripts/         # Raw session archives. Do not read by default.
```

## Session Protocol

### At session start
1. Read `_index.md` first — it tells you the current focus.
2. Read `_map.md` — it tells you the overall state.
3. Read 1–2 relevant `concepts/*.md` only if the topic of focus requires.
4. Do NOT read `transcripts/` unless user asks.

### During session
**Auto-write (do this without asking):**
**触发"立即落档当前概念"的信号（任一即可）：**
  - 用户明确确认理解："对"、"懂了"、"没问题"、"理解了"、"OK"
  - 讨论自然过渡到下一个概念（当前概念是"已完成"状态）
  - 用户显式说："记下来"、"这点重要"、"save this"
**落档纪律：**
  - 只落已确认的那一个概念。**绝不连带写还在讨论中或刚被提到的相邻概念**——
    即使两者强相关。下一个概念等它自己的确认信号。
  - 漏掉触发信号被用户提醒后，只补漏掉的那个，不要"顺便"扩写。
- A code example or derivation the user accepts → write to `examples/` or the relevant concept file.
- Use Obsidian wikilinks `[[concept-name]]` liberally to connect concepts.

**Do NOT auto-write:**
- Half-formed speculation. Keep that in conversation until confirmed.
- Long syntheses across many concepts. Wait for `/consolidate`.
- Anything to `_map.md` mid-session unless the user explicitly says so.

### When user says "consolidate" / "总结一下" / "整理"
1. Review the conversation so far.
2. Update relevant `concepts/*.md` files with synthesis.
3. Update `_map.md`: move concepts between 已掌握 / 进行中 / 待开始 as appropriate; add new edges in 关键关系.
4. Append unresolved items to `questions/open.md`.
5. Update `_index.md` with "上次讨论到哪" for next session.

### At session end
- Remind user to run the transcript export script if it exists, or note that the conversation should be saved.
- Update `_index.md` last line with a one-sentence handoff for next session.

## Concept File Structure

Each `concepts/<name>.md`:

```markdown
# <Concept Name>

## 定义
<one-paragraph precise definition>

## 直觉
<plain-language intuition, why it matters>

## 公式 / 形式化
<必须用 LaTeX：行内 $...$，块级 $$...$$。
不要用 ASCII 排版（如 `WoE_i = ln(...)`）——那是终端临时显示，不进文件。
Concept 文件的渲染目标是 Obsidian。>

## 例子
<canonical example, ideally one good one>

## 关系
- 关联到 [[other-concept]] because ...
- 对比 [[similar-concept]]: ...

## 我的疑问
- ...
```

Sections can be omitted if not yet developed. Keep growing the file as understanding deepens. Length is fine; this file is loaded only when discussed.

## `_map.md` Discipline

`_map.md` is the spine. Keep it under ~5k tokens. It is **navigation + status**, not a dump of content. Format:

```markdown
# <Topic> — Knowledge Map

## 已掌握
- [[concept-a]] — one-line summary of what's understood
- [[concept-b]] — ...

## 进行中
- [[concept-c]] — what's understood, what's unclear → see [[questions/open#anchor]]

## 待开始
- topic / chapter / area name
- ...

## 关键关系
- A → B: because ...
- C ↔ D: contrast on ...
```

When `_map.md` exceeds ~5k tokens, propose to the user that it be split or further distilled.

## Token Discipline

Per-session input target: ~10–15k tokens (map + index + 1–2 concepts).
If you find yourself loading more, stop and ask the user whether to narrow focus.

## Skills Policy in Learning Mode

**Do NOT invoke these skills even if they seem to apply:**
- `simplify` — concept files are knowledge artifacts, not code to refactor.
- `superpowers:test-driven-development` — files in `examples/` are illustrations, not production code.
- `superpowers:verification-before-completion` — `/consolidate` is synthesis, not a completion claim.
- `superpowers:requesting-code-review` / `superpowers:receiving-code-review` — peer review is not the workflow here.
- `superpowers:writing-plans` / `superpowers:executing-plans` / `superpowers:subagent-driven-development` — learning is exploratory, not plan-driven.
- `superpowers:finishing-a-development-branch` — there is no "branch to finish" in a learning vault.
- `superpowers:using-git-worktrees` — single-vault workflow, no worktrees.
- `frontend-design:*`, `document-skills:frontend-design`, `document-skills:web-artifacts-builder`, `document-skills:webapp-testing` — not a UI project.

**Skills that ARE useful here:**
- `superpowers:brainstorming` — when starting to explore a new concept area or learning direction.
- `superpowers:systematic-debugging` — only if a code example in `examples/` genuinely misbehaves.
- `document-skills:doc-coauthoring` — for long-form note refinement when the user explicitly requests it.
- `matplotx-styling` — when the user asks for a plot in a learning example.

If unsure whether a skill applies, ask the user instead of invoking.

## What This Mode Is NOT

- Not a place for casual chat. Use the regular Claude.ai or another tool for that.
- Not a coding agent. Don't proactively run builds, tests, lint.
- Not autonomous. Confirm before destructive edits or large rewrites of `_map.md`.
- Not a planning environment. Learning is exploratory; resist the urge to "plan first then execute."
