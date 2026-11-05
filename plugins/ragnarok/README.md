# ragnarok

Sets up the [ragnarok](https://github.com/freyr/ragnarok) vault search system on a fresh machine.

## Install

```text
/plugin install ragnarok --marketplace freyr/ragnarok-claude-plugin
```

## Layout

| Folder | Holds |
|---|---|
| `skills/` | One folder per skill, each with a `SKILL.md`. |
| `commands/` | Slash commands as Markdown files. |
| `agents/` | Subagent definitions as Markdown files. |
| `hooks/hooks.json` | Command hooks (`SessionStart`, `PreToolUse`, and others). |
| `.mcp.json` | The `ragnarok` MCP server registration (to add). |

## Planned content

- The `ragnarok` MCP server registration. Today `ragnarok init` registers it at the user scope.
- A setup skill or command that clones `freyr/ragnarok` and runs `./setup.sh`.
- The "ragnarok first" search guidance from `~/.claude/ragnarok.md`.
- The vault workflow skills that depend on ragnarok.
