#!/usr/bin/env bash
# session-context.sh — SessionStart hook for claude-openproject-ops.
#
# Emits to stdout (Claude Code adds it to the session context):
#   1. the plugin's runtime operating contract (shipped, addressed via $CLAUDE_PLUGIN_ROOT), and
#   2. the host-local instance scratchpad, if it exists at the canonical path.
#
# The scratchpad path comes from the SAME resolver the writers use
# (scripts/op-state-path.sh → $OP_STATE_FILE, else $HOME/.op-state.local.md), so reader and writer
# can never point at different files. Location-independent (contract via $CLAUDE_PLUGIN_ROOT);
# best-effort — missing pieces are skipped silently and the hook always exits 0.
set -u

ROOT="${CLAUDE_PLUGIN_ROOT:-}"

# 1. Operating contract (shipped with the plugin).
contract="$ROOT/context/operating-contract.md"
[ -n "$ROOT" ] && [ -f "$contract" ] && cat "$contract"

# 2. Instance scratchpad (host-local, NOT shipped) — at the canonical path the writers also use.
sp=""
resolver="$ROOT/scripts/op-state-path.sh"
[ -n "$ROOT" ] && [ -f "$resolver" ] && sp="$(bash "$resolver" 2>/dev/null || true)"

if [ -n "${sp:-}" ]; then
  if [ -s "$sp" ] && ! grep -qE '\(TEMPLATE\)|<https://host>' "$sp" 2>/dev/null; then
    # Populated → inject it for read-modify-write.
    printf '\n---\n## Instance scratchpad (host-local) — read-modify-write here, never commit\n'
    printf 'path: %s\n\n' "$sp"
    cat "$sp"
  else
    # Missing or still a template → prompt the agent to populate it this session (the hook can't:
    # real instance facts need /op-setup + provisioning or a live-instance read).
    printf '\n---\n## Instance scratchpad — NOT POPULATED (fill before operating the instance)\n'
    printf 'canonical path: %s\n' "$sp"
    printf 'It is missing or still a template. Create it at that path from templates/op-state.example.md, then fill it via /op-setup (Instance) + intake provisioning, or from the live instance. Do not operate the instance blind; do not invent values.\n'
  fi
fi

exit 0
