# KISA Stack [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)

My personal coding-agent workflow and desktop dotfiles.

## Current workflow

**Only these five components make up my current personal workflow:**

- [Z.A.E.B.A.L.](https://github.com/howdeploy/Z.A.E.B.A.L) — investigate agent mistakes when criticism is addressed to the agent or an audit is explicitly requested.
- [Ponytail](https://github.com/dietrichgebert/ponytail) — understand the existing implementation and make the smallest complete change.
- [Graphify](https://pypi.org/project/graphifyy/) — build and query a project knowledge graph when explicitly requested.
- [Choirboy Prompt](https://github.com/howdeploy/choirboy-prompt) — load established team decisions and project context when needed.
- [Deploychan MCP](https://github.com/howdeploy/deploychan_mcp) — my curated knowledge and skill catalog, available at `https://mcp.deploychan.webcam/mcp`.

Use each project's own installation instructions for your runtime. This repository does not bundle or install these five integrations. Their documentation and availability determine runtime support.

See [plugins.md](plugins.md) for how the components work together.

## Global instructions

[global-config/](global-config/) contains paired `CLAUDE.md` and `AGENTS.md` templates: understand the task, read the existing code, preserve working behavior, and deliver the requested change for the user to check. Tests and other agents require an explicit user request.

Adapt the templates before copying them into your global configuration. Integrations remain subject to the user's task and the runtime's permissions.

## Desktop dotfiles

[dotfiles/](dotfiles/) contains ShojiWM, Quickshell, Walker, shaders and the portable desktop setup. Follow its own [README](dotfiles/README.md) for installation; desktop configuration is separate from the coding-agent workflow.

## Archived skills

[skills/](skills/) preserves earlier task-specific skills for reference. **They are not my current workflow or a recommended starter bundle.** The old bulk-install command is disabled so it cannot install that archive as the current stack.

If you deliberately want an archived skill, review it first and install it by name:

```bash
./install.sh <skill-name> --claude
./install.sh <skill-name> --codex
./install.sh <skill-name> --hermes
```

Without a runtime flag, the script targets Claude Code and Codex. Existing skill directories are backed up with a timestamp. The script installs only the selected archived skill; it does not set up the current workflow, global instructions or desktop.

## Contributing

This is my personal setup. Open an issue if a published instruction is stale or something is broken.
