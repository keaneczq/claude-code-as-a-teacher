# cc-chat

Claude Code 作为长期学习/严肃讨论 chatbot 的工具集。

## 角色分工

- **本仓库**（`/Users/keane/git/cc-chat/`）：开发产物。模板、脚本、文档、未来的 hook 与 skill。
- **Vault**（`~/Keane/cc-chat/`）：运行时数据。每个子目录一个长期话题；笔记、概念、原始对话存档。Obsidian 的 git 插件已覆盖 vault，无需额外版本控制。

## 快速开始

```bash
# 创建一个新话题（同时会在首次运行时部署 vault 级 CLAUDE.md）
./scripts/new-topic.sh feature-engineering

# 进入话题目录开始工作
cd ~/Keane/cc-chat/feature-engineering
claude
```

## 操作规范

读 `docs/conventions.md`，这是不破坏 vault 结构的关键。

## 设计原则

1. **transcripts 是流水，insights 是资产**：原始对话只 append，不当作知识使用。
2. **原子笔记 + 索引图**：每个概念一个文件，`_map.md` 做导航。
3. **session 按概念切，不按时间切**：一个 session 聚焦一个分支。
4. **token 纪律**：每次只加载 `_map.md` + `_index.md` + 1-2 个 concept。
5. **机械活脚本做，智力活 LLM 做**。
# claude-code-as-a-teacher
