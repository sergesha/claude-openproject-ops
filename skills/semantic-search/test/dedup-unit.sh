#!/usr/bin/env bash
# dedup-unit.sh — pure unit tests for dedup helpers (no OpenProject instance needed). Run: bash dedup-unit.sh
set -euo pipefail
cd "$(dirname "$0")/.."
. ./index.sh
pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
eq(){ [ "$2" = "$3" ] && ok "$1" || no "$1 (got '$2' want '$3')"; }

eq "text joins title+summary" "$(dedup_text 'Export to PDF' 'user exports a board')" "Export to PDF. user exports a board"
eq "text title-only when summary empty" "$(dedup_text '  Export   to PDF ' '')" "Export to PDF"

H1=$(dedup_hash 'Export to PDF' 'user exports a board')
H2=$(dedup_hash 'export TO   pdf' 'USER exports a board')   # case/whitespace variant
eq "hash normalized (case+ws insensitive)" "$H1" "$H2"
[ ${#H1} -eq 16 ] && ok "hash is 16 hex chars" || no "hash len ${#H1} (want 16)"
H3=$(dedup_hash 'Export to CSV' 'user exports a board')
[ "$H1" != "$H3" ] && ok "different text -> different hash" || no "hash collision on different text"

eq "decide missing" "$(dedup_decide no  no  no )" "missing"
eq "decide fresh"   "$(dedup_decide yes no  yes)" "fresh"
eq "decide changed" "$(dedup_decide yes yes yes)" "changed"
eq "decide nontext" "$(dedup_decide yes yes no )" "nontext"

echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
