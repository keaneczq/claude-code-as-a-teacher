# Operating Conventions

> Read this once before using the vault. Re-read when behavior drifts.

## 三层架构

```
本仓库 (~/git/cc-chat/)         vault (~/Keane/cc-chat/)         hooks (~/.claude/settings.json)
─────────────────────           ─────────────────────────        ──────────────────────────────
templates/vault-CLAUDE.md ─→    CLAUDE.md (vault root, signpost) SessionStart → session-start-context.sh
templates/modes/<mode>/   ─→    <topic>/CLAUDE.md                SessionEnd   → export-transcript.sh
templates/modes/<mode>/   ─→    <topic>/_map.md, _index.md       (注入由 ./scripts/install-hooks.sh 完成)
                                <topic>/.cc-mode  (mode 哨兵，hook 据此分流)
                                <topic>/<mode-specific dirs>
                                <topic>/transcripts/  ←─── SessionEnd hook 自动落档（jsonl + md）

轻量启动（非部署，按需用 cc-lite 命令启动）：
templates/cc-chat-lite-settings.json ─→ ~/.claude/cc-chat-lite.json   (--settings overlay)
scripts/cc-lite.sh                    ─→ source 进 ~/.bash_profile / ~/.zshrc (定义 cc-lite)
```

- **本仓库**：开发产物，进入这里写代码、改模板、调脚本。
- **vault**：运行时数据，进入某个 topic 目录后启动 `claude`，进行学习。
- **hooks**：把"开 session 时注入 handoff"和"关 session 时存档 transcript"自动化。session-start-context.sh 现在按 `.cc-mode` 分流（learning / personal）。
- 三者职责严格分开——别在 vault 里写脚本，也别在本仓库里学知识。

## 多模式（Multi-Mode）

vault 现在支持多种"运行模式"。每个 topic 在创建时通过 `.cc-mode` 哨兵文件声明自己的模式，hook 据此决定如何注入上下文。

### 当前可用模式

- **`learning`**（默认）— 长时间学习一个领域：知识图谱、概念原子、章节进度。中心产物是 `concepts/*.md`。
- **`personal`** — 个人/人生类深度对话：性格、孩子教育、世界观、个人事务。中心产物是 `_profile.md`（你是谁，跨子主题加载）和 `positions/<subtopic>.md`（每个子主题的当前立场 + 演化轨迹）。

### 关键差异

| 维度 | learning | personal |
|---|---|---|
| 中心产物 | `concepts/*.md` | `positions/<subtopic>.md` |
| 跨 session 身份载体 | 无 | `_profile.md` 跨子主题始终注入 |
| transcripts 角色 | 默认不主动读 | 默认不注入但鼓励按需读 |
| Hook 启动注入 | `_index.md` handoff | handoff + `_profile.md` 全文 + 焦点 `positions/<x>.md` 全文 |
| /consolidate | 知识综合（写 concepts） | 立场综合 + 身份提议（写 positions、ask 才回写 _profile） |

### Rule 0（高于其他所有规则）

**所有模式**的 `CLAUDE.md` 顶部都植入了同一份 Rule 0：客观、不迎合情绪、默认挑战不默认推进。这是跨模式的最高规则——LLM 在任何模式下都必须先认可你的观点再推进，不能因为你的语气、情绪或确定性就接受论点。

### 模式不可切换

一个 topic 创建时选定的 mode 是固定的——后续不能改。如果想切换，新建一个 topic 然后手动迁移内容。

## 启动 session 的标准流程

```bash
cd ~/Keane/cc-chat/<topic>
claude
```

进入话题目录再启动 CC 是关键：CC 会把当前目录当工作空间，自动加载 vault 根的 `CLAUDE.md` 和当前 topic 的文件。

**不要**在 vault 根目录直接启动 CC——那样它没有 topic context，会茫然或者乱写。

## 创建新话题

```bash
cd ~/git/cc-chat
./scripts/new-topic.sh [--mode learning|personal] <slug> "<可选的标题>"
```

`--mode` 默认是 `learning`，可省略；显式 `--mode personal` 创建个人模式 topic。

脚本会：
- 首次运行时把 `templates/vault-CLAUDE.md` 部署到 vault 根（signpost）
- 拷贝 `templates/modes/<mode>/CLAUDE.md` 到 `<topic>/CLAUDE.md`（这是该 topic 的运行规则）
- 写 `<topic>/.cc-mode`，内容是 mode 名
- 创建 mode 对应的目录布局（learning 创建 `concepts/`、`chapters/`、`examples/`、`refs/`、`questions/`、`transcripts/`；personal 只创建 `positions/`、`transcripts/`）
- 实例化 `_map.md`、`_index.md`（personal 还会实例化 `_profile.md`）

**创建后必做**：
- learning：手写 `_map.md` 的"学习目标"、"当前材料"、"待开始"三块。
- personal：手写 `_profile.md` 的稳定身份信息（关键经历 / 价值观底色 / 关键关系 / 性格 / 当前生活状态快照）。这是 seed，LLM 不会替你写。

## 文件触碰规则（给你和 CC 都看的）

| 文件 | 谁可以写 | 何时写 |
|---|---|---|
| `_map.md` | 你（主） + CC（限定时机） | 你随时改；CC 仅在 `/consolidate` 或你明说时改 |
| `.cc-mode` | `new-topic.sh` 写一次 | 之后**永不修改**——hook 据此分流 |
| `_index.md` | 你 + CC | session 开始你写焦点，结束 CC 写 handoff |
| `concepts/*.md` | CC（主） + 你 | session 中 CC 自动写定义/公式/例子；你随时增补 |
| `examples/*.md` | CC + 你 | 同上 |
| `questions/open.md` | CC + 你 | 遇到没解决的问题就追加 |
| `transcripts/*.md` | 脚本 / 你手动 | session 结束后存档；CC 不读不写 |
| `refs/*.md` | 你（主） | 书摘、论文、外部链接 |
| `_profile.md` (personal) | 你（主）+ LLM（先问再写） | 你随时改；LLM 在 /consolidate 时只能**提议**条目，得你许可才回写 |
| `positions/*.md` (personal) | LLM（主）+ 你 | /consolidate 时 LLM 重写"当前立场"，旧版本进"演化轨迹" |

## Session 协议

### 开始
1. `_index.md` 写好"今天打算搞什么"
2. 启动 `claude`
3. 第一句话可以是："读 _index 和 _map，确认你理解今天的焦点"

### 进行中
- 让 CC 边讨论边写 `concepts/*.md`（这是默认行为，写在 vault CLAUDE.md 里）
- 不重要的来回不需要追问"要不要记下来"，重要的 CC 会自动记
- 遇到没搞懂的，直接说"加进 questions/open"
- **想边讨论边在 Obsidian 里看渲染**（LaTeX、代码块在终端读着痛苦）：打开 topic 根的 `_live.md`。它由 `Stop` hook（`live-render.sh`）在每轮回复后自动重渲染当前 session 的完整对话流，Obsidian 会自动重载，近实时看到 MathJax 排好的公式。
  - 这是**临时阅读面**，不是知识资产：每轮全量覆盖，session 结束时被 `export-transcript.sh` 清掉。别在里面记东西，别 import 它。
  - 它和模型无关——hook 读的是本来就存在的 transcript JSONL，**零 token 成本**，也不依赖模型记得镜像自己的输出。
  - `_live.md` 应进 vault 的 `.gitignore`（它是 scratch，不该被 Obsidian git 插件 commit）。

### 想要总结时
说"`/consolidate`"或"整理一下"，CC 会：
- 更新相关 concept 文件
- 更新 `_map.md` 状态
- 把未解决的扔进 `questions/open.md`
- 在 `_index.md` 留 handoff

### 结束
- 用户给出结束信号（"结束"、"明天聊"、"done"、"收工"、"拜了"）时，CC 应**先反问"要不要 /consolidate？"**——这是写在 vault CLAUDE.md 的硬规则。
- transcript 由 SessionEnd hook 自动存档到 `<topic>/transcripts/`：
  - `<时间戳>-<sessionid8>.jsonl` 无损备份
  - `<时间戳>-<sessionid8>.md` Obsidian 可读渲染（user/assistant 对话流，thinking 折叠）
- 如果某次没 /consolidate 就退出，下次 SessionStart hook 会扫到这件事并提示恢复流程：读那份 MD → /consolidate → 再进入新焦点。
- 进行中那份 `_live.md`（见 § 进行中）在 SessionEnd 归档完成后被清掉——durable 副本已落进 `transcripts/`，临时阅读面没有保留价值。
- Obsidian 的 git 插件会自动 commit vault，包括本次改动。

## 反模式（别这么干）

- **在一个 session 里讨论多个不相关概念**：会让 concept 文件被来回切换、写得碎。一次一个分支。
- **让 `_map.md` 变成内容堆**：它只是状态导航，超过 5k tokens 就该拆或精炼。
- **直接读 transcripts 找东西**：用 Obsidian 全文搜索，或重新讨论。transcripts 是流水档案，不是知识。
- **跨 topic 互相引用 concept**：每个 topic 自治。如果两个 topic 真的需要共享概念，先讨论再决定如何组织。
- **手动改 vault 根 `CLAUDE.md`**：那个文件现在只是个 signpost（指向 topic 目录），不承载运行规则。要改 topic 的运行规则，改对应模式的 `templates/modes/<mode>/CLAUDE.md`，然后重新部署到该 topic 目录的 `CLAUDE.md`。
- **手动改 topic 的 `.cc-mode`**：这个文件由 `new-topic.sh` 一次性写入，之后视为不可变。如果你真的想"切换模式"，新建 topic 重新来。
- **想靠 vault 里的 `.claude/settings.json` 关插件**：行不通。CC 只读启动目录的 settings、不向上 walk，且 `enabledPlugins:false` 在普通 project scope 关不掉全局已开的插件。要给 cc-chat 子树减负，用 `cc-lite` 启动（见 § 模板更新流程），别在 vault 里放 settings 文件。

## 模板更新流程

想改 vault 根 `CLAUDE.md`（signpost）时：
1. 改本仓库的 `templates/vault-CLAUDE.md`
2. `cp templates/vault-CLAUDE.md ~/Keane/cc-chat/CLAUDE.md` 覆盖

想给 cc-chat 子树减负（轻量启动）时：
1. 改本仓库的 `templates/cc-chat-lite-settings.json`（源头）
2. `cp templates/cc-chat-lite-settings.json ~/.claude/cc-chat-lite.json` 部署到运行位置
3. 用 `cc-lite`（而非 `claude`）从任意 cc-chat topic 启动，即生效

   机制要点（都已实测确认）：
   - `cc-lite` 是 `scripts/cc-lite.sh` 定义的函数，等价于 `claude --settings ~/.claude/cc-chat-lite.json`。`--settings` 对全局 `~/.claude/settings.json` 做**深合并**：overlay 里写的 key 覆盖全局，没写的（token / hooks / permissions / statusLine）全部继承。所以全局配置改了会自动跟随，**零维护、不漂移**。
   - overlay 三件事：`skillListingBudgetFraction: 0.001` 把 skill listing 从 ~4.5k 压到接近 0；`enabledPlugins` 全 `false` 关掉 dev 插件（经 `--settings` 高优先级 scope 传入，实测能真正关闭，不只是省描述）；`skillOverrides` 把 user skill 设 `user-invocable-only`（对 Claude 隐藏、`/` 仍可手动调）。
   - **为什么不用项目级 `.claude/settings.json`**：CC 只读「启动目录」的 settings，不向上 walk；且 vault 的 git root 是整个 `~/Keane`（Obsidian vault），在那放配置粒度太宽。`--settings` 是唯一能精准「仅此子树轻量」又不碰 vault、不嵌套 git repo 的办法。
   - 普通 `claude` 启动 = 全套工具（dev 仓库、需要插件的场景用这个）；`cc-lite` 启动 = 轻量。由你显式选择，无隐式魔法。
   - 联网搜索（WebSearch / WebFetch）是 CC 内置工具，任何插件开关都不影响。

想改某个 mode 的运行规则时：
1. 改本仓库的 `templates/modes/<mode>/CLAUDE.md`
2. 对每个使用该 mode 的现有 topic，手动覆盖：`cp templates/modes/<mode>/CLAUDE.md ~/Keane/cc-chat/<topic>/CLAUDE.md`
3. 新建的 topic 会自动用最新模板

想改 topic 模板（`_map.md` / `_index.md` / personal 的 `_profile.md`）时：
- 只影响**新建的 topic**。已有的 topic 是手写演化出来的产物，不应被覆盖。

**在添加新 mode 时**：先在 `templates/modes/<new-mode>/` 准备好模板，再在 `scripts/session-start-context.sh` 的 dispatcher 里加一个 `case` 分支，让 `read_mode` 接受新 mode 名（顺序很重要——`read_mode` 先放行而 dispatcher 没准备好的话，请求会被静默 fallback 到 learning），最后在 `scripts/new-topic.sh` 的 `--mode` 校验 `case` 里加上新 mode（否则 `new-topic.sh --mode <new>` 会拒绝创建）。

## 迁移到多模式

如果你是从单模式 vault 升级过来：

1. 给现有 topic 写 `.cc-mode`（默认所有现存 topic 都是 learning）：
   ```bash
   echo learning > ~/Keane/cc-chat/<existing-topic>/.cc-mode
   ```
   缺失 `.cc-mode` 时 hook 会按 learning 兜底，不会崩——但显式写入更稳。

2. 把现有 vault 根 `CLAUDE.md` 替换成新 signpost：
   ```bash
   cp templates/vault-CLAUDE.md ~/Keane/cc-chat/CLAUDE.md
   ```

3. 给现有 topic 部署对应模式的运行规则文件（**每个 topic 一份**）：
   ```bash
   cp templates/modes/learning/CLAUDE.md ~/Keane/cc-chat/<existing-topic>/CLAUDE.md
   ```

完成后开 session 验证：`📌 cc-chat: 已注入 [<topic>] handoff` 系统消息应该照常出现，session 行为应该完全不变（除了多了 Rule 0）。

详细的迁移指引和回归清单：见 `docs/superpowers/specs/2026-05-22-multi-mode-personal-design.md` § "Migration & Regression"。

## Token 心法

每次 session input 目标 10–15k tokens：

- vault 根 `CLAUDE.md`：~0.05k（signpost，几乎不占）
- topic 的 `CLAUDE.md`（mode-rules）：~3k
- `_map.md`：≤5k
- `_index.md`：~0.5k
- 1–2 个 mode 中心产物文件（learning 的 `concepts/*.md` 或 personal 的 `_profile.md` + 焦点 `positions/<x>.md`）：3–8k

personal mode 由 hook 自动注入 `_profile.md` 全文 + 焦点 `positions/<x>.md` 全文，加起来上限 ~8k。learning mode 由 LLM 按需 Read concepts。

如果超了，LLM 应主动提示你缩小焦点。

以上只算 vault 内容本身。真正吃掉首问 context 的隐形大头是**插件 / MCP / 第三方 SessionStart hook 注入**——Playwright MCP、superpowers 的 using-superpowers 全文注入、document-skills 等加起来能让首问从目标 10–15k 飙到 ~50k。解决办法是用 `cc-lite` 启动（见 § 模板更新流程），把插件和 skill listing 关掉，实测首问从 ~26% 降到 ~23% 区间、Skills 从 4.5k 降到 ~0.8k。如果某次首问 context 异常偏高，先确认是不是忘了用 `cc-lite`、而是用了普通 `claude`。
