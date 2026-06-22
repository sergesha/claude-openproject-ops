#!/usr/bin/env bash
# check-cookbook.sh — structural + leak checks for docs/cookbook recipes.
# Validates: required files exist, recipe template-conformance, link integrity
# (file-resolvable refs), and no host/secret leakage. Exit 0 = all pass.
set -uo pipefail
cd "$(dirname "$0")/.."   # repo root
fail=0
pass(){ printf '  PASS  %s\n' "$1"; }
bad(){ printf '  FAIL  %s\n' "$1"; fail=1; }

INDEX=docs/cookbook/start-here.md
RECIPE=docs/cookbook/scattered-thoughts-to-predictable-delivery.md
NAV=skills/startup-navigator/SKILL.md

echo "== files exist =="
for f in "$INDEX" "$RECIPE"; do
  [ -f "$f" ] && pass "$f" || bad "missing $f"
done

echo "== index ($INDEX) =="
if [ -f "$INDEX" ]; then
  grep -q '## Phase N — <Name>' "$INDEX" && pass "template block present" || bad "template block missing"
  grep -q 'scattered-thoughts-to-predictable-delivery.md' "$INDEX" && pass "recipe #1 in TOC" || bad "recipe #1 not in TOC"
  grep -q 'CLAUDE.md' "$INDEX" && pass "standing rules reference CLAUDE.md" || bad "CLAUDE.md reference missing"
fi

echo "== recipe template-conformance ($RECIPE) =="
if [ -f "$RECIPE" ]; then
  phases=$(grep -c '^## Phase ' "$RECIPE")
  [ "$phases" -eq 8 ] && pass "8 phase headings" || bad "expected 8 phase headings, found $phases"
  for label in '\*\*Outcome:\*\*' '\*\*You are here when:\*\*' '\*\*Why this phase:\*\*' \
    '\*\*The decision you make:\*\*' '\*\*Method:\*\*' '\*\*Make it real:\*\*' \
    '\*\*Done when:\*\*'; do
    n=$(grep -c "$label" "$RECIPE")
    [ "$n" -ge 8 ] && pass "$label x$n" || bad "$label appears ${n}x (need >=8)"
  done
  grep -qi 'loop' "$RECIPE" && pass "loop noted" || bad "loop note missing"
fi

echo "== navigator skill consistency ($NAV) =="
if [ -f "$NAV" ]; then
  pass "$NAV exists"
  grep -q "$(basename "$RECIPE")" "$NAV" && pass "navigator points at the recipe" || bad "navigator missing recipe reference"
  if [ -f "$RECIPE" ]; then
    while IFS= read -r name; do
      grep -qF "$name" "$NAV" && pass "phase '$name' mapped" || bad "phase '$name' missing from navigator"
    done < <(grep '^## Phase ' "$RECIPE" | sed 's/^## Phase [0-9]* — //')
  fi
else
  bad "missing $NAV"
fi

echo "== link integrity (file-resolvable refs) =="
for f in "$INDEX" "$RECIPE" "$NAV"; do
  [ -f "$f" ] || continue
  for cmd in $(grep -oE '/op-[a-z-]+' "$f" | sort -u); do
    p="commands${cmd}.md"
    [ -f "$p" ] && pass "$f -> $p" || bad "$f links $cmd but $p missing"
  done
  for path in $(grep -oE '(docs|skills|commands|scripts)/[A-Za-z0-9_./-]+' "$f" | sed 's/[.,):]*$//' | sort -u); do
    [ -e "$path" ] && pass "$f -> $path" || bad "$f links $path (missing)"
  done
done

echo "== no-leak (host/secret patterns must be absent) =="
LEAK='apikey:|OPENPROJECT_API_KEY|SECRET_KEY_BASE|([0-9]{1,3}\.){3}[0-9]{1,3}|op\.[a-z0-9-]+\.[a-z]{2,}'
for f in "$INDEX" "$RECIPE" "$NAV"; do
  [ -f "$f" ] || continue
  if grep -nEi "$LEAK" "$f" >/dev/null; then bad "$f contains host/secret-like text"; else pass "$f clean"; fi
done

echo
if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASS"; else echo "CHECKS FAILED"; fi
exit "$fail"
