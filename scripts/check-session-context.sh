#!/usr/bin/env bash
# check-session-context.sh — deterministic harness for the runtime context-delivery mechanism.
#
# Verifies that the SessionStart hook ships an operating contract and injects it (plus the
# host-local instance scratchpad at the CANONICAL path) regardless of cwd, that the scratchpad
# reader and writers resolve the same path (scripts/op-state-path.sh), that no host specifics are
# in any shipped file, and that CLAUDE.md doesn't duplicate the contract. Mechanism test only.
#
# Run from the plugin repo root:  bash scripts/check-session-context.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CONTRACT="$ROOT/context/operating-contract.md"
HOOK="$ROOT/hooks/session-context.sh"
HOOKS_JSON="$ROOT/hooks/hooks.json"
RESOLVER="$ROOT/scripts/op-state-path.sh"
PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
CLAUDE_MD="$ROOT/CLAUDE.md"
SENTINEL="op-ops-operating-contract-v1"

fail=0
pass() { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

echo "== files exist =="
[ -s "$CONTRACT" ]   && pass "context/operating-contract.md present & non-empty" || bad "context/operating-contract.md missing/empty"
[ -f "$HOOK" ]       && pass "hooks/session-context.sh present"   || bad "hooks/session-context.sh missing"
[ -x "$HOOK" ]       && pass "hooks/session-context.sh executable" || bad "hooks/session-context.sh not executable"
[ -s "$HOOKS_JSON" ] && pass "hooks/hooks.json present"           || bad "hooks/hooks.json missing"
[ -f "$RESOLVER" ]   && pass "scripts/op-state-path.sh present"   || bad "scripts/op-state-path.sh missing"
[ -x "$RESOLVER" ]   && pass "scripts/op-state-path.sh executable" || bad "scripts/op-state-path.sh not executable"

echo "== contract carries the mandate rules + pointers =="
if [ -s "$CONTRACT" ]; then
  grep -qi "bluff"       "$CONTRACT" && pass "contract: no-bluffing"         || bad "contract: missing no-bluffing"
  grep -qi "disclosure"  "$CONTRACT" && pass "contract: disclosure boundary" || bad "contract: missing disclosure boundary"
  grep -qi "best-effort" "$CONTRACT" && pass "contract: memory best-effort"  || bad "contract: missing memory best-effort"
  grep -qi "scratchpad"  "$CONTRACT" && pass "contract: scratchpad guidance" || bad "contract: missing scratchpad guidance"
  grep -q  "/op-coach"   "$CONTRACT" && pass "contract: /op-coach pointer"   || bad "contract: missing /op-coach pointer"
  grep -q  "$SENTINEL"   "$CONTRACT" && pass "contract: anti-dup sentinel"   || bad "contract: missing sentinel '$SENTINEL'"
fi

echo "== no host specifics in shipped files (scratchpad path is host data, never shipped) =="
LEAK_RE='/home/|([0-9]{1,3}\.){3}[0-9]{1,3}|OPENPROJECT_API_KEY|SECRET_KEY_BASE|\.op-api\.env|\.op-admin\.env|apikey:'
leakhits="$(grep -REn "$LEAK_RE" "$ROOT/context" "$ROOT/hooks" "$RESOLVER" "$PLUGIN_JSON" 2>/dev/null || true)"
if [ -z "$leakhits" ]; then pass "no host specifics in shipped files"; else bad "host specifics leaked:"; printf '%s\n' "$leakhits"; fi

echo "== hooks.json wiring =="
if [ -s "$HOOKS_JSON" ]; then
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$HOOKS_JSON" 2>/dev/null && pass "hooks.json valid JSON" || bad "hooks.json invalid JSON"
  grep -q "SessionStart"       "$HOOKS_JSON" && pass "hooks.json: SessionStart event"            || bad "hooks.json: no SessionStart"
  grep -q 'CLAUDE_PLUGIN_ROOT' "$HOOKS_JSON" && pass "hooks.json: addresses via CLAUDE_PLUGIN_ROOT" || bad "hooks.json: not via CLAUDE_PLUGIN_ROOT"
  grep -q 'session-context'    "$HOOKS_JSON" && pass "hooks.json: runs session-context"          || bad "hooks.json: does not run session-context"
fi
[ -s "$PLUGIN_JSON" ] && grep -q '"hooks"' "$PLUGIN_JSON" && pass "plugin.json registers hooks" || bad "plugin.json missing \"hooks\""

echo "== separation: architecture in README, CLAUDE.md must NOT carry the contract =="
if [ -f "$CLAUDE_MD" ]; then
  grep -q "@context/operating-contract" "$CLAUDE_MD" && bad "CLAUDE.md @imports the contract (double-inject)" || pass "CLAUDE.md: does not @import the contract"
  grep -q "$SENTINEL" "$CLAUDE_MD" && bad "CLAUDE.md inlines the contract (sentinel present)" || pass "CLAUDE.md: contract not inlined"
fi
[ -f "$ROOT/README.md" ] && grep -q "operating-contract.md" "$ROOT/README.md" && pass "README documents context delivery" || bad "README does not document context delivery"

echo "== resolver is deterministic (OP_STATE_FILE override, else \$HOME default) =="
r_override="$(OP_STATE_FILE=/canonical/probe.md bash "$RESOLVER" 2>/dev/null)"
[ "$r_override" = "/canonical/probe.md" ] && pass "resolver honours OP_STATE_FILE" || bad "resolver ignored OP_STATE_FILE (got '$r_override')"
r_home="$(OP_STATE_FILE="" HOME=/canon/home bash "$RESOLVER" 2>/dev/null)"
[ "$r_home" = "/canon/home/.op-state.local.md" ] && pass "resolver defaults to \$HOME/.op-state.local.md" || bad "resolver \$HOME default wrong (got '$r_home')"

echo "== hook: contract always emitted =="
EMPTY_HOME="$(mktemp -d)"
out_none="$(cd /tmp && CLAUDE_PLUGIN_ROOT="$ROOT" OP_STATE_FILE="" HOME="$EMPTY_HOME" bash "$HOOK" 2>/dev/null)"; rc=$?
[ "$rc" = 0 ] && pass "hook exit 0" || bad "hook non-zero exit ($rc)"
printf '%s' "$out_none" | grep -qi "disclosure" && pass "hook emits contract" || bad "hook did not emit contract"

echo "== hook: MISSING scratchpad → NOT POPULATED directive at start (not silence) =="
printf '%s' "$out_none" | grep -q "canonical path:" && pass "hook flags missing scratchpad" || bad "hook did not flag missing scratchpad"
printf '%s' "$out_none" | grep -q "canonical path: $EMPTY_HOME/.op-state.local.md" && pass "hook shows canonical path to populate" || bad "hook did not show canonical path"
rmdir "$EMPTY_HOME" 2>/dev/null || true

echo "== hook: UNPOPULATED template → NOT POPULATED (not injected as if real) =="
TMPL="$(mktemp)"; printf '# state (TEMPLATE)\n## Instance\n- url: <https://host>\n' > "$TMPL"
out_tmpl="$(cd /tmp && CLAUDE_PLUGIN_ROOT="$ROOT" OP_STATE_FILE="$TMPL" bash "$HOOK" 2>/dev/null)"
printf '%s' "$out_tmpl" | grep -q "canonical path: $TMPL" && pass "hook flags template as unpopulated" || bad "hook treated template as populated"
rm -f "$TMPL"

echo "== hook: POPULATED via OP_STATE_FILE; reader==writer path; not flagged =="
TMP_SP="$(mktemp)"; printf '## Projects\n- Probe #99 -> marker-XYZ\n' > "$TMP_SP"
rpath="$(OP_STATE_FILE="$TMP_SP" bash "$RESOLVER")"
out_sp="$(cd /tmp && CLAUDE_PLUGIN_ROOT="$ROOT" OP_STATE_FILE="$TMP_SP" bash "$HOOK" 2>/dev/null)"
printf '%s' "$out_sp" | grep -q "path: $rpath" && pass "hook path == resolver path (reader==writer)" || bad "hook path != resolver path"
printf '%s' "$out_sp" | grep -q "marker-XYZ"   && pass "hook injects scratchpad content"            || bad "hook did not inject content"
printf '%s' "$out_sp" | grep -q "canonical path:" && bad "populated file wrongly flagged"             || pass "populated file not flagged"
rm -f "$TMP_SP"

echo "== hook: POPULATED via \$HOME default; a stray file in cwd is IGNORED (no guessing) =="
TMP_HOME="$(mktemp -d)"; printf '## Projects\n- HomeProbe #1 -> home-marker-ABC\n' > "$TMP_HOME/.op-state.local.md"
STRAY_CWD="$(mktemp -d)"; printf '## Projects\n- STRAY-SHOULD-NOT-APPEAR\n' > "$STRAY_CWD/.op-state.local.md"
out_home="$(cd "$STRAY_CWD" && CLAUDE_PLUGIN_ROOT="$ROOT" OP_STATE_FILE="" HOME="$TMP_HOME" bash "$HOOK" 2>/dev/null)"
printf '%s' "$out_home" | grep -q "home-marker-ABC"        && pass "hook resolves scratchpad via \$HOME" || bad "hook did not resolve via \$HOME"
printf '%s' "$out_home" | grep -q "STRAY-SHOULD-NOT-APPEAR" && bad "hook picked up a cwd file (guessing!)" || pass "hook ignores stray cwd file (deterministic)"
rm -rf "$TMP_HOME" "$STRAY_CWD"

echo
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "$fail CHECK(S) FAILED"; fi
exit "$fail"
