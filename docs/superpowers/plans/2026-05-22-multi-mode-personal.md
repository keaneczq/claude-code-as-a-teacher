# Multi-Mode Vault: Personal Mode + Mode 抽象 — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend cc-chat from single-mode (Learning) to multi-mode by introducing a `.cc-mode` sentinel, per-topic `CLAUDE.md`, a `templates/modes/<mode>/` layout, mode-aware `session-start-context.sh`, the new Personal Mode end-to-end, and Rule 0 across both modes — with zero behavioral regression for the existing `feature-engineering` topic.

**Architecture:** Sentinel-based mode declaration (`<topic>/.cc-mode` single line). `new-topic.sh` deploys per-mode templates from `templates/modes/<mode>/`. `session-start-context.sh` reads the sentinel and dispatches to `build_context_learning` (current behavior) or `build_context_personal` (full `_profile.md` + focus `positions/<x>.md` injection). Rule 0 (objectivity / no flattery / default-challenge) lives at the top of every mode's `CLAUDE.md`.

**Tech Stack:** Bash 4+, Python 3 (already used inside `session-start-context.sh` for stdin JSON parsing), Markdown templates. No new dependencies. Fixture-based smoke tests in bash — no test framework introduced.

**Spec:** `docs/superpowers/specs/2026-05-22-multi-mode-personal-design.md` — read this before starting. The plan implements §3–§6 of the spec.

---

## File Structure

### Created

| Path | Responsibility |
|---|---|
| `templates/modes/learning/CLAUDE.md` | Learning Mode rules (current `vault-CLAUDE.md` content + Rule 0 prepended) |
| `templates/modes/learning/topic-_map.md` | Learning Mode `_map.md` template (moved from `templates/topic-_map.md`) |
| `templates/modes/learning/topic-_index.md` | Learning Mode `_index.md` template (moved from `templates/topic-_index.md`) |
| `templates/modes/personal/CLAUDE.md` | Personal Mode rules + Rule 0 |
| `templates/modes/personal/topic-_map.md` | Personal Mode `_map.md` template (subtopic-list shape) |
| `templates/modes/personal/topic-_index.md` | Personal Mode `_index.md` template (with `## 焦点子主题` anchor) |
| `templates/modes/personal/topic-_profile.md` | Personal Mode `_profile.md` seed |
| `tests/test-new-topic.sh` | Smoke test driver for `new-topic.sh` |
| `tests/test-session-start-context.sh` | Smoke test driver for the SessionStart hook |
| `tests/fixtures/sample-vault/` | Throwaway fixture vault used by both test drivers |

### Modified

| Path | What Changes |
|---|---|
| `templates/vault-CLAUDE.md` | Rewritten as a 4–6-line signpost |
| `scripts/new-topic.sh` | Adds `--mode` flag, reads from `templates/modes/<mode>/`, writes `.cc-mode`, idempotent vault-root deploy, mode-conditional dir set |
| `scripts/session-start-context.sh` | Adds `read_mode` helper, refactors current logic into `build_context_learning`, adds `build_context_personal`, adds dispatcher |
| `docs/conventions.md` | Documents `--mode` flag, per-topic `CLAUDE.md`, and one-time migration steps |

### Deleted

| Path | Why |
|---|---|
| `templates/topic-_map.md` | Moved to `templates/modes/learning/topic-_map.md`; no compatibility shim |
| `templates/topic-_index.md` | Moved to `templates/modes/learning/topic-_index.md` |

### Out of repo (one-time, runs against the user's vault — NOT executed by this plan)

| Action | Owner |
|---|---|
| Write `learning` to `~/Keane/cc-chat/feature-engineering/.cc-mode` | User, post-merge |
| Replace `~/Keane/cc-chat/CLAUDE.md` with the new signpost | User, post-merge |
| Deploy `templates/modes/learning/CLAUDE.md` to `~/Keane/cc-chat/feature-engineering/CLAUDE.md` | User, post-merge |

The plan ends with the user-side migration as a documented checklist (Task 11), not as automated code. The implementer must NOT touch `~/Keane/cc-chat/` from inside the worktree.

---

## Process Notes

- **Worktree:** This plan should run in a worktree per the brainstorming skill's recommendation. The implementer stays in the worktree until merge; user-side migration happens after merge to `main`.
- **TDD scope:** Bash scripts (`new-topic.sh`, `session-start-context.sh`) are tested via fixture-based smoke tests. Markdown template files are verified by inspection — they are documents, not code.
- **Backward compatibility safety net:** Throughout the plan, the existing `feature-engineering` topic must continue to work without `.cc-mode`. The hook fallback (missing `.cc-mode` → treat as `learning`) is what makes this safe.
- **Commit cadence:** Each task ends with a commit. Use `feat:` for new functionality, `refactor:` for moves, `docs:` for doc-only changes, `test:` for test scaffolding.
- **Skills:** Use @superpowers:test-driven-development for the bash test tasks. Use @superpowers:verification-before-completion before claiming any task done.

## Task 1: Reorganize templates into `templates/modes/learning/`

This is a pure move + git-detectable rename. Establishes the new layout and unblocks subsequent tasks.

**Files:**
- Create dir: `templates/modes/learning/`
- Move: `templates/topic-_map.md` → `templates/modes/learning/topic-_map.md`
- Move: `templates/topic-_index.md` → `templates/modes/learning/topic-_index.md`
- Copy: `templates/vault-CLAUDE.md` → `templates/modes/learning/CLAUDE.md` (verbatim — Rule 0 is added in Task 3)

- [ ] **Step 1: Create the directory and move map/index templates**

```bash
mkdir -p templates/modes/learning
git mv templates/topic-_map.md templates/modes/learning/topic-_map.md
git mv templates/topic-_index.md templates/modes/learning/topic-_index.md
```

- [ ] **Step 2: Copy `vault-CLAUDE.md` to `modes/learning/CLAUDE.md` (verbatim)**

```bash
cp templates/vault-CLAUDE.md templates/modes/learning/CLAUDE.md
```

The original `templates/vault-CLAUDE.md` stays put for now — it gets rewritten as the signpost in Task 2.

- [ ] **Step 3: Verify the diff is move-only**

```bash
git status
git diff --stat
```

Expected: two `R` (renamed) entries for the map/index templates (≥90% similarity), one `??` for `templates/modes/learning/CLAUDE.md`, no other changes.

- [ ] **Step 4: Commit**

```bash
git add templates/modes/learning/
git commit -m "refactor(templates): move learning-mode templates to templates/modes/learning/"
```

---

## Task 2: Rewrite `templates/vault-CLAUDE.md` as signpost

The vault-root `CLAUDE.md` no longer carries Learning Mode rules — those moved to per-topic copies. It becomes a 4–6-line "cd into a topic first" instruction.

**Files:**
- Modify: `templates/vault-CLAUDE.md` (full replacement)

- [ ] **Step 1: Replace contents with the spec's exact signpost text**

Write `templates/vault-CLAUDE.md` with exactly this content (matching spec §Architecture: Mode Abstraction § Per-topic CLAUDE.md):

```markdown
# cc-chat vault

这里是多 topic / 多 mode 的根目录，不直接承载任何 topic 的对话规则。

请进入具体 topic 目录后再启动 Claude Code：

    cd ~/Keane/cc-chat/<topic-slug>
    claude

每个 topic 目录有自己的 `CLAUDE.md` 和 `.cc-mode`，决定该 topic 的运行模式。
新建 topic：在仓库目录运行 `./scripts/new-topic.sh [--mode learning|personal] <slug> [title]`。
```

- [ ] **Step 2: Verify length**

```bash
wc -l templates/vault-CLAUDE.md
```

Expected: between 8 and 12 lines (the signpost is intentionally short).

- [ ] **Step 3: Commit**

```bash
git add templates/vault-CLAUDE.md
git commit -m "refactor(templates): rewrite vault-CLAUDE.md as multi-topic signpost"
```

---

## Task 3: Prepend Rule 0 to `templates/modes/learning/CLAUDE.md`

Adds the cross-mode top-priority rule to the Learning Mode template. The exact text comes verbatim from spec §Architecture: Rule 0 — Objectivity, No Flattery § Rule 0 text.

**Files:**
- Modify: `templates/modes/learning/CLAUDE.md` (insert Rule 0 block at top, before existing content)

- [ ] **Step 1: Read the current file's first 5 lines to know where to insert**

```bash
head -5 templates/modes/learning/CLAUDE.md
```

Note the existing first heading (likely `# cc-chat — Learning Vault` or similar). Rule 0 is inserted **immediately after** the H1 title and any tagline directly under it, **before** the first `##` section.

- [ ] **Step 2: Insert Rule 0 block**

Insert the full Rule 0 markdown block (from spec lines ~117–172, the section starting with `## Rule 0：客观，不迎合（高于本文件其他所有规则）` and ending with the `0.5 落档时` block). Insert as the first `##`-level section in the file. Subsequent existing sections stay in their current order.

Use `Edit` tool with `old_string = "<first existing ## heading>"` and `new_string = "<full Rule 0 block>\n\n<first existing ## heading>"`.

- [ ] **Step 3: Verify Rule 0 sections are all present**

```bash
grep -n "^### 0\.[0-5]\|^## Rule 0" templates/modes/learning/CLAUDE.md
```

Expected: 6 lines — `## Rule 0：…` plus `### 0.1`, `### 0.2`, `### 0.3`, `### 0.4`, `### 0.5`.

- [ ] **Step 4: Verify existing Learning Mode rules are still intact**

```bash
grep -c "^## " templates/modes/learning/CLAUDE.md
```

Expected: at least the original number of `##` sections + 1 (for Rule 0). If the count is wrong, you've accidentally overwritten existing content — revert and retry.

- [ ] **Step 5: Commit**

```bash
git add templates/modes/learning/CLAUDE.md
git commit -m "feat(learning-mode): prepend Rule 0 (objectivity, no flattery) to Learning Mode CLAUDE.md"
```

---

## Task 4: Create Personal Mode templates

Brand-new files. Content is fully specified in the spec — no design choices to make here.

**Files:**
- Create: `templates/modes/personal/CLAUDE.md`
- Create: `templates/modes/personal/topic-_map.md`
- Create: `templates/modes/personal/topic-_index.md`
- Create: `templates/modes/personal/topic-_profile.md`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p templates/modes/personal
```

- [ ] **Step 2: Write `templates/modes/personal/CLAUDE.md`**

Structure (in order from top):

1. **Rule 0 block** — verbatim from spec §Rule 0 text. Same content as in Learning Mode.
2. **`## Personal Mode 概述`** — 5–8 lines: this mode is for personal/life questions; central artifacts are `_profile.md` (who-you-are, cross-subtopic) and `positions/<subtopic>.md` (synthesized current stance + evolution); transcripts are read-allowed (unlike Learning Mode).
3. **`## 子主题与 positions/`** — 1 file per subtopic; structure (5 subsections: 当前立场 / 仍在演化 / 演化轨迹 / 相关 transcript / 与 _profile 的接口); soft cap ~5k tokens; rewrite-not-append discipline; if LLM disagrees with user on stance, keep user's version and log disagreement in 演化轨迹 (Rule 0.5).
4. **`## _profile.md 的写入纪律`** — user writes by hand; LLM may **propose** during /consolidate but **must ask** before writing; soft cap ~3k tokens; what belongs (5 categories from spec) and what doesn't.
5. **`## /consolidate 在 Personal Mode 下`** — full 5-step protocol from spec §/consolidate in Personal Mode. Include the "Rule 0 reinforcement at consolidation time" reminder at the end.
6. **`## 隐式 /consolidate 触发`** — switching subtopics counts as a branch selection.
7. **`## Transcripts 的角色`** — default not auto-loaded, but reading rendered .md is allowed when user asks ("look back at last session"). Differs from Learning Mode.
8. **`## Skills Policy in Personal Mode`** — copy Learning Mode's skills policy structure verbatim (allowed/disallowed list), with these deltas: drop `superpowers:systematic-debugging` and `matplotx-styling` from the useful list; keep `superpowers:brainstorming` and `document-skills:doc-coauthoring`; same blocklist as Learning Mode.

Use spec §3 (Personal Mode: Artifact Structure) and §5 (/consolidate in Personal Mode) as the authoritative source. The file will run ~150–250 lines.

- [ ] **Step 3: Write `templates/modes/personal/topic-_map.md`**

Exact content:

```markdown
# {{TOPIC_TITLE}} — Subtopics

## 活跃
<!-- 当前在动的子主题。一行一条，格式：
- [[positions/<slug>]] — 当前主要在想：<一句话> / 上次活跃 YYYY-MM-DD
-->

## 沉睡（>30 天未碰）
<!-- 30 天没动的子主题在 /consolidate 时由 LLM 移到这里 -->

## 想开但还没开
<!-- 用户随时往这里加；LLM 不主动写 -->
```

- [ ] **Step 4: Write `templates/modes/personal/topic-_index.md`**

Exact content:

```markdown
# {{TOPIC_TITLE}} — Current Focus

## 今天打算搞什么
<!-- 一句话；用户在 SessionStart 前手写或上次 /consolidate 留下 -->

## 焦点子主题
<!-- hook 会读这一节的第一条 - positions/<slug> 行，注入对应文件
- positions/<slug>
-->

## 上次结束时的 handoff
<!-- 上次 /consolidate 后由 LLM 写：本次最值得续的点；下次焦点候选 -->
```

- [ ] **Step 5: Write `templates/modes/personal/topic-_profile.md`**

Exact content (matches spec §3 § _profile.md § Initial template scaffolding):

```markdown
# {{TOPIC_TITLE}} — Profile

> 这个文件是关于"你是谁"的稳定背景信息。手写为主；LLM 在 /consolidate 时
> 可能提议补充，但必须先问你。控制在 ~3k tokens 以内。

## 关键经历
<!-- 教育 / 职业 / 家庭 / 重大转折点；一行一条 -->

## 价值观底色
<!-- 一行一条；论证去 positions/worldview.md -->

## 关键关系
<!-- 家人，以及对你决策有显著影响的人 -->

## 性格 / 思维倾向
<!-- 自评 与 LLM 观察分别标注 -->

## 当前生活状态快照
<!-- 工作 / 城市 / 健康 / 财务粗轮廓——只到给建议需要的粒度 -->
```

- [ ] **Step 6: Verify all 4 files exist and contain the `{{TOPIC_TITLE}}` placeholder where expected**

```bash
ls templates/modes/personal/
grep -l '{{TOPIC_TITLE}}' templates/modes/personal/topic-_*.md
```

Expected: 4 files listed; 3 of them (`topic-_map.md`, `topic-_index.md`, `topic-_profile.md`) contain `{{TOPIC_TITLE}}`. `CLAUDE.md` does **not** carry the placeholder — it's mode-rules, not topic-specific.

- [ ] **Step 7: Verify Rule 0 in Personal CLAUDE.md is identical to Learning's**

```bash
diff <(awk '/^## Rule 0/,/^## [^R]/' templates/modes/learning/CLAUDE.md | sed '$d') \
     <(awk '/^## Rule 0/,/^## [^R]/' templates/modes/personal/CLAUDE.md | sed '$d')
```

Expected: empty diff (Rule 0 text is identical across modes per spec).

- [ ] **Step 8: Commit**

```bash
git add templates/modes/personal/
git commit -m "feat(personal-mode): add Personal Mode templates (CLAUDE.md, _map, _index, _profile)"
```

## Task 5: Smoke-test driver scaffolding

Establishes the test layout used by Tasks 6 and 8. Creates `tests/` with a fixture vault and helper scaffolding. No production code touched yet.

**Files:**
- Create: `tests/test-new-topic.sh`
- Create: `tests/test-session-start-context.sh`
- Create: `tests/fixtures/sample-vault/.gitkeep`
- Create: `tests/README.md` (one paragraph)

- [ ] **Step 1: Create directory layout**

```bash
mkdir -p tests/fixtures/sample-vault
touch tests/fixtures/sample-vault/.gitkeep
```

- [ ] **Step 2: Write `tests/test-new-topic.sh` skeleton**

```bash
#!/usr/bin/env bash
# Smoke test for scripts/new-topic.sh.
# Spins a temp vault, invokes new-topic.sh against it, asserts file shape.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/new-topic.sh"

PASS=0; FAIL=0
ok()   { echo "  ok   $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

mk_vault() {
  local d
  d=$(mktemp -d -t ccvault.XXXXXX)
  echo "$d"
}

# Tests will be filled in by Task 6.
test_placeholder() { :; }

test_placeholder

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 3: Write `tests/test-session-start-context.sh` skeleton**

```bash
#!/usr/bin/env bash
# Smoke test for scripts/session-start-context.sh.
# Constructs fixture topic dirs, pipes JSON via stdin, asserts JSON output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/session-start-context.sh"

PASS=0; FAIL=0
ok()   { echo "  ok   $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

mk_vault() {
  local d
  d=$(mktemp -d -t cchook.XXXXXX)
  echo "$d"
}

# Tests will be filled in by Task 8.
test_placeholder() { :; }

test_placeholder

echo
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 4: Make both executable**

```bash
chmod +x tests/test-new-topic.sh tests/test-session-start-context.sh
```

- [ ] **Step 5: Write `tests/README.md`**

```markdown
# Tests

Bash-based smoke tests for the cc-chat helper scripts.

## Run

    ./tests/test-new-topic.sh
    ./tests/test-session-start-context.sh

Each driver creates a temp vault under `$TMPDIR`, invokes the target script,
and asserts file shape / output. Drivers exit non-zero on any failure.
No external test framework. Bash 4+, Python 3 required.
```

- [ ] **Step 6: Run skeletons (must succeed before commit)**

```bash
./tests/test-new-topic.sh
./tests/test-session-start-context.sh
```

Expected: each prints `Passed: 0  Failed: 0` and exits 0.

- [ ] **Step 7: Commit**

```bash
git add tests/
git commit -m "test: scaffold bash smoke-test drivers for new-topic.sh and session-start-context.sh"
```

---

## Task 6: TDD — `new-topic.sh --mode` flag

Per @superpowers:test-driven-development: write failing tests first, then implement.

**Files:**
- Modify: `tests/test-new-topic.sh` (replace `test_placeholder` with real cases)
- Modify: `scripts/new-topic.sh` (add `--mode` flag, route templates, write `.cc-mode`, idempotent vault deploy)

### 6a — Write failing tests

- [ ] **Step 1: Replace `test_placeholder` with the three test cases below**

```bash
# Test 1: default mode (no flag) → learning, with .cc-mode written
test_default_mode() {
  local vault topic
  vault=$(mk_vault)
  CC_CHAT_VAULT="$vault" "$SCRIPT" demo-default "Demo Default" >/dev/null
  topic="$vault/demo-default"

  [[ -f "$topic/.cc-mode" ]]                         && ok ".cc-mode written" \
                                                     || fail ".cc-mode missing"
  [[ "$(cat "$topic/.cc-mode")" == "learning" ]]     && ok ".cc-mode contains 'learning'" \
                                                     || fail ".cc-mode wrong: $(cat "$topic/.cc-mode")"
  [[ -f "$topic/CLAUDE.md" ]]                        && ok "topic CLAUDE.md deployed" \
                                                     || fail "topic CLAUDE.md missing"
  [[ -d "$topic/concepts" ]]                         && ok "concepts/ created (learning)" \
                                                     || fail "concepts/ missing"
  [[ -f "$topic/_map.md" ]] && grep -q "Demo Default" "$topic/_map.md" \
                                                     && ok "_map title substituted" \
                                                     || fail "_map title not substituted"
  rm -rf "$vault"
}

# Test 2: --mode personal → personal artifacts only
test_personal_mode() {
  local vault topic
  vault=$(mk_vault)
  CC_CHAT_VAULT="$vault" "$SCRIPT" --mode personal personal "Personal" >/dev/null
  topic="$vault/personal"

  [[ "$(cat "$topic/.cc-mode")" == "personal" ]]     && ok "personal: .cc-mode=personal" \
                                                     || fail "personal: wrong .cc-mode"
  [[ -f "$topic/_profile.md" ]]                      && ok "personal: _profile.md created" \
                                                     || fail "personal: _profile.md missing"
  [[ -d "$topic/positions" ]]                        && ok "personal: positions/ created" \
                                                     || fail "personal: positions/ missing"
  [[ ! -d "$topic/concepts" ]]                       && ok "personal: concepts/ NOT created" \
                                                     || fail "personal: concepts/ wrongly created"
  [[ ! -d "$topic/chapters" ]]                       && ok "personal: chapters/ NOT created" \
                                                     || fail "personal: chapters/ wrongly created"
  grep -q "Personal" "$topic/_profile.md"            && ok "personal: _profile title substituted" \
                                                     || fail "personal: _profile title not substituted"
  rm -rf "$vault"
}

# Test 3: invalid --mode → script exits non-zero, no topic created
test_invalid_mode() {
  local vault rc
  vault=$(mk_vault)
  set +e
  CC_CHAT_VAULT="$vault" "$SCRIPT" --mode bogus x "X" >/dev/null 2>&1
  rc=$?
  set -e
  [[ $rc -ne 0 ]]                                    && ok "invalid mode: exits non-zero ($rc)" \
                                                     || fail "invalid mode: exited 0"
  [[ ! -d "$vault/x" ]]                              && ok "invalid mode: no topic dir created" \
                                                     || fail "invalid mode: topic dir created"
  rm -rf "$vault"
}

test_default_mode
test_personal_mode
test_invalid_mode
```

Remove the `test_placeholder` invocation.

- [ ] **Step 2: Run tests — they MUST fail**

```bash
./tests/test-new-topic.sh
```

Expected: failures (the script doesn't yet support `--mode`, won't read from `templates/modes/<mode>/`, won't write `.cc-mode`). Note which assertions fail so 6b can target them.

If tests *pass* before any implementation, the test cases don't actually exercise new behavior — fix the tests.

### 6b — Implement to make tests pass

- [ ] **Step 3: Modify `scripts/new-topic.sh`**

Required changes (preserving existing behavior for the no-flag case where compatible):

1. **Add `--mode` parsing.** Accept `--mode learning` or `--mode personal` as the first arg(s). Default to `learning`. Reject any other value with `echo "Unknown mode: $mode" >&2; exit 2`.
2. **Honor `CC_CHAT_VAULT` env var** for testability. If set, use it as the vault root instead of `~/Keane/cc-chat`. (The test driver sets this; production runs leave it unset.)
3. **Read templates from `templates/modes/<mode>/`** instead of `templates/`. Map: `CLAUDE.md` → `<topic>/CLAUDE.md`, `topic-_map.md` → `<topic>/_map.md`, `topic-_index.md` → `<topic>/_index.md`. Apply `{{TOPIC_TITLE}}` substitution to map/index (and to `topic-_profile.md` if mode=personal).
4. **Write `.cc-mode`** to the topic root with the mode name (single line, no trailing newline OK either way — `cat` and `[[ ==`  both work).
5. **Mode-conditional dir set:**
   - `learning`: existing dirs (`concepts/`, `chapters/`, `examples/`, `refs/`, `questions/`, `transcripts/`) + `questions/open.md` placeholder.
   - `personal`: only `positions/` and `transcripts/`. Also copy `templates/modes/personal/topic-_profile.md` → `<topic>/_profile.md` with `{{TOPIC_TITLE}}` substitution.
6. **Idempotent vault-root `CLAUDE.md` deploy:** if `<vault>/CLAUDE.md` is missing, copy from `templates/vault-CLAUDE.md`. If it exists, leave it alone (do not unconditionally overwrite, per spec §Migration).

Suggested function decomposition (for clarity, not enforced):

```bash
parse_args()         # parses --mode and slug/title
ensure_vault_root()  # mkdir + idempotent CLAUDE.md deploy
deploy_topic()       # template copy with {{TOPIC_TITLE}} sub
make_dirs_for_mode() # mode-dependent dir layout
```

- [ ] **Step 4: Run tests — must pass**

```bash
./tests/test-new-topic.sh
```

Expected: `Passed: 12  Failed: 0` (4+5+3 ok lines). If any fail, fix and re-run; do not move on with red tests.

- [ ] **Step 5: Manual sanity check against the existing repo**

```bash
TMP=$(mktemp -d); CC_CHAT_VAULT="$TMP" ./scripts/new-topic.sh smoke "Smoke"
ls -la "$TMP/smoke/"
cat "$TMP/smoke/.cc-mode"
rm -rf "$TMP"
```

Expected: full Learning-Mode topic layout, `.cc-mode` contains `learning`. Confirms backward-compat.

- [ ] **Step 6: Commit**

```bash
git add scripts/new-topic.sh tests/test-new-topic.sh
git commit -m "feat(new-topic): add --mode flag, .cc-mode sentinel, mode-conditional layout"
```

## Task 7: Refactor `session-start-context.sh` — extract `build_context_learning`

Pure refactor — no behavioral change. Pulls the existing handoff-building block into a function so Task 8 can add a sibling `build_context_personal`. This isolates risk: if anything breaks here, it shows up before mode-aware logic is layered on.

**Files:**
- Modify: `scripts/session-start-context.sh`

- [ ] **Step 1: Identify the current "build additionalContext" block**

The current script (107 lines) does:
1. Read JSON from stdin → `cwd`.
2. Validate `cwd` is under the vault and contains `_index.md`.
3. Detect "neither consolidated nor _index updated" → set `WARNING`.
4. Read tail-30 lines of `_index.md` → `HANDOFF`.
5. Compose `additionalContext = "## Handoff from _index.md\n\n${HANDOFF}\n\n${WARNING}"`.
6. Print JSON with `additionalContext` and `systemMessage`.

Step 5 (compose) is the block to extract.

- [ ] **Step 2: Add `build_context_learning` function**

Above the main flow, add:

```bash
# Builds the additionalContext payload for Learning Mode.
# Args: $1 = topic_dir, $2 = HANDOFF (already read), $3 = WARNING (may be empty)
# Stdout: the additionalContext string.
# Must reproduce the original layout exactly (including the
# "## 上次整理状态" subheading when warning is non-empty) — this is a
# pure refactor, no behavioral change.
build_context_learning() {
  local topic_dir="$1" handoff="$2" warning="${3:-}"
  printf '## Handoff from _index.md\n\n%s' "$handoff"
  if [[ -n "$warning" ]]; then
    printf '\n\n## 上次整理状态\n\n%s' "$warning"
  fi
}
```

- [ ] **Step 3: Replace the inline composition with a call to the new function**

In the main flow, where `additionalContext` was being built inline, replace with:

```bash
ADDITIONAL_CONTEXT="$(build_context_learning "$TOPIC_DIR" "$HANDOFF" "$WARNING")"
```

(Variable names in caps to match current shell-script style — adjust to whatever the existing script uses.)

- [ ] **Step 4: Run the existing hook against the real `feature-engineering` topic to verify zero behavioral change**

```bash
echo '{"cwd":"'"$HOME"'/Keane/cc-chat/feature-engineering"}' \
  | ./scripts/session-start-context.sh \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("hookSpecificOutput",{}).get("additionalContext","<missing>"))'
```

Expected: same output as before the refactor (the handoff text from `_index.md` tail-30 prefixed with `## Handoff from _index.md`).

If output differs, the refactor introduced a behavior change — fix before continuing.

- [ ] **Step 5: Commit**

```bash
git add scripts/session-start-context.sh
git commit -m "refactor(hook): extract build_context_learning from inline composition"
```

---

## Task 8: TDD — mode-aware `session-start-context.sh`

Adds the `.cc-mode` read, the dispatcher, and `build_context_personal`. Per @superpowers:test-driven-development.

**Files:**
- Modify: `tests/test-session-start-context.sh` (add real test cases)
- Modify: `scripts/session-start-context.sh` (add `read_mode`, dispatcher, `build_context_personal`)

### 8a — Write failing tests

- [ ] **Step 1: Replace `test_placeholder` with these cases**

```bash
# Helper: invoke hook with a fake cwd, return additionalContext text.
# Sets CC_CHAT_VAULT so the hook accepts the temp-dir cwd (the hook's
# vault-root validation otherwise rejects anything outside ~/Keane/cc-chat).
invoke_hook() {
  local cwd="$1"
  local vault
  vault=$(dirname "$cwd")
  echo "{\"cwd\":\"$cwd\"}" | CC_CHAT_VAULT="$vault" "$SCRIPT" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("hookSpecificOutput",{}).get("additionalContext",""), end="")'
}

invoke_hook_sysmsg() {
  local cwd="$1"
  local vault
  vault=$(dirname "$cwd")
  echo "{\"cwd\":\"$cwd\"}" | CC_CHAT_VAULT="$vault" "$SCRIPT" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("systemMessage",""), end="")'
}

# Build a minimal learning-mode topic fixture.
seed_learning_topic() {
  local vault="$1" name="$2"
  local topic="$vault/$name"
  mkdir -p "$topic/transcripts"
  cat > "$topic/_index.md" <<'EOF'
# fixture topic
## handoff
- last consolidated: 2026-05-20
- next: keep going on widget X
EOF
  # No .cc-mode written — exercises the missing-sentinel fallback.
  echo "$topic"
}

# Build a personal-mode topic fixture with profile + positions/foo.
seed_personal_topic() {
  local vault="$1" name="$2"
  local topic="$vault/$name"
  mkdir -p "$topic/transcripts" "$topic/positions"
  echo personal > "$topic/.cc-mode"
  cat > "$topic/_profile.md" <<'EOF'
# Profile fixture
- key trait A
- key trait B
EOF
  cat > "$topic/positions/foo.md" <<'EOF'
# Foo
## 当前立场
fixture stance
EOF
  cat > "$topic/_index.md" <<'EOF'
# fixture
## 焦点子主题
- positions/foo
## 上次结束时的 handoff
keep going
EOF
  echo "$topic"
}

# Test A: missing .cc-mode → treated as learning, output matches pre-change.
test_missing_sentinel_is_learning() {
  local vault topic out
  vault=$(mk_vault)
  topic=$(seed_learning_topic "$vault" "fe")
  out=$(invoke_hook "$topic")
  echo "$out" | grep -q "## Handoff from _index.md" \
    && ok "missing sentinel: handoff header present" \
    || fail "missing sentinel: handoff header absent"
  echo "$out" | grep -q "key trait A" \
    && fail "missing sentinel: leaked _profile content (should NOT)" \
    || ok "missing sentinel: no _profile content"
  rm -rf "$vault"
}

# Test B: .cc-mode=personal → injects _profile and positions/<focus>.
test_personal_injects_profile_and_positions() {
  local vault topic out
  vault=$(mk_vault)
  topic=$(seed_personal_topic "$vault" "personal")
  out=$(invoke_hook "$topic")
  echo "$out" | grep -q "## Handoff from _index.md" \
    && ok "personal: handoff header present" \
    || fail "personal: handoff header absent"
  echo "$out" | grep -q "key trait A" \
    && ok "personal: _profile content injected" \
    || fail "personal: _profile content missing"
  echo "$out" | grep -q "fixture stance" \
    && ok "personal: focus positions content injected" \
    || fail "personal: focus positions content missing"
  rm -rf "$vault"
}

# Test C: invalid .cc-mode value → fallback to learning + systemMessage warning.
test_invalid_sentinel_warns() {
  local vault topic out msg
  vault=$(mk_vault)
  topic=$(seed_learning_topic "$vault" "x")
  echo bogus > "$topic/.cc-mode"
  out=$(invoke_hook "$topic")
  msg=$(invoke_hook_sysmsg "$topic")
  echo "$out" | grep -q "## Handoff from _index.md" \
    && ok "invalid sentinel: still emits handoff (learning fallback)" \
    || fail "invalid sentinel: no handoff emitted"
  echo "$msg" | grep -q ".cc-mode" \
    && ok "invalid sentinel: systemMessage mentions .cc-mode" \
    || fail "invalid sentinel: no warning in systemMessage"
  rm -rf "$vault"
}

# Test D: personal with missing focus positions/<x>.md → still injects profile,
#         systemMessage warns, no crash.
test_personal_missing_focus_file() {
  local vault topic out msg
  vault=$(mk_vault)
  topic=$(seed_personal_topic "$vault" "p")
  rm "$topic/positions/foo.md"
  out=$(invoke_hook "$topic")
  msg=$(invoke_hook_sysmsg "$topic")
  echo "$out" | grep -q "key trait A" \
    && ok "missing focus: _profile still injected" \
    || fail "missing focus: _profile missing"
  echo "$msg$out" | grep -qi "positions/foo\|missing\|焦点" \
    && ok "missing focus: warning surfaced somewhere" \
    || fail "missing focus: silent — should warn"
  rm -rf "$vault"
}

test_missing_sentinel_is_learning
test_personal_injects_profile_and_positions
test_invalid_sentinel_warns
test_personal_missing_focus_file
```

- [ ] **Step 2: Run — must fail**

```bash
./tests/test-session-start-context.sh
```

Expected: tests B, C, D fail (the script doesn't yet read `.cc-mode` or inject `_profile`/`positions`). Test A may pass if the refactor in Task 7 was clean.

### 8b — Implement

- [ ] **Step 3: Add `read_mode` helper**

```bash
# Reads <topic>/.cc-mode. Echoes the trimmed mode name.
# Echoes "learning" if the file is missing.
# Echoes "learning" + emits a warning to stderr if value is unknown.
# Args: $1 = topic_dir
# Stdout: mode name (always one of: learning, personal)
# Stderr (optional): a warning suitable for prepending to systemMessage
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
```

- [ ] **Step 4: Add `build_context_personal`**

```bash
# Builds the additionalContext for Personal Mode.
# Injects: _index handoff (tail-30) + _profile.md (full) + positions/<focus>.md (full).
# Args: $1 = topic_dir, $2 = HANDOFF, $3 = WARNING
# Stdout: additionalContext string.
# May echo extra warnings to stderr if focus file is missing.
build_context_personal() {
  local topic_dir="$1" handoff="$2" warning="${3:-}"
  printf '## Handoff from _index.md\n\n%s\n' "$handoff"
  if [[ -n "$warning" ]]; then
    printf '\n%s\n' "$warning"
  fi
  if [[ -f "$topic_dir/_profile.md" ]]; then
    printf '\n## _profile.md\n\n'
    cat "$topic_dir/_profile.md"
  fi
  # Find first "- positions/<name>" under "## 焦点子主题".
  local focus
  focus=$(awk '
    /^## 焦点子主题/ { in_focus=1; next }
    in_focus && /^## / { exit }
    in_focus && /^- positions\// {
      sub(/^- positions\//, ""); sub(/[[:space:]]+$/, "");
      sub(/\.md$/, "");
      print; exit
    }
  ' "$topic_dir/_index.md")
  if [[ -n "$focus" ]]; then
    local fp="$topic_dir/positions/$focus.md"
    if [[ -f "$fp" ]]; then
      printf '\n## positions/%s.md (focus)\n\n' "$focus"
      cat "$fp"
    else
      echo "WARN_MISSING_FOCUS=positions/$focus.md" >&2
    fi
  fi
}
```

- [ ] **Step 5: Wire dispatcher into the main flow**

```bash
MODE=$(read_mode "$TOPIC_DIR" 2> >(MODE_WARN=$(cat); export MODE_WARN))
# Or, more portable:
MODE_WARN_FILE=$(mktemp)
MODE=$(read_mode "$TOPIC_DIR" 2>"$MODE_WARN_FILE")
MODE_WARN=$(cat "$MODE_WARN_FILE"); rm -f "$MODE_WARN_FILE"

CTX_WARN_FILE=$(mktemp)
case "$MODE" in
  learning) ADDITIONAL_CONTEXT="$(build_context_learning "$TOPIC_DIR" "$HANDOFF" "$WARNING" 2>"$CTX_WARN_FILE")" ;;
  personal) ADDITIONAL_CONTEXT="$(build_context_personal "$TOPIC_DIR" "$HANDOFF" "$WARNING" 2>"$CTX_WARN_FILE")" ;;
esac
CTX_WARN=$(cat "$CTX_WARN_FILE"); rm -f "$CTX_WARN_FILE"
```

Then build `SYSTEM_MESSAGE` to include the existing topic-name marker plus, conditionally:
- if `MODE_WARN` matches `WARN_INVALID_MODE=<x>` → append `⚠ .cc-mode 值无效（"<x>"），按 learning 处理`
- if `CTX_WARN` matches `WARN_MISSING_FOCUS=<path>` → append `⚠ 焦点文件不存在: <path>`

- [ ] **Step 6: Run tests — must pass**

```bash
./tests/test-session-start-context.sh
```

Expected: all 8+ assertions ok. Re-run Test A's pre-change parity check to confirm `feature-engineering` still works (Step 4 of Task 7).

- [ ] **Step 7: Commit**

```bash
git add scripts/session-start-context.sh tests/test-session-start-context.sh
git commit -m "feat(hook): mode-aware SessionStart — read .cc-mode, inject _profile + focus positions"
```

## Task 9: Delete moved templates and update `docs/conventions.md`

The old top-level `templates/topic-_map.md` and `templates/topic-_index.md` were renamed by `git mv` in Task 1, so git already tracks them as moves — no extra deletion needed. This task verifies that's true and updates documentation.

**Files:**
- Verify (no change): `templates/topic-_map.md` and `templates/topic-_index.md` are gone from working tree
- Modify: `docs/conventions.md`

- [ ] **Step 1: Verify the old templates are gone**

```bash
ls templates/topic-_map.md templates/topic-_index.md 2>&1
```

Expected: `No such file or directory` for both. If either still exists, something undid the rename — re-do the `git mv` in Task 1.

- [ ] **Step 2: Update `docs/conventions.md`**

Add a section near the top covering:

1. **Multi-mode** — vault now supports multiple modes; each topic declares its mode via a single-line `.cc-mode` file at its root.
2. **Available modes** — `learning` (default), `personal`.
3. **`new-topic.sh --mode <name>`** — flag-based selection at creation time. Mode is fixed once chosen; switching modes requires creating a new topic.
4. **Per-topic `CLAUDE.md`** — every topic now carries its own `CLAUDE.md`, deployed from `templates/modes/<mode>/CLAUDE.md`. The vault-root `CLAUDE.md` is a signpost only.
5. **Rule 0** — both modes carry an identical Rule 0 (objectivity, no flattery, default-challenge) at the top of their `CLAUDE.md`. Cross-mode top-priority rule.
6. **Migration note** — point to Task 11 of this plan / the spec's §Migration & Regression for the one-time migration of `feature-engineering`.

Use existing conventions.md style and section ordering.

- [ ] **Step 3: Commit**

```bash
git add docs/conventions.md
git commit -m "docs(conventions): document multi-mode vault, --mode flag, per-topic CLAUDE.md"
```

---

## Task 10: End-to-end verification gate

Per @superpowers:verification-before-completion: nothing is "done" until the full suite passes. This task gates merge.

**Files:** none (read-only checks)

- [ ] **Step 1: Run both test drivers**

```bash
./tests/test-new-topic.sh
./tests/test-session-start-context.sh
```

Expected: both exit 0 with `Failed: 0`.

- [ ] **Step 2: Real-vault parity check (Learning Mode no-regression)**

```bash
echo '{"cwd":"'"$HOME"'/Keane/cc-chat/feature-engineering"}' \
  | ./scripts/session-start-context.sh
```

Expected: same JSON output structure as before any changes — `additionalContext` contains `## Handoff from _index.md` followed by the tail of the topic's `_index.md`. **No** `_profile.md` content. **No** `_index` mode-related warnings.

This works because `feature-engineering` does NOT yet have a `.cc-mode` file (migration Task 11 happens after merge), and the missing-sentinel fallback treats it as `learning`.

- [ ] **Step 3: Fresh-install spot check**

```bash
TMP=$(mktemp -d)
CC_CHAT_VAULT="$TMP" ./scripts/new-topic.sh --mode personal personal "Personal"
ls "$TMP/personal/"
cat "$TMP/personal/.cc-mode"
[[ -f "$TMP/CLAUDE.md" ]] && echo "vault signpost deployed (fresh-install path)"
rm -rf "$TMP"
```

Expected: `_profile.md`, `_map.md`, `_index.md`, `CLAUDE.md`, `.cc-mode` (=personal), `positions/`, `transcripts/` present; `concepts/`/`chapters/`/`examples/`/`refs/`/`questions/` absent; vault-root `CLAUDE.md` deployed.

- [ ] **Step 4: Bash lint (best-effort, optional)**

```bash
shellcheck scripts/new-topic.sh scripts/session-start-context.sh tests/test-*.sh 2>/dev/null || \
  echo "shellcheck not installed — skipping (optional)"
```

If shellcheck is installed and reports issues, fix them. If not installed, this is a non-blocking step.

- [ ] **Step 5: Sanity-check uncommitted state**

```bash
git status
git log --oneline -10
```

Expected: clean working tree (all task commits landed); the most recent ~9 commits should match Tasks 1–9 in order.

- [ ] **Step 6: Mark verification done**

No commit at this step. Verification confirms the work is mergeable; merging itself is a separate user action governed by @superpowers:finishing-a-development-branch.

---

## Task 11: Migration runbook (post-merge, executed by user, NOT by the implementer)

This task is **documentation only inside this plan**. The implementer must NOT execute these commands against `~/Keane/cc-chat/` from inside the worktree — they touch live user data.

The user runs these once after merging the branch to `main` and pulling locally.

**Steps the user runs (not the implementer):**

```bash
# 1. Mark the existing topic as Learning Mode.
echo learning > ~/Keane/cc-chat/feature-engineering/.cc-mode

# 2. Replace vault-root CLAUDE.md with the new signpost.
cp templates/vault-CLAUDE.md ~/Keane/cc-chat/CLAUDE.md

# 3. Deploy the per-topic CLAUDE.md to feature-engineering.
cp templates/modes/learning/CLAUDE.md \
   ~/Keane/cc-chat/feature-engineering/CLAUDE.md
```

**Regression checks the user runs after migration** (matches spec §Migration & Regression checklist):

```bash
# 4. Start CC inside feature-engineering.
cd ~/Keane/cc-chat/feature-engineering
claude
```

Inside the session, verify:
1. `SessionStart` `systemMessage` shows `📌 cc-chat: 已注入 [feature-engineering] handoff (... 行)`. `additionalContext` contains the existing `_index.md` tail. No `_profile.md` content.
2. `CLAUDE.md` rules are intact: 详细优先 / 对比双向展开 / 段尾自检 / auto-write triggers / `/consolidate` protocol all present. **Rule 0 is new and intentional** — visible at the top of `CLAUDE.md`.
3. `SessionEnd` archives transcripts to `feature-engineering/transcripts/` as both `.jsonl` and `.md`.
4. Running `/consolidate` writes to `concepts/`, updates `_map.md`, appends `questions/open.md`.

**Creating the first Personal topic** (when the user is ready):

```bash
cd ~/git/cc-chat
./scripts/new-topic.sh --mode personal personal "Personal"
# Hand-write the seed for ~/Keane/cc-chat/personal/_profile.md before first session.
```

---

## Dependency Graph

```
Task 1 (move learning templates)
  └─> Task 2 (rewrite vault signpost)
  └─> Task 3 (Rule 0 → learning CLAUDE.md)
  └─> Task 4 (personal templates)
        ├─ shares Rule 0 text with Task 3 (verify identical)
  └─> Task 5 (test scaffolding)
        └─> Task 6 (TDD new-topic.sh)
              └─> Task 7 (refactor hook)
                    └─> Task 8 (TDD mode-aware hook)
                          └─> Task 9 (docs + delete-stragglers)
                                └─> Task 10 (verification gate)
                                      └─> Task 11 (user-side migration runbook — NOT auto-run)
```

Tasks 2, 3, 4 are independent of each other after Task 1 — could parallelize if desired, but serial is fine for this small project.

---

## Post-Plan

When all 10 in-repo tasks are green and Task 10's verification passes:

1. The implementer hands the branch off using @superpowers:finishing-a-development-branch.
2. The user merges, pulls locally, then runs Task 11 against `~/Keane/cc-chat/` once.
3. The user creates the first Personal topic with `./scripts/new-topic.sh --mode personal personal "Personal"`, hand-writes the `_profile.md` seed, and starts using it.

Future modes (decision / research / incubation) follow this same plan shape: add `templates/modes/<mode>/`, add a `build_context_<mode>` branch in the hook, add test cases, document. No further infrastructure changes anticipated.
