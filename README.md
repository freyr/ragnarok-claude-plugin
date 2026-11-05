# ragnarok-claude-plugin

Claude Code plugins for [ragnarok](https://github.com/freyr/ragnarok), the local RAG search over Obsidian vaults.
This repository is a plugin marketplace with more than one plugin.

## Plugins

| Plugin | Purpose |
|---|---|
| [`ragnarok`](plugins/ragnarok) | Skills, hooks and configuration to set up the ragnarok vault search system on a fresh machine. |
| [`ragnarok-kb-mods`](plugins/ragnarok-kb-mods) | Optional mods for ragnarok knowledge-base features. |

## Install

Add the marketplace once, then install the plugins that you need:

```
/plugin marketplace add freyr/ragnarok-claude-plugin
/plugin install ragnarok@ragnarok
/plugin install ragnarok-kb-mods@ragnarok
```

From a shell, use `claude plugin marketplace add` and `claude plugin install` with the same arguments.

To get new versions, run `/plugin marketplace update ragnarok`.

## Layout

```
.claude-plugin/marketplace.json   the marketplace "ragnarok": lists each plugin and its folder
plugins/<name>/                   one folder for each plugin
  .claude-plugin/plugin.json      the plugin manifest
  skills/  commands/  agents/     components
  hooks/hooks.json                command hooks, or {"modules": [...]} for a mod
templates/plugin/                 the skeleton for a new plugin
```

## Add a plugin

1. Copy `templates/plugin/` to `plugins/<name>/`.
2. Replace `PLUGIN_NAME` and `ONE_LINE_DESCRIPTION` in `plugin.json` and `README.md`.
3. Add an entry to `.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
4. Validate: `claude plugin validate .` and `claude plugin validate plugins/<name>`.

## Develop

Load a plugin from its folder for one session:

```
claude --plugin-dir plugins/<name>
```

Or add this checkout as a local marketplace. Then `/reload-plugins` reads your edits with no new version:

```
claude plugin marketplace add ~/code/freyr/ragnarok-claude-plugin
```

Increase `version` in a plugin's `plugin.json` when you release a change.

## License

MIT
