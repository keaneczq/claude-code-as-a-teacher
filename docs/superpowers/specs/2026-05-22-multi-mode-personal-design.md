# Multi-Mode Vault: Personal Mode + Mode 抽象

- **Date**: 2026-05-22
- **Status**: Design (awaiting user review)
- **Scope**: Extend cc-chat from a single-mode (Learning) vault to a multi-mode vault, with Personal Mode as the first non-learning mode. Establish a mode-abstraction so that future modes (Decision, Research, Incubation) can be added by replicating the same shape.

## Problem

cc-chat currently supports exactly one kind of long-running conversation — Learning Mode — whose conventions are hard-coded in `templates/vault-CLAUDE.md`. The user is satisfied with how it works but wants to extend the system to other kinds of deep, persistent dialogue (decisions, research, incubation, and most pressingly, a "personal" space for things like personality/life questions, parenting, worldview, personal affairs).

The infrastructure underneath Learning Mode — `SessionStart` handoff injection, `SessionEnd` transcript archival, the `_index.md` / `_map.md` pattern, the `/consolidate` protocol, the token-discipline conventions — is mode-agnostic in spirit, but currently coupled to learning-specific artifacts (`concepts/`, `chapters/`, `examples/`). Re-using it for other dialogue kinds requires factoring out the mode dimension.

The first non-learning mode chosen is **Personal Mode**, because among the four candidates (decision, research, incubation, personal) it has the largest structural distance from Learning Mode. If the abstraction holds for Personal, the remaining three modes can be added later as straightforward replications.

## Goals

1. Introduce a **mode abstraction** so that each topic in the vault declares which mode it runs under, and the existing infrastructure routes behavior by mode.
2. Implement **Personal Mode** end-to-end: artifact structure, hook injection behavior, `/consolidate` semantics, mode-specific `CLAUDE.md` rules.
3. Establish **Rule 0** (objectivity, no flattery, default-challenge-not-default-advance) as a cross-mode top-priority rule, applied to both Personal Mode and the existing Learning Mode.
4. Migrate the existing `feature-engineering` topic onto the new architecture with **zero behavioral regression** — Learning Mode users should not notice any change apart from Rule 0.
5. Keep the abstraction **lean** — exactly the shape needed for two modes today, leaving the door open for the next three without over-engineering.

## Non-Goals

- Implementing decision / research / incubation modes. They are out of scope for this spec; their addition is expected to be a copy-and-tune exercise once Personal Mode validates the abstraction.
- A pluggable "mode framework" with mode-specific hook implementations or skill bundles. Current behavioral divergence is content-level (what gets injected, what artifacts exist, what `/consolidate` writes), not infrastructure-level. Promotion to plugin-grade is deferred until ≥3 modes exist with genuine infrastructure divergence.
- Switching a topic between modes after creation. A topic's mode is fixed at creation time. To "switch", create a new topic and migrate content manually.
- Encryption, privacy partitioning, or any access control beyond what the local filesystem and the user's existing private Obsidian-git repo provide.
- A user-facing command to interrogate Rule 0 compliance (e.g., `/check-flattery`). The user can always say "be harder on me / don't accommodate" — that is the lighter, sufficient interface.

## Architecture: Mode Abstraction

### Sentinel-based mode declaration

Every topic directory in the vault carries a single-line text file `.cc-mode` at its root, whose content is the mode name (`learning` | `personal`). This sentinel is the single source of truth for mode routing.

Why a sentinel file:

- A single 1-line read per `SessionStart` hook invocation; no parsing needed.
- Robust against user editing of `_index.md` (which a frontmatter-based scheme would not be).
- Avoids breaking existing vault paths (which a directory-based scheme like `vault/learning/<topic>/` would force).

A missing `.cc-mode` is treated as `learning` for backward compatibility — see [Migration](#migration--regression).

### Per-topic `CLAUDE.md`

Each topic directory contains its own `CLAUDE.md`, deployed from `templates/modes/<mode>/CLAUDE.md` at topic creation time. The vault-root `CLAUDE.md` becomes a minimal "signpost" that instructs the user to `cd` into a specific topic before starting CC.

This is the largest structural change versus the current setup (where a single vault-root `CLAUDE.md` carries Learning Mode rules). It is necessary because Personal Mode and Learning Mode rules are mutually inappropriate when applied to the wrong kind of topic — they cannot share a single file.

CC's normal cwd-based `CLAUDE.md` discovery loads the per-topic file automatically when the user runs `claude` from inside the topic directory, which is already the documented entry path (`docs/conventions.md`).

**Vault-root signpost content** (the new `templates/vault-CLAUDE.md`, deployed once to `~/Keane/cc-chat/CLAUDE.md`):

```markdown
# cc-chat vault

这里是多 topic / 多 mode 的根目录，不直接承载任何 topic 的对话规则。

请进入具体 topic 目录后再启动 Claude Code：

    cd ~/Keane/cc-chat/<topic-slug>
    claude

每个 topic 目录有自己的 `CLAUDE.md` 和 `.cc-mode`，决定该 topic 的运行模式。
新建 topic：在仓库目录运行 `./scripts/new-topic.sh [--mode learning|personal] <slug> [title]`。
```

### Repository layout changes

```
templates/
├── modes/
│   ├── learning/
│   │   ├── CLAUDE.md          # moved from templates/vault-CLAUDE.md, + Rule 0 prepended
│   │   ├── topic-_map.md      # moved from templates/topic-_map.md
│   │   └── topic-_index.md    # moved from templates/topic-_index.md
│   └── personal/
│       ├── CLAUDE.md          # new — Personal Mode rules + Rule 0
│       ├── topic-_map.md      # new — subtopic-list-with-status shape
│       ├── topic-_index.md    # new — adds "焦点子主题" anchor
│       └── topic-_profile.md  # new — Personal Mode only
└── vault-CLAUDE.md             # rewritten as a 4–6-line signpost
```

The old top-level `templates/topic-_map.md` and `templates/topic-_index.md` are deleted after their content moves to `templates/modes/learning/`. No compatibility shim — `new-topic.sh` always reads from `templates/modes/<mode>/`.

### `new-topic.sh` change

```
./scripts/new-topic.sh [--mode learning|personal] <slug> [title]
```

- `--mode` defaults to `learning` for backward compatibility.
- Validates `--mode` value against the known set; rejects unknown values.
- Copies `templates/modes/<mode>/CLAUDE.md` → `<topic>/CLAUDE.md`.
- Copies `templates/modes/<mode>/topic-_map.md` → `<topic>/_map.md` (with `{{TOPIC_TITLE}}` substitution).
- Copies `templates/modes/<mode>/topic-_index.md` → `<topic>/_index.md` (same).
- For `personal`: also copies `templates/modes/personal/topic-_profile.md` → `<topic>/_profile.md` (with `{{TOPIC_TITLE}}` substitution).
- Writes the mode name into `<topic>/.cc-mode`.
- Creates only the directories the mode needs:
  - `learning`: `concepts/`, `chapters/`, `examples/`, `refs/`, `questions/`, `transcripts/` + `questions/open.md` placeholder (current behavior).
  - `personal`: `positions/`, `transcripts/`. No empty `concepts/`/`chapters/`/`examples/`/`refs/`/`questions/`.

Vault-root `CLAUDE.md` is no longer unconditionally redeployed by `new-topic.sh` — it is set up once during migration (see below). The script does deploy it from `templates/vault-CLAUDE.md` if it is missing (fresh-install fallback, see the bullet list above).

## Architecture: Rule 0 — Objectivity, No Flattery

Rule 0 is a cross-mode top-priority rule applied to **every mode's `CLAUDE.md`**. It is placed at the very top of the file, above all other rules, with an explicit declaration that it overrides everything else in the same file.

### Why Rule 0 spans modes (not Personal-only)

The user's reasoning: in Learning Mode the dialogue's subject matter is largely objective (math, code, data), so the flattery-temptation rarely triggers. But the temptation is identical in nature — when it does trigger (e.g., the user proposes an incorrect approach with confidence), the LLM should challenge before advancing. So Learning Mode benefits from the same rule even though it sees less use of it.

Currently the rule lives in two copies (one per mode's `CLAUDE.md`). Promotion to a shared file (e.g., `templates/modes/_shared/rule-zero.md`) is deferred until ≥3 modes exist and copy-drift becomes a problem.

### Rule 0 text

```markdown
## Rule 0：客观，不迎合（高于本文件其他所有规则）

你的首要职责是说真话，不是让用户感觉良好。当客观分析与用户的
情绪/偏好/期待冲突时，永远选客观——即使这带来痛苦、即使被推回。
无条件。

### 0.1 不迎合情绪

禁止：
- "你说得对" —— 除非你真的检查了证据并同意
- "你完全有理由这么感觉" —— 情绪有真实性，但情绪不是事实判断的依据
- "两边都有道理" —— 除非你真的判断证据均衡，否则不要用它来回避站队
- 软化结论以照顾感受 —— 判断是 A，就说 A，不要包装成"也许 A 也许 B"
- 用户推回时立刻让步 —— 除非用户给出了之前没考虑过的新证据/角度
- 默认接受用户对自己/他人的描述 —— 尤其当用户在描述冲突且把对方
  框定为错的一方时，必须主动想一步另一方视角

### 0.2 默认挑战，不默认推进

用户提出方案 / 想法 / 观点 / 判断时，**默认动作是先挑战，而不是
顺着展开**。只有在你检查证据、想过反例之后，**真正认同**，才往
下推进。

具体地：
- 用户说"我觉得 X" → 你先问自己：X 站得住吗？反例是什么？前提
  是否成立？有没有更解释力的替代解释？再决定回复内容。
- 不要因为用户表达自信就接受。"我已经想过了"、"很明显"、"显然"
  不是论据。
- 不要因为继续对话省事就推进。如果你心里其实有疑虑却让对话往下
  跑，等价于迎合。
- 反过来：如果你检查后认同，就直接接着推，不要为了"显得在思考"
  人为制造质疑——伪挑战和迎合一样有害。
- 表达质疑时直接说："这里我不同意，因为……"、"这个前提我想先
  问一下"，不要用"也许可以再想想"、"角度很有意思"这种软化层。

### 0.3 高警惕场景（出现时停一下、自检一遍再回）

- 用户表达强烈情绪（受伤、愤怒、恐惧、防御）
- 引导性问句寻求认同（"你不觉得……吗"、"我这样想没错吧"）
- 用户对自己有强烈的本质化描述（"我就是这种人"）
- 用户描述与他人的冲突，且把对方框定为错的一方
- 用户对你上一句话不满
- 用户提出方案/判断时表达高确定性（"显然"、"肯定"、"毫无疑问"）

### 0.4 自检问句（生成回答前问自己一遍）

- "我下面要说的这句话，是因为证据支持它，还是因为用户想听到它？"
- "用户刚才提的观点/方案，我真的认同吗？还是只是没异议？没异议
  和认同不是一回事——前者要继续追问，后者才能往下推。"

### 0.5 落档时

写 positions/、回写 _profile.md、更新 _map.md、写 concepts/ 时：
写你（基于这次对话证据）真正判断的当前观点，不是用户最希望
被记录的版本。如果你和用户在某点上有分歧，把分歧本身记下来，
不要抹平它。
```

### Why this is expected to bind LLM behavior

1. **Position equals priority** — Rule 0 sits at the top of `CLAUDE.md` with explicit precedence, so it is the first thing loaded and the rule that wins on conflict.
2. **Concrete prohibited phrases** — 0.1's list of banned sentence templates is what the LLM actually generates; recognizing them before emission is more tractable than internalizing an abstract principle.
3. **Trigger-scenario list** — 0.3 names situations where flattery-pressure spikes, letting the LLM raise its self-check level at exactly those moments.
4. **Pre-generation self-check** — 0.4 phrases the rule as a one-line question the LLM can run silently before each response, more operational than abstract guidance.
5. **Coverage extends to consolidation** — 0.5 keeps the rule active when writing files, preventing the "tough in dialogue, soft in archive" failure mode.

## Personal Mode: Artifact Structure

### Directory layout

```
~/Keane/cc-chat/personal/
├── CLAUDE.md              # Personal Mode rules + Rule 0 (deployed at create time)
├── .cc-mode               # single line: personal
├── _profile.md            # who-you-are; loaded across all subtopics
├── _map.md                # subtopic list with status
├── _index.md              # this session's focus
├── positions/             # one file per subtopic — synthesized current stance
│   ├── parenting.md
│   ├── worldview.md
│   └── ...
└── transcripts/           # archived by existing SessionEnd hook (jsonl + md)
```

Personal Mode does **not** use the Learning Mode artifacts: `concepts/`, `chapters/`, `examples/`, `refs/`, `questions/open.md`. These are knowledge-building artifacts; Personal Mode produces stance-evolution artifacts.

### `_profile.md` — cross-subtopic identity

**Purpose**: Let the LLM know who the user is from the first turn of every session, so that advice across subtopics (parenting, worldview, life decisions) is grounded in the user's stable identity rather than being re-bootstrapped each time.

**Content scope** (input-side context, used to inform discussion across all subtopics):

- Key life experiences (education / career / family / inflection points)
- Value commitments (one-line each; argumentation lives in `positions/worldview.md`)
- Key relationships (family, people whose views materially affect the user's decisions)
- Personality / cognitive tendencies (self-reported and LLM-observed, marked separately)
- Current life-state snapshot (work, city, health, financial outline — only at the granularity needed for advice)

**Out of scope here**:

- Stance on a specific subtopic → that goes in `positions/<subtopic>.md`.
- One-off events or emotions → those live in transcripts.

**Write discipline**:

- User writes by hand. The user owns this file.
- LLM may **propose** additions during `/consolidate` when it observes information that is (a) referenced repeatedly across subtopics and (b) stable. The LLM **must ask** before writing — never auto-append. (See [/consolidate](#consolidate-in-personal-mode).)
- Soft cap ~3k tokens. When exceeded, the LLM raises this in the next session and proposes compaction or splitting. The cap is enforced by the LLM in-session, not by the hook (see [Hook Changes](#hook-changes-mode-aware-session-start-contextsh)).
- Use dense bulleted lists, not prose.

**Initial template scaffolding** (`templates/modes/personal/topic-_profile.md`): the seed file ships with the section headings from "Content scope" above as empty placeholders, plus a one-line instruction at the top reminding the user that this is a hand-written seed. Concretely:

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

**Rule 0 application**: When the LLM writes back to `_profile.md`, it records what it actually observed in the conversation, not what the user prefers to be recorded as. If the user self-describes one way but conversation evidence diverges, the LLM notes the divergence rather than smoothing it.

### `positions/<subtopic>.md` — current stance, evolution trail

**Purpose**: For each subtopic, hold a synthesized "current stance + how it got here + pointers to source dialogues". This is the primary entry point three months later.

**Structure**:

```markdown
# <Subtopic Title>

## 当前立场（最后更新：YYYY-MM-DD）
<LLM-synthesized current judgment / view / advice. Rule 0 applies — write
the real judgment, not the version the user wants to read. If there is
disagreement, record the disagreement explicitly.>

## 仍在演化 / 未定
<Unresolved aspects. Convergence is not required — Personal Mode content
often shouldn't be force-closed.>

## 演化轨迹
- YYYY-MM-DD: <earlier stance> → 因为 <trigger> 改为 <current stance>
- YYYY-MM-DD: ...

## 相关 transcript
- [[transcripts/20260518-abc12345]] — short note on what this session covered
- ...

## 与 _profile 的接口
<Stable identity-level information surfaced in this subtopic that may be
worth lifting to _profile.md. LLM proposes; user decides.>
```

**Write discipline**:

- A subtopic file is created the first time the user clearly enters that topic. The LLM proposes the filename; user can rename or veto.
- `当前立场` is **rewritten** (not appended) each `/consolidate`; the previous version moves into `演化轨迹`.
- If the LLM wants to change `当前立场` but the user disagrees: keep the user's version in `当前立场`, record the disagreement in `演化轨迹`. Never smooth a disagreement.
- Soft cap ~5k tokens per file. When exceeded, propose splitting or distilling.

### `_map.md` — subtopic navigation

Learning Mode's `已掌握 / 进行中 / 待开始` does not apply — Personal Mode subtopics have no notion of "completed".

```markdown
# Personal — Subtopics

## 活跃
- [[positions/parenting]] — 当前主要在想：要不要换学校 / 上次活跃 2026-05-18
- [[positions/worldview]] — 自由意志相关讨论 / 上次活跃 2026-05-12

## 沉睡（>30 天未碰）
- [[positions/career-direction]] — 暂时不动 / 上次活跃 2026-03-02

## 想开但还没开
- 退休规划
- 父母赡养
```

"Sleeping" is not "done"; it just means out of view. The user can pull anything back into 活跃 at any time. Promotion between sections happens at `/consolidate`.

### `_index.md` — this session's focus

```markdown
# Personal — Current Focus

## 今天打算搞什么
<one line>

## 焦点子主题
- positions/parenting   # ← hook reads this line and injects the file

## 上次结束时的 handoff
<one or two lines from last /consolidate>
```

The `焦点子主题` section is the **contract** between `_index.md` and the SessionStart hook. The hook reads the first `- positions/<name>` entry under that heading and injects the corresponding file. Additional entries (if present) are loaded by the LLM on demand within the session.

### Transcripts: semantic upgrade

Learning Mode's "default: do not load `transcripts/`" rule **does not apply** in Personal Mode. The user has stated that the full Q&A record itself is valuable and will be re-read.

Revised rule for Personal Mode:

- Hook still does not auto-inject transcript files (token protection).
- When the user says "look back at last session" or "find that conversation about X", the LLM directly reads the rendered `.md` transcript.
- `相关 transcript` links inside `positions/*.md` are the indexed entry points.

### Skills policy in Personal Mode

Learning Mode's `CLAUDE.md` carries an explicit skills allowlist/blocklist (see current `templates/vault-CLAUDE.md` "Skills Policy" section). Personal Mode reuses the same blocklist almost wholesale — neither mode is a code/UI workflow — with these adjustments to the **useful** list:

- `superpowers:brainstorming` — useful, same as Learning. When the user enters a new subtopic area and is still framing it, brainstorming applies before stance synthesis begins.
- `superpowers:systematic-debugging` — **drop**. No code in Personal Mode.
- `document-skills:doc-coauthoring` — useful, same as Learning. Occasionally helpful for refining `_profile.md` or a major `positions/<x>.md` rewrite when the user explicitly asks.
- `matplotx-styling` — **drop**. No plots.

The blocklist is identical to Learning Mode's: `simplify`, all `superpowers:test-driven-development` / `verification-before-completion` / `requesting-code-review` / `receiving-code-review` / `writing-plans` / `executing-plans` / `subagent-driven-development` / `finishing-a-development-branch` / `using-git-worktrees`, and all UI/frontend skills.

Implementation: the Personal Mode `CLAUDE.md` carries a "Skills Policy in Personal Mode" section structurally parallel to Learning Mode's, with the adjustments above. When this spec is implemented, the implementer copies Learning Mode's section and applies the deltas — no further design needed.

### Deliberate omissions (YAGNI)

- No `questions/open.md` — the user has stated open threads are not the focus; tracking them would create a parallel "in-flight" record that competes with `仍在演化` inside `positions/`.
- No psychology-mode-only files (mood logs, trigger lists). The current-stance + evolution-trail format covers it; specialization can be added later if a stable need emerges.
- No encryption / privacy tiering. Vault is local + already inside the user's private Obsidian-git repo.

## Hook Changes: Mode-Aware `session-start-context.sh`

### Scope

Only `scripts/session-start-context.sh` is modified. `export-transcript.sh`, `render-transcript.py`, and `install-hooks.sh` remain unchanged — transcript archival is mode-agnostic.

### Current logic (summarized)

1. Read stdin JSON → extract `cwd`.
2. Validate `cwd` is under the vault and contains `_index.md`; otherwise exit silently.
3. Detect whether the last session was `/consolidate`-d, and whether `_index.md` was updated since; if neither → produce a `WARNING`.
4. Read tail-30 of `_index.md` as `handoff`.
5. Emit JSON with `additionalContext = "## Handoff from _index.md\n\n<handoff>" + optional WARNING` and `systemMessage`.

### Revised logic

```
1-3. unchanged
4. Read .cc-mode to determine mode (missing → "learning"; invalid → "learning"
   plus a warning appended to systemMessage).
5. Build additionalContext per mode:
   - learning  → tail-30 of _index.md  (+ WARNING if any)
   - personal  → tail-30 of _index.md  (+ WARNING if any)
                 + full _profile.md
                 + the positions/<focus>.md file pointed to by the first
                   "- positions/<name>" line under "## 焦点子主题" in _index.md
6. Emit (unchanged shape).
```

### Key design choices

**Why Personal Mode auto-injects `_profile.md` in full**: The user's stated need is "feel like the LLM already knows me at session start". The `_profile.md` size cap (~3k tokens, see Section 3) is set explicitly so that whole-file injection is safe. If the file ever exceeds the cap, the LLM (in-session) will surface the issue; the hook itself does no truncation — hooks must remain content-policy-free.

**Why Personal Mode auto-injects the focus subtopic's `positions/<x>.md`**: Removes the need for the LLM to issue a `Read` call as its first action, which would also bloat the transcript and delay the first useful turn. The contract is `_index.md` → `## 焦点子主题` → first `- positions/<name>` line.

**Focus-subtopic parsing**: Find the line `## 焦点子主题`. Among the immediately following `- positions/<name>` lines, take the first one. Resolve to `<topic>/positions/<name>.md` (with or without the `.md` suffix). If the file is missing, log a warning to `systemMessage` and skip — do not fail the session.

**Missing `.cc-mode` fallback**: Treat as `learning`. This is the safety net for the existing `feature-engineering` topic and any topic created without `--mode`. The fallback is **soft net, not replacement** — explicit migration writes the sentinel, see [Migration](#migration--regression).

**Invalid `.cc-mode` value (neither `learning` nor `personal`)**: Treat as `learning` plus prepend a one-line warning to `systemMessage`: `⚠ .cc-mode 值无效（"<x>"），按 learning 处理`. Surfacing the warning is what makes this fallback discoverable; otherwise misconfiguration would be silently masked.

### Token budget (Personal Mode session start)

| Source                                 | Cap      | Notes                                                    |
| -------------------------------------- | -------- | -------------------------------------------------------- |
| `CLAUDE.md` (per topic)                | ~3k      | Loaded by CC's normal cwd-based discovery, not by hook   |
| `_profile.md`                          | ~3k      | Soft cap; LLM proposes compaction in-session if exceeded |
| `positions/<focus>.md`                 | ~5k      | Soft cap; LLM proposes split in-session if exceeded      |
| `_index.md` handoff (tail 30 lines)    | ~0.5k    | Same as Learning Mode                                    |
| Optional WARNING / mode-invalid notice | <0.1k    |                                                          |
| **Total at session start**             | **~12k** | Same order of magnitude as Learning Mode's 10–15k target |

### Implementation note

Current `session-start-context.sh` is 107 lines. Estimated post-change: ~150 lines, broken into `build_context_learning` and `build_context_personal` functions with a small dispatcher in `main`. The added complexity is local: read `.cc-mode`, branch, optionally read two more files, concatenate.

### Verification

Manual fixture-based test, no test framework needed:

- Fixture A: `feature-engineering/` (no `.cc-mode`) → expect Learning behavior, `additionalContext` matches current output exactly.
- Fixture B: a fresh `personal/` topic with valid `.cc-mode=personal`, populated `_profile.md`, populated `positions/foo.md`, and `_index.md` pointing focus to `foo` → expect injected context to include all three.
- Fixture C: a topic with `.cc-mode=garbage` → expect Learning fallback plus `systemMessage` warning.
- Fixture D: Personal topic with `_index.md` pointing focus to a non-existent `positions/missing` → expect `_profile.md` still injected, no `positions` content, `systemMessage` warning.

## `/consolidate` in Personal Mode

Learning Mode's `/consolidate` synthesizes knowledge — updating `concepts/`, migrating `_map.md` status, appending `questions/open.md`. Personal Mode reuses the same skeleton but writes different artifacts and adds a profile-write-back gate.

### The five steps

```
1. Re-read this session, group by subtopic.
   (Personal Mode sessions cross subtopic boundaries more often than
   Learning Mode sessions cross concept boundaries — explicit grouping
   is required, not optional.)

2. For each subtopic touched in this session:
   - If positions/<x>.md does not exist → propose creation
     (filename, title); user confirms or renames before writing.
   - Rewrite "当前立场" based on this session's evidence,
     applying Rule 0.
   - If "当前立场" changed, move the previous version into
     "演化轨迹" with date and trigger.
   - Update "仍在演化 / 未定" with newly surfaced unresolved items.
   - Append the to-be-archived transcript filename to "相关 transcript".

3. Scan the whole session for stable identity-level information that
   may belong in _profile.md.
   - DO NOT write _profile.md directly.
   - Surface the candidates to the user:
     "I'd suggest adding these to _profile. Which ones? (y/n/edit each)"
   - Write only after the user decides per item.

4. Update _map.md:
   - Subtopics touched this session → "活跃", refresh "上次活跃" date.
   - "活跃" subtopics not touched in 30+ days → "沉睡".
   - Newly created subtopics → "活跃".
   - No "已完成" — Personal Mode has no completion state.

5. Update _index.md handoff:
   - Next-session focus candidates (LLM proposes if user did not
     specify).
   - One or two lines on the most worth-continuing thread from this
     session.
```

### Differences from Learning Mode `/consolidate`

1. **Multi-subtopic grouping is the default.** LM assumes one branch per session; Personal assumes multiple subtopics per session. Step 1 makes the grouping explicit.
2. **`_profile.md` write-back has a user-approval gate.** LM's `concepts/` are LLM-primary, user-supplemental; Personal's `_profile.md` is user-primary, LLM-proposing. The user has final editorial control over their own portrait — this is Rule 0's extension to the archival side.
3. **No silent stance edits.** A change to `当前立场` requires a corresponding entry in `演化轨迹` recording why it changed. If the LLM rewrites `当前立场` without adding a 演化轨迹 line, that erases disagreement and violates Rule 0.5.
4. **No `questions/open` updates.** Personal Mode does not track open threads as a separate artifact.

### Implicit `/consolidate` trigger

Inherited from Learning Mode unchanged: when the LLM offers branch options ("we could go A or B next") and the user picks one, that selection is itself the implicit-`/consolidate` signal — the just-finished branch must be consolidated before the new branch's first sentence.

In Personal Mode the "branch" corresponds to "switching subtopics". When the user says "let's switch to talking about the kid", that **is** the implicit-`/consolidate` signal for whatever subtopic was active before.

### No auto-write in Personal Mode

LM's auto-write rule (user confirms understanding → immediately write the single confirmed concept to `concepts/`) **does not apply** in Personal Mode. Personal artifacts are not knowledge atoms; there is no "just-confirmed unit small enough to land independently". All Personal Mode synthesis flows through `/consolidate`.

### Session-end behavior

Inherited from Learning Mode: when the user signals end-of-session ("结束 / 明天聊 / done / 收工"), the LLM must first ask "要不要先 /consolidate？" before letting the session close, unless the user has already explicitly opted out. Transcript archival via the `SessionEnd` hook is unchanged.

### Rule 0 reinforcement at consolidation time

Consolidation is the moment Rule 0 is most easily violated: the LLM may have held the line during dialogue but soften the conclusion when writing it down "to avoid hurting the user". Personal Mode's `CLAUDE.md` therefore restates Rule 0 at the `/consolidate` step:

```
When writing positions/ and proposing additions to _profile.md,
apply Rule 0 with extra force. What you write is your judged current
stance, not the version the user prefers to read. Record disagreements
explicitly; do not smooth them.
```

## Migration & Regression

### Current state

The vault contains exactly one real topic — `feature-engineering` — plus a vault-root `CLAUDE.md` deployed from the current `templates/vault-CLAUDE.md`.

### One-time migration steps

```
1. Mark feature-engineering as Learning Mode (sentinel):
   echo learning > ~/Keane/cc-chat/feature-engineering/.cc-mode

2. Replace vault-root CLAUDE.md with the new vault-level signpost:
   cp templates/vault-CLAUDE.md ~/Keane/cc-chat/CLAUDE.md
   # Content is rewritten — from Learning Mode rules to a 4–6-line
   # "please cd into a topic directory before starting CC".

3. Move detailed Learning Mode rules to templates/modes/learning/CLAUDE.md
   (with Rule 0 prepended), then deploy to feature-engineering:
   cp templates/modes/learning/CLAUDE.md \
      ~/Keane/cc-chat/feature-engineering/CLAUDE.md
```

Step 3 is mandatory because the new architecture requires every topic to carry its own `CLAUDE.md`. `feature-engineering` is no exception. Without it, entering the topic shows only the vault-root signpost and the LLM loses Learning Mode rules.

The migration is documented as three manual commands rather than scripted. It runs once, and a script for a single-use migration adds more failure surface than value.

### Regression checklist

After migration, start CC inside `~/Keane/cc-chat/feature-engineering/` and verify:

1. **`SessionStart` injection unchanged**: `systemMessage` shows `📌 cc-chat: 已注入 [feature-engineering] handoff (... 行)`; `additionalContext` contains the tail-30 lines of `_index.md`; **no** `_profile.md` or `positions/<x>.md` content (Learning Mode does not inject these).
2. **`CLAUDE.md` behavior unchanged**: existing LM rules (详细优先, 对比双向展开, 段尾自检, auto-write triggers, `/consolidate` protocol) all still active. Rule 0 is **new** and intentional; this is the only behavioral addition Learning Mode users will notice.
3. **`SessionEnd` archival unchanged**: transcripts archive to `feature-engineering/transcripts/` as both `.jsonl` and `.md`.
4. **`/consolidate` behavior unchanged**: still writes `concepts/`, updates `_map.md`, appends `questions/open.md`.

All four checks passing = migration succeeded.

### Creating the first Personal Mode topic

```
./scripts/new-topic.sh --mode personal personal "Personal"
```

The script:

- Validates `--mode` value (must be `learning` or `personal`).
- Copies `templates/modes/personal/CLAUDE.md` → topic root.
- Instantiates `_map.md`, `_index.md`, `_profile.md` from `templates/modes/personal/`.
- Writes `personal` into `.cc-mode`.
- Creates `transcripts/` and `positions/` only.
- Does **not** create `concepts/`, `chapters/`, `examples/`, `refs/`, `questions/`.
- Does **not** redeploy the vault-root `CLAUDE.md` if it already exists. If the vault-root `CLAUDE.md` is missing (fresh-install case), the script deploys it from `templates/vault-CLAUDE.md` — this preserves the existing safety-net behavior of `new-topic.sh` and ensures a fresh vault always has a usable signpost.

After creation, the user hand-writes initial `_profile.md` content. This is a seed step — the LLM does not write `_profile.md` on the user's behalf (same discipline as `_map.md` seeding in Learning Mode).

### Removed templates

The old top-level `templates/topic-_map.md` and `templates/topic-_index.md` are deleted after their content moves to `templates/modes/learning/`. `new-topic.sh` does not fall back to the old location — there is one and only one path: `templates/modes/<mode>/`.

### Deferred (YAGNI)

- No automated migration script — three manual commands run once.
- No mode-switching feature for existing topics — fixed at creation.
- No interactive `--mode` prompt in `new-topic.sh` — explicit flag prevents accidents.
- No placeholder directories for future modes (`templates/modes/decision/` etc.) — added when the mode is actually built.

## Open Questions

None at the time of this writing. All design decisions through Sections 1–6 were confirmed by the user during the brainstorming dialogue on 2026-05-22.

## Out of Scope (Reiteration)

This spec covers Mode Abstraction + Personal Mode + Rule 0 + Migration only. The following are explicit follow-ups, each their own future spec:

- **Decision Mode**: options / trade-offs / final-decision-with-rationale shape.
- **Research Mode**: question-driven, evidence-anchored, citation-tracking shape.
- **Incubation Mode**: idea → hypothesis → roadmap shape.

Each future mode is expected to add `templates/modes/<name>/` (CLAUDE.md, topic-_map.md, topic-_index.md, possibly mode-specific files) and a `build_context_<mode>` branch in `session-start-context.sh`. No further infrastructure changes are anticipated for those three modes.
