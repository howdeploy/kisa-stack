# Global instruction templates

These templates describe the current KISA workflow for Claude Code and Codex: Z.A.E.B.A.L., Ponytail, Graphify, Choirboy Prompt and Deploychan MCP. Install the integrations separately using the links in [plugins.md](../plugins.md).

| File | Destination |
|---|---|
| [CLAUDE.md](CLAUDE.md) | `~/.claude/CLAUDE.md` |
| [AGENTS.md](AGENTS.md) | `~/.codex/AGENTS.md` (or your configured Codex home) |

## Install

Read and adapt the relevant template. Merge it with your existing global instructions; keep a backup before replacing an existing file. The templates preserve KISA's preference for Russian private chat and English GitHub communication; change that preference for your own use if needed.

The templates do not install plugins, MCP servers or skills. Check availability in the active runtime before using an integration. Use [Deploychan MCP's documentation](https://github.com/howdeploy/deploychan_mcp) to connect the personal catalog.

## Working rules

- Understand the requested outcome and read the current implementation before editing.
- Make the smallest complete change, preserving existing behavior and unfinished user work.
- Use native tools and verify claims against files, command output and current sources.
- Ask about material scope decisions, new access, spending and destructive actions.
- Leave tests, builds, lint, typechecks, browser checks and subagents to an explicit user request.
- Report what changed, what was checked by reading, and what was not run.

## Optional local knowledge base

A personal knowledge base is not required to use the workflow. If you have one, add its canonical path and reading rules to your own instructions. Read relevant project context directly from files and write memory only within an explicit request. Obsidian may be used as a viewer; no separate writer or import pipeline is required.

The `hooks/wiki-anchor.sh`, `hooks/wiki-reminder.sh` and `settings.hooks.example.json` files are legacy examples preserved for reference. They are not part of the current setup; do not copy them as an installation step. If you previously enabled those hooks, review and remove their entries from your own settings when migrating, preserving unrelated hooks and settings.
