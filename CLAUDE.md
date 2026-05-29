# cc-chat — 开发仓库

> 这是 **本仓库**（开发产物）。运行时数据在 vault `~/Keane/cc-chat/`，两者别混。
> 动手改模板 / 脚本 / 配置 / 任何运行规则之前，**先读 `docs/conventions.md`**——它是权威流程，本文件只是把最常踩的坑前置到上下文里。

## 三层架构

```
本仓库 (~/git/cc-chat/)        vault (~/Keane/cc-chat/)          hooks (~/.claude/settings.json)
─────────────────             ───────────────────────           ───────────────────────────────
templates/   ──部署→          <topic>/CLAUDE.md 等运行时规则       SessionStart / SessionEnd 脚本
scripts/                      <topic>/concepts、transcripts 等数据
```

- **本仓库**：写代码、改模板、调脚本。**不在这里学知识。**
- **vault**：运行时数据。进某个 topic 目录启动 `claude` 来学习。
- 两者职责严格分开——别在 vault 写脚本，也别在本仓库学知识。

## 载重规则（最常踩、代价最高的坑）

**改 topic 的运行规则 → 改源头模板，绝不直接编辑 vault 运行时文件。**

vault 里每个 `<topic>/CLAUDE.md` 都是从模板**部署**出来的副本。直接改它会：下次部署被覆盖、绕过版本控制、各 topic 之间漂移。正确流程：

1. 改 `templates/modes/<mode>/CLAUDE.md`（源头）
2. 对每个用该 mode 的现有 topic 部署：
   `cp templates/modes/<mode>/CLAUDE.md ~/Keane/cc-chat/<topic>/CLAUDE.md`
3. 新建 topic 由 `new-topic.sh` 自动用最新模板

同理的源头映射：

- 改 vault 根 signpost → 改 `templates/vault-CLAUDE.md` → `cp` 覆盖 `~/Keane/cc-chat/CLAUDE.md`
- 改 topic 实例模板（`_map.md` / `_index.md` / personal 的 `_profile.md`）→ 只影响**新建** topic，不回溯覆盖已有的

## 细节去哪查（都在 `docs/conventions.md`）

- 模板更新流程、添加新 mode 的步骤 → § 模板更新流程
- 单模式升级到多模式的迁移 + 回归清单 → § 迁移到多模式
- 完整反模式清单 → § 反模式
- 改 settings.json / hooks 行为 → 用 `update-config` skill
