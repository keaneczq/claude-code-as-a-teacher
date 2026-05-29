# cc-chat vault

这里是多 topic / 多 mode 的根目录，不直接承载任何 topic 的对话规则。

请进入具体 topic 目录后再启动 Claude Code：

    cd ~/Keane/cc-chat/<topic-slug>
    claude

每个 topic 目录有自己的 `CLAUDE.md` 和 `.cc-mode`，决定该 topic 的运行模式。
新建 topic：在仓库目录运行 `./scripts/new-topic.sh [--mode learning|personal] <slug> [title]`。

## LaTeX / 公式（全 vault 通用，渲染目标是 Obsidian）

公式一律用 LaTeX：行内 `$...$`，块级 `$$...$$`。不要用 ASCII 排版（如 `WoE_i = ln(...)`）——那只是终端临时显示，不进文件。

块级 `$$` 的硬性结构（不遵守会渲染成乱码而非公式）：

- `$$` 必须**顶格（第 0 列）**，前后各留一个空行。任何前导缩进都会让 Obsidian 不再把它当数学块，进而把 `_{}`、`\max_t` 里的 `_` 当成斜体标记吃掉。
- **不要把块级 `$$` 放进列表项**（`-` / 数字列表）里——缩进会触发同样的问题。列表里要么用行内 `$...$` 写成一行，要么把公式拉出列表、单独顶格成块。
