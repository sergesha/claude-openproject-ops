#!/usr/bin/env bash
# dedup-smoke.sh — live test of the keyword fallback path (pure APIv3, MCP-independent). Self-cleaning.
# Run: bash dedup-smoke.sh   (needs ~/openproject/.op-api.env)
set -euo pipefail
set -a; . ~/openproject/.op-api.env; set +a
U="$OPENPROJECT_URL/api/v3"
A=(-s -u "apikey:$OPENPROJECT_API_KEY")
J=("${A[@]}" -H "Content-Type: application/json")
cd "$(dirname "$0")/.."
. ./index.sh
pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
jq(){ python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
T_IDEA=8; P_INTAKE=5
created=()
cleanup(){ for id in "${created[@]:-}"; do [ -n "$id" ] && curl "${A[@]}" -X DELETE "$U/work_packages/$id" -o /dev/null -w "  del #$id HTTP %{http_code}\n"; done; }
trap cleanup EXIT

A_ID=$(curl "${J[@]}" -X POST "$U/projects/$P_INTAKE/work_packages" \
  -d "{\"subject\":\"SMOKEDEDUP export dashboard to PDF\",\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T_IDEA\"}}}" | jq "d['id']")
created+=("$A_ID"); echo "  Idea A #$A_ID"

sleep 2   # OpenProject full-text indexing can be slightly async

HITS=$(dedup_keyword_search "SMOKEDEDUP export dashboard PDF" 10)
echo "$HITS" | grep -qx "$A_ID" && ok "keyword fallback surfaces near-duplicate #$A_ID" || no "keyword search missed #$A_ID (got: $HITS)"

echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
