# Operating Conventions

> Read this once before using the vault. Re-read when behavior drifts.

## 三层架构

```
本仓库 (~/git/cc-chat/)         vault (~/Keane/cc-chat/)
─────────────────────           ─────────────────────────
templates/  ─── deploy ───→     CLAUDE.md (vault root)
templates/  ─── instantiate ──→ <topic>/_map.md, _index.md
scripts/    ─── invoke ───→     creates topic structure
docs/                           <topic>/concepts/, ...
                                <topic>/transcripts/
```

- **本仓库**：开发产物，进入这里写代码、改模板、调脚本。
- **vault**：运行时数据，进入某个 topic 目录后启动 `claude`，进行学习。
- 两个职责严格分开——别在 vault 里写脚本，也别在本仓库里学知识。

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
./scripts/new-topic.sh <slug> "<可选的标题>"
```

脚本会：
- 首次运行时把 `templates/vault-CLAUDE.md` 部署到 vault 根
- 创建 topic 目录结构
- 实例化 `_map.md` 和 `_index.md`

**创建后必做**：手写 `_map.md` 的"学习目标"、"当前材料"、"待开始"三块。这是 seed，CC 不会替你写。

## 文件触碰规则（给你和 CC 都看的）

| 文件 | 谁可以写 | 何时写 |
|---|---|---|
| `_map.md` | 你（主） + CC（限定时机） | 你随时改；CC 仅在 `/consolidate` 或你明说时改 |
| `_index.md` | 你 + CC | session 开始你写焦点，结束 CC 写 handoff |
| `concepts/*.md` | CC（主） + 你 | session 中 CC 自动写定义/公式/例子；你随时增补 |
| `examples/*.md` | CC + 你 | 同上 |
| `questions/open.md` | CC + 你 | 遇到没解决的问题就追加 |
| `transcripts/*.md` | 脚本 / 你手动 | session 结束后存档；CC 不读不写 |
| `refs/*.md` | 你（主） | 书摘、论文、外部链接 |

## Session 协议

### 开始
1. `_index.md` 写好"今天打算搞什么"
2. 启动 `claude`
3. 第一句话可以是："读 _index 和 _map，确认你理解今天的焦点"

### 进行中
- 让 CC 边讨论边写 `concepts/*.md`（这是默认行为，写在 vault CLAUDE.md 里）
- 不重要的来回不需要追问"要不要记下来"，重要的 CC 会自动记
- 遇到没搞懂的，直接说"加进 questions/open"

### 想要总结时
说"`/consolidate`"或"整理一下"，CC 会：
- 更新相关 concept 文件
- 更新 `_map.md` 状态
- 把未解决的扔进 `questions/open.md`
- 在 `_index.md` 留 handoff

### 结束
- 当前不做 transcript 自动存档（第一周观察期）
- Obsidian 的 git 插件会自动 commit vault，包括本次改动

## 反模式（别这么干）

- **在一个 session 里讨论多个不相关概念**：会让 concept 文件被来回切换、写得碎。一次一个分支。
- **让 `_map.md` 变成内容堆**：它只是状态导航，超过 5k tokens 就该拆或精炼。
- **直接读 transcripts 找东西**：用 Obsidian 全文搜索，或重新讨论。transcripts 是流水档案，不是知识。
- **跨 topic 互相引用 concept**：每个 topic 自治。如果两个 topic 真的需要共享概念，先讨论再决定如何组织。
- **手动改 vault 里的 `CLAUDE.md`**：那个文件是从 `templates/vault-CLAUDE.md` 部署来的。要改改模板，然后重新部署（删掉 vault 里的旧版，下次 `new-topic.sh` 会重新部署；或手动覆盖）。

## 模板更新流程

想改 vault 行为时：
1. 在本仓库改 `templates/vault-CLAUDE.md`
2. 手动 `cp templates/vault-CLAUDE.md ~/Keane/cc-chat/CLAUDE.md` 覆盖
3. 已存在的 topic 不需要管，CC 会自动用新版的 vault CLAUDE.md

想改 topic 模板时（`_map.md` / `_index.md`）：
- 只影响**新建的 topic**。已有的 topic 是手写演化出来的产物，不应被覆盖。

## Token 心法

每次 session input 目标 10–15k tokens：
- vault `CLAUDE.md`：~2k
- `_map.md`：≤5k
- `_index.md`：~0.5k
- 1–2 个 `concepts/*.md`：3–7k

如果超了，CC 应主动提示你缩小焦点。
