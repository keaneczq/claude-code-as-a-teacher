# cc-chat vault

这里是多 topic / 多 mode 的根目录，不直接承载任何 topic 的对话规则。

请进入具体 topic 目录后再启动 Claude Code：

    cd ~/Keane/cc-chat/<topic-slug>
    claude

每个 topic 目录有自己的 `CLAUDE.md` 和 `.cc-mode`，决定该 topic 的运行模式。
新建 topic：在仓库目录运行 `./scripts/new-topic.sh [--mode learning|personal] <slug> [title]`。
