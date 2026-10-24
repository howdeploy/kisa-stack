# Current personal workflow

This is the complete current list. Install each integration from its own documentation for the runtime you use; they are not all Claude Code marketplace plugins.

| Component | Role | Source |
|---|---|---|
| Z.A.E.B.A.L. | Audit an agent's mistaken assumptions and actions | [Repository](https://github.com/howdeploy/Z.A.E.B.A.L) |
| Ponytail | Make the smallest complete change after reading the existing code | [Repository](https://github.com/dietrichgebert/ponytail) |
| Graphify | Build and query a source-backed project knowledge graph on request | [Package](https://pypi.org/project/graphifyy/) |
| Choirboy Prompt | Load established team decisions and project context | [Repository](https://github.com/howdeploy/choirboy-prompt) |
| Deploychan MCP | Retrieve my curated knowledge and skill packs | [Repository](https://github.com/howdeploy/deploychan_mcp) · endpoint: `https://mcp.deploychan.webcam/mcp` |

## How I use them

Start with the user's task and the existing implementation. Ponytail keeps the change focused. Load Choirboy context when established decisions matter; author or refresh its dossiers only when the user asks to update memory. Use Deploychan MCP for relevant material without treating a catalog recommendation as permission to install it.

Run Graphify only on an explicit request. When a graph already exists, prefer the relevant `query`, `path` or `explain` operation and check the source before relying on an inferred relationship.

Z.A.E.B.A.L. applies to criticism addressed to the agent or an explicit audit request. A mention of the skill, a quotation or profanity about something else is not an audit request. Follow the user's restrictions on subagents and testing during an audit too.

The [global instruction templates](global-config/) describe the shared working rules. The [archived skills](skills/) and [desktop dotfiles](dotfiles/) are separate resources, not extra components of this workflow.
