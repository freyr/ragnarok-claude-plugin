---
name: ragnarok-setup
description: Use to install ragnarok (local RAG search over Obsidian vaults) on a computer, to repair it, or to check it — when the mcp__ragnarok__* tools are absent or fail, when `ragnarok doctor` reports a failure, or when the person asks to set up vault search on a new Mac. Clones freyr/ragnarok, runs setup.sh and doctor, and fixes what fails. Not for tuning the path rules or private folders (ragnarok-adapt) or for normal searching.
---

# Set up ragnarok

ragnarok is a local MCP server that searches the Markdown notes of Obsidian vaults. Its code and its
own documentation are in the checkout of [freyr/ragnarok](https://github.com/freyr/ragnarok). This plugin
gives the search guidance (a SessionStart hook) and these skills. `ragnarok init` registers the MCP
server `ragnarok` at the user scope, so the tools are `mcp__ragnarok__*`.

## Find the checkout

```bash
R=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/ragnarok-dir.sh") && echo "checkout: $R" || echo "no checkout at $R"
```

The script reads `$RAGNAROK_DIR`, then the `--directory` of the registered MCP server, then uses
`~/code/ragnarok`. Run all ragnarok commands in that folder: `cd "$R" && uv run ragnarok <command>`.

## Check

```bash
cd "$R" && uv run ragnarok doctor
```

`doctor` checks the configuration, Ollama, the Ollama service, the embedding model, the index and the
MCP registration. It prints a fix for each failure. When all parts pass and the tools are still absent,
the person must restart Claude Code.

## Install on a new computer

Requirements: macOS with Homebrew and `brew install ollama`. `setup.sh` installs uv when it is missing.

1. Ask the person for the checkout folder (default `~/code/ragnarok`) and the vault root (the folder that
   holds the vault folders, for example `~/Documents/Vaults`).
2. Clone, if the folder has no checkout:

   ```bash
   git clone https://github.com/freyr/ragnarok.git "$R"
   ```

3. Tell the person what `init` does before you run it: it writes `config.toml` with each folder under the
   root as a vault, starts Ollama with `brew services`, pulls the embedding model, indexes all vaults and
   registers the MCP server at the user scope. `--yes` accepts the default answer of each question, so
   ask the person first. Without `--yes`, the person runs it in a terminal (`! cd "$R" && ./setup.sh`).
4. Run the setup. The first index of 1,500 notes takes about 12 minutes, so run it in the background:

   ```bash
   cd "$R" && ./setup.sh --yes --root "<vault root>"
   ```

5. Run `uv run ragnarok doctor` until all parts pass.
6. Before the first search, agree on the private folders with the person (`ragnarok-adapt`, step 2).
   Private patterns apply when the server answers, so notes indexed before the patterns are safe.
7. Tell the person to restart Claude Code. The tools then appear as `mcp__ragnarok__*`.
8. Continue with the `ragnarok-adapt` skill to set the path rules for the vaults of the person.

## Repair

| Symptom | Fix |
| --- | --- |
| `doctor`: Ollama not running | `brew services start ollama` |
| `doctor`: model missing | `ollama pull` the model that `config.toml` names |
| `doctor`: MCP not registered, or registered with another folder | `cd "$R" && uv run ragnarok init` (step 6 asks before it replaces a registration) |
| Tools present, results empty or old | `cd "$R" && uv run ragnarok status`, then `uv run ragnarok index` |
| A slow first call after a config change | Normal: the call indexes the changed notes. Run `ragnarok index` from the CLI first. |

The server log is `$R/logs/server.log`, one line for each tool call.

## Update

```bash
cd "$R" && git pull --ff-only && uv sync && uv run ragnarok doctor
```

Restart Claude Code after an update, so that it starts the new server.
