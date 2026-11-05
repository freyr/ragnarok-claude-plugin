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

```text
/plugin marketplace add freyr/ragnarok-claude-plugin
/plugin install ragnarok@ragnarok
/plugin install ragnarok-kb-mods@ragnarok
```

From a shell, use `claude plugin marketplace add` and `claude plugin install` with the same arguments.

To get new versions, run `/plugin marketplace update ragnarok`.

## Layout

```text
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

```text
claude --plugin-dir plugins/<name>
```

Or add this checkout as a local marketplace. Then `/reload-plugins` reads your edits with no new version:

```text
claude plugin marketplace add ~/code/freyr/ragnarok-claude-plugin
```

Do not change `version` by hand. The release workflow sets it (see Releases).

## Releases

All plugins and the marketplace share one version. Each push to `main` runs the release workflow.
It looks at the commit messages since the last tag. A marker in a commit message selects the release:

| Marker | Release | Example |
|---|---|---|
| `[major]` | 1.4.2 → 2.0.0 | `Rename the search skill [major]` |
| `[minor]` | 1.4.2 → 1.5.0 | `Add the setup command [minor]` |
| `[patch]` | 1.4.2 → 1.4.3 | `Fix the hook matcher [patch]` |
| none, or `[none]` | no release | `Edit the README` |

When there is more than one marker, the highest one applies. A merge commit or a squash commit that holds
a marker also counts. When a marker is found, the workflow:

1. runs CI;
2. sets the new version in `.claude-plugin/marketplace.json` and in every `plugin.json`;
3. updates `CHANGELOG.md` with [git-cliff](https://git-cliff.org) (configuration: `cliff.toml`);
4. commits `chore(release): vX.Y.Z [skip ci]`, tags `vX.Y.Z` and pushes both;
5. publishes a GitHub release with the notes of that version.

The version is computed by [github-tag-action](https://github.com/anothrNick/github-tag-action).

## CI

`.github/workflows/ci.yml` runs on each pull request and before each release:

| Job | Checks |
|---|---|
| Marketplace | Anthropic's [validate-plugins](https://github.com/anthropics/claude-plugins-community/tree/main/.github/actions/validate-plugins) action: `claude plugin validate` and the marketplace policy invariants. |
| Plugins | `scripts/validate-plugins.sh`: `claude plugin validate --strict` and `--profile directory` for each plugin, folders and marketplace entries agree, all versions are the same, `claude plugin test` where a plugin has tests. |
| Lint | markdownlint-cli2, ShellCheck, actionlint. |
| Security | gitleaks (secrets in the history), zizmor (workflow security analysis). |
| Changelog preview | git-cliff writes the unreleased changes to the job summary. |

## License

MIT
