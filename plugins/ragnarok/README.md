# ragnarok

Claude Code support for [ragnarok](https://github.com/freyr/ragnarok), the local RAG search over Obsidian
vaults. The plugin sets ragnarok up on a computer, adapts it to your vaults, and tells Claude to search the
vaults with ragnarok before it uses Grep.

## Install

```text
/plugin marketplace add freyr/ragnarok-claude-plugin
/plugin install ragnarok@ragnarok
```

Then ask Claude to set up ragnarok. The `ragnarok-setup` skill does the rest.

## Content

| Part | What it does |
| --- | --- |
| Skill `ragnarok-setup` | Clones `freyr/ragnarok`, runs `setup.sh` (uv, Ollama service, embedding model, index, MCP registration) and `ragnarok doctor`, and fixes what fails. |
| Skill `ragnarok-adapt` | Adapts ragnarok to your vaults: survey, private folders, path rules, optional frontmatter backfill, an evaluation set. |
| SessionStart hook | Adds the "ragnarok first" search guidance to each session, so Claude uses the `mcp__ragnarok__*` tools before Grep. |
| `scripts/ragnarok-dir.sh` | Finds the checkout: `$RAGNAROK_DIR`, else the folder of the registered MCP server, else `~/code/ragnarok`. |

The plugin does not register the MCP server. `ragnarok init` registers it at the user scope, with the
folder of your checkout. The tool names then stay `mcp__ragnarok__*` for all sessions.

## Requirements

macOS with Homebrew, `brew install ollama`, and Claude Code. `setup.sh` installs uv.

## Note

If your `~/.claude/CLAUDE.md` already holds a "ragnarok first" block, remove it. The hook gives the same
guidance, and two copies that differ confuse Claude.
