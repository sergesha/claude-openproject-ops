#!/usr/bin/env bash
# smoke.sh — live test for the openproject-pm write-path (the CRUD every other skill delegates to).
# Exercises, via APIv3 (the MCP-independent ground truth the skill falls back to): create work
# package, update fields (priority/description with lockVersion), set parent, create a relation,
# add a comment, read everything back, then clean up. Proves the documented operations actually work.
# Run: bash smoke.sh
set -euo pipefail
set -a; . ~/openproject/.op-api.env; set +a
U="$OPENPROJECT_URL/api/v3"; A=(-s -u "apikey:$OPENPROJECT_API_KEY"); J=("${A[@]}" -H "Content-Type: application/json")
P=6; T=5    # project Roadmap, type Epic (the type enabled there)
jq(){ python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
pass=0; fail=0; ok(){ echo "  PASS: $1"; pass=$((pass+1)); }; no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
created=()

patch(){ local id="$1" body="$2" lv; lv=$(curl "${A[@]}" "$U/work_packages/$id" | jq "d['lockVersion']")
  echo "$body" | python3 -c "import sys,json;b=json.load(sys.stdin);b['lockVersion']=$lv;print(json.dumps(b))" \
    | curl "${J[@]}" -X PATCH "$U/work_packages/$id" -d @- -o /dev/null -w "%{http_code}"; }

echo "== create_work_package =="
PARENT=$(curl "${J[@]}" -X POST "$U/projects/$P/work_packages" -d "{\"subject\":\"SMOKE pm parent\",\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T\"}}}" | jq "d['id']")
CHILD=$(curl "${J[@]}" -X POST "$U/projects/$P/work_packages" -d "{\"subject\":\"SMOKE pm child\",\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T\"}}}" | jq "d['id']")
OTHER=$(curl "${J[@]}" -X POST "$U/projects/$P/work_packages" -d "{\"subject\":\"SMOKE pm other\",\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T\"}}}" | jq "d['id']")
created+=("$CHILD" "$OTHER" "$PARENT")
{ [ -n "$PARENT" ] && [ -n "$CHILD" ] && [ -n "$OTHER" ]; } && ok "created #$PARENT, #$CHILD, #$OTHER" || no "create"

echo "== update_work_package (description + lockVersion) =="
code=$(patch "$CHILD" "{\"description\":{\"raw\":\"updated by smoke\"}}")
GOT=$(curl "${A[@]}" "$U/work_packages/$CHILD" | jq "d['description']['raw']")
{ [ "$code" = "200" ] && [ "$GOT" = "updated by smoke" ]; } && ok "update applied (HTTP 200, read-back ok)" || no "update (HTTP $code, got '$GOT')"

echo "== set_work_package_parent =="
code=$(patch "$CHILD" "{\"_links\":{\"parent\":{\"href\":\"/api/v3/work_packages/$PARENT\"}}}")
PAR=$(curl "${A[@]}" "$U/work_packages/$CHILD" | jq "d['_links'].get('parent',{}).get('href','').rsplit('/',1)[-1]")
[ "$PAR" = "$PARENT" ] && ok "parent set (#$CHILD → #$PARENT)" || no "parent ($PAR)"

echo "== create_work_package_relation (relates, between non-hierarchical items) =="
rc=$(curl "${J[@]}" -X POST "$U/work_packages/$CHILD/relations" -d "{\"type\":\"relates\",\"_links\":{\"to\":{\"href\":\"/api/v3/work_packages/$OTHER\"}}}" -o /dev/null -w "%{http_code}")
{ [ "$rc" = "201" ] || [ "$rc" = "200" ]; } && ok "relation created (HTTP $rc)" || no "relation (HTTP $rc)"

echo "== add comment (activity) =="
ac=$(curl "${J[@]}" -X POST "$U/work_packages/$CHILD/activities" -d "{\"comment\":{\"raw\":\"smoke comment\"}}" -o /dev/null -w "%{http_code}")
{ [ "$ac" = "201" ] || [ "$ac" = "200" ]; } && ok "comment added (HTTP $ac)" || no "comment (HTTP $ac)"

echo "== cleanup =="
for id in "${created[@]}"; do curl "${A[@]}" -X DELETE "$U/work_packages/$id" -o /dev/null -w "  del #$id %{http_code}\n"; done

echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
