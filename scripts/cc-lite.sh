#!/usr/bin/env bash
# cc-lite: launch Claude Code with a lightweight settings overlay for the cc-chat vault.
#
# Why: learning/personal topics under ~/Keane/cc-chat/ don't need dev plugins
# (superpowers / document-skills / etc) or the full skill listing. Those cost
# ~11k of first-turn context. This overlay disables them via --settings, which
# DEEP-MERGES over ~/.claude/settings.json (token / hooks / permissions are
# inherited, only the keys in the overlay are changed). Global config edits flow
# through automatically — no manual sync.
#
# Source this file from ~/.bashrc and ~/.zshrc.
cc-lite() {
  command claude --settings "$HOME/.claude/cc-chat-lite.json" "$@"
}
