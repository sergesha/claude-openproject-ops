#!/usr/bin/env bash
# op-state-path.sh — the ONE canonical path of the host-local instance scratchpad.
#
# Reader (the SessionStart hook) and writers (/op-setup, intake provisioning, section-owner skills)
# all resolve the scratchpad location through THIS script, so the file that gets written is always
# the file that gets read — they cannot diverge. Deterministic, no cwd guessing:
#
#   OP_STATE_FILE  if set (explicit override, e.g. multi-instance hosts), else
#   $HOME/.op-state.local.md   (zero-config default: one host = one instance = one scratchpad)
#
# Prints the path to stdout. Does NOT create the file (creation is a /op-setup action).
set -u
if [ -z "${HOME:-}" ] && [ -z "${OP_STATE_FILE:-}" ]; then
  echo "op-state-path.sh: neither OP_STATE_FILE nor HOME is set" >&2
  exit 1
fi
printf '%s\n' "${OP_STATE_FILE:-${HOME}/.op-state.local.md}"
