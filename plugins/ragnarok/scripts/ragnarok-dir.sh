#!/usr/bin/env bash
# Print the folder of the ragnarok checkout on this computer.
# Order: $RAGNAROK_DIR; the --directory argument of the MCP server "ragnarok" in ~/.claude.json;
# the default ~/code/ragnarok. Exit 1 when the folder has no ragnarok checkout (it still prints the path).
set -uo pipefail

dir=${RAGNAROK_DIR:-}

if [ -z "$dir" ] && [ -r "$HOME/.claude.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    args=$(jq -r '.mcpServers.ragnarok.args // [] | .[]' "$HOME/.claude.json" 2>/dev/null)
  else
    args=$(plutil -extract mcpServers.ragnarok.args json -o - "$HOME/.claude.json" 2>/dev/null |
      tr -d '[]' | tr ',' '\n' | sed -E 's/^ *"//; s/" *$//; s#\\/#/#g')
  fi
  dir=$(printf '%s\n' "$args" | awk 'prev == "--directory" { print; exit } { prev = $0 }')
fi

dir=${dir:-$HOME/code/ragnarok}
dir=${dir/#\~/$HOME}
printf '%s\n' "$dir"
[ -f "$dir/pyproject.toml" ] && grep -q '^name = "ragnarok"' "$dir/pyproject.toml"
