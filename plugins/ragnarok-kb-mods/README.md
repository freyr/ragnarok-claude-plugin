# ragnarok-kb-mods

Optional mods for ragnarok knowledge-base features: panes, bands, status entries and hooks that use the
ragnarok index. Install this plugin only if you want these features. It needs the `ragnarok` plugin and a
working ragnarok setup.

## Install

```text
/plugin install ragnarok-kb-mods --marketplace freyr/ragnarok-claude-plugin
```

## Develop

The hooks module is `hooks/register.ts`. Add hooks with `on(event, matcher?, hook)`. Validate the plugin:

```text
claude plugin validate plugins/ragnarok-kb-mods
```

Load it from disk for one session:

```text
claude --plugin-dir plugins/ragnarok-kb-mods
```
