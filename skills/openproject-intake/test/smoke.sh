#!/usr/bin/env bash
# smoke.sh — live integration test for the openproject-intake skill, pure APIv3 (MCP-independent).
# Exercises: create Idea + custom fields, RICE computation (T3), Use case link, status flow,
# conversion to a Roadmap Epic with Origin marker (T2), roadmap horizon (T6), classification
# extensibility (T4). Cleans up everything it creates (T7). Run: bash smoke.sh
set -euo pipefail
set -a; . ~/openproject/.op-api.env; set +a
U="$OPENPROJECT_URL/api/v3"
# Host comes from $OPENPROJECT_URL — no hard-coded host (works for any deploy: localhost or a domain)
A=(-s -u "apikey:$OPENPROJECT_API_KEY")
J=("${A[@]}" -H "Content-Type: application/json")
pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
jq(){ python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }

# schema ids (from the instance scratchpad ## Intake schema)
T_IDEA=8; T_UC=9; T_EPIC=5; P_INTAKE=5; P_ROADMAP=6
S_APPROVED=17; S_CONVERTED=18
CF_REACH=1; CF_IMPACT=2; CF_CONF=3; CF_EFFORT=4; CF_RICE=5; CF_TRACK=6; CF_LENS=7; CF_HORIZON=8
OPT_IMPACT2=4; OPT_CONF80=7; OPT_TRACK_GEN=9; OPT_LENS_STRAT=10; OPT_HORIZON_NEXT=15
CF_TAGS=9; OPT_TAG_SEC=19; OPT_TAG_QW=21

created=()   # work package ids to clean up

patch(){ # id  json-without-lockversion  -> merges current lockVersion
  local id="$1" body="$2"
  local lv; lv=$(curl "${A[@]}" "$U/work_packages/$id" | jq "d['lockVersion']")
  echo "$body" | python3 -c "import sys,json;b=json.load(sys.stdin);b['lockVersion']=$lv;print(json.dumps(b))" \
    | curl "${J[@]}" -X PATCH "$U/work_packages/$id" -d @- -o /tmp/sm_patch.json -w "%{http_code}"
}

echo "== T2: create Idea in Intake =="
IDEA=$(curl "${J[@]}" -X POST "$U/projects/$P_INTAKE/work_packages" \
  -d "{\"subject\":\"SMOKE export dashboard to PDF\",\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T_IDEA\"}}}" | jq "d['id']")
created+=("$IDEA"); echo "  Idea #$IDEA"

echo "== set RICE inputs + Track/Lens (numeric in body, list in _links) =="
code=$(patch "$IDEA" "{\"customField$CF_REACH\":2000,\"customField$CF_EFFORT\":4,\"_links\":{\"customField$CF_IMPACT\":{\"href\":\"/api/v3/custom_options/$OPT_IMPACT2\"},\"customField$CF_CONF\":{\"href\":\"/api/v3/custom_options/$OPT_CONF80\"},\"customField$CF_TRACK\":{\"href\":\"/api/v3/custom_options/$OPT_TRACK_GEN\"},\"customField$CF_LENS\":{\"href\":\"/api/v3/custom_options/$OPT_LENS_STRAT\"}}}")
[ "$code" = "200" ] && ok "fields set (HTTP 200)" || no "fields set (HTTP $code)"

echo "== T3: RICE = 2000*2*(80/100)/4 = 800 =="
RICE=$(python3 -c "print(2000*2*(80/100)/4)")           # 800.0
code=$(patch "$IDEA" "{\"customField$CF_RICE\":$RICE}")
GOT=$(curl "${A[@]}" "$U/work_packages/$IDEA" | jq "d.get('customField$CF_RICE')")
[ "$GOT" = "800.0" ] && ok "RICE score stored = $GOT" || no "RICE score = $GOT (want 800.0)"

echo "== Tags: multi-value set (security + quick-win) =="
code=$(patch "$IDEA" "{\"_links\":{\"customField$CF_TAGS\":[{\"href\":\"/api/v3/custom_options/$OPT_TAG_SEC\"},{\"href\":\"/api/v3/custom_options/$OPT_TAG_QW\"}]}}")
TAGN=$(curl "${A[@]}" "$U/work_packages/$IDEA" | jq "len(d['_links'].get('customField$CF_TAGS',[]))")
[ "$TAGN" = "2" ] && ok "Idea carries 2 tags (multi-value)" || no "Idea tags = $TAGN (want 2)"

echo "== T2: create Use case + relate =="
UC=$(curl "${J[@]}" -X POST "$U/projects/$P_INTAKE/work_packages" \
  -d "{\"subject\":\"SMOKE user exports a board as PDF to email a client\",\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T_UC\"}}}" | jq "d['id']")
created+=("$UC"); echo "  Use case #$UC"
rc=$(curl "${J[@]}" -X POST "$U/work_packages/$IDEA/relations" \
  -d "{\"type\":\"relates\",\"_links\":{\"to\":{\"href\":\"/api/v3/work_packages/$UC\"}}}" -o /dev/null -w "%{http_code}")
[ "$rc" = "201" ] || [ "$rc" = "200" ] && ok "Idea relates Use case (HTTP $rc)" || no "relate (HTTP $rc)"

echo "== T2: flow -> Approved =="
code=$(patch "$IDEA" "{\"_links\":{\"status\":{\"href\":\"/api/v3/statuses/$S_APPROVED\"}}}")
[ "$code" = "200" ] && ok "Idea -> Approved" || no "Idea -> Approved (HTTP $code)"

echo "== conversion: Epic in Roadmap with Origin block + Horizon=Next =="
ORIGIN="Origin: Idea #$IDEA · RICE $RICE · Track General · Lens Strategic · use cases #$UC"
EPIC=$(curl "${J[@]}" -X POST "$U/projects/$P_ROADMAP/work_packages" \
  -d "{\"subject\":\"Export dashboard to PDF\",\"description\":{\"raw\":\"$ORIGIN\"},\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T_EPIC\"}}}" | jq "d['id']")
created+=("$EPIC"); echo "  Epic #$EPIC"
code=$(patch "$EPIC" "{\"_links\":{\"customField$CF_HORIZON\":{\"href\":\"/api/v3/custom_options/$OPT_HORIZON_NEXT\"}}}")
HOR=$(curl "${A[@]}" "$U/work_packages/$EPIC" | jq "d['_links'].get('customField$CF_HORIZON',{}).get('title')")
[ "$HOR" = "Next" ] && ok "T6: Epic Horizon = $HOR" || no "T6: Epic Horizon = $HOR (want Next)"
ODESC=$(curl "${A[@]}" "$U/work_packages/$EPIC" | jq "d['description']['raw']")
echo "$ODESC" | grep -q "Origin: Idea #$IDEA" && ok "Origin block present on Epic" || no "Origin block missing"

echo "== propagate Tags Idea -> Epic =="
code=$(patch "$EPIC" "{\"_links\":{\"customField$CF_TAGS\":[{\"href\":\"/api/v3/custom_options/$OPT_TAG_SEC\"},{\"href\":\"/api/v3/custom_options/$OPT_TAG_QW\"}]}}")
ETAGN=$(curl "${A[@]}" "$U/work_packages/$EPIC" | jq "len(d['_links'].get('customField$CF_TAGS',[]))")
[ "$ETAGN" = "2" ] && ok "Epic carries 2 propagated tags (cross-cutting)" || no "Epic tags = $ETAGN (want 2)"

echo "== relate Idea->Epic, mark Converted =="
curl "${J[@]}" -X POST "$U/work_packages/$IDEA/relations" -d "{\"type\":\"relates\",\"_links\":{\"to\":{\"href\":\"/api/v3/work_packages/$EPIC\"}}}" -o /dev/null
curl "${J[@]}" -X POST "$U/work_packages/$IDEA/activities" -d "{\"comment\":{\"raw\":\"Converted → Epic #$EPIC\"}}" -o /dev/null
code=$(patch "$IDEA" "{\"_links\":{\"status\":{\"href\":\"/api/v3/statuses/$S_CONVERTED}\"}}}" 2>/dev/null || true)
code=$(patch "$IDEA" "{\"_links\":{\"status\":{\"href\":\"/api/v3/statuses/$S_CONVERTED\"}}}")
ST=$(curl "${A[@]}" "$U/work_packages/$IDEA" | jq "d['_links']['status']['title']")
[ "$ST" = "Converted" ] && ok "Idea status = $ST" || no "Idea status = $ST (want Converted)"

echo "== T4: classification extensibility (add a Track option, then remove) =="
ADDED=$(cd ~/openproject/openproject-docker-compose && docker compose exec -T web bundle exec rails runner '
  cf=CustomField.find(6); o=cf.custom_options.create!(value:"SMOKE-track"); puts o.id' 2>/dev/null | tr -d "[:space:]")
LISTED=$(cd ~/openproject/openproject-docker-compose && docker compose exec -T web bundle exec rails runner '
  puts CustomField.find(6).custom_options.pluck(:value).include?("SMOKE-track")' 2>/dev/null | grep -o true || true)
[ "$LISTED" = "true" ] && ok "new Track value selectable (extensible)" || no "Track extensibility"
cd ~/openproject/openproject-docker-compose && docker compose exec -T web bundle exec rails runner "CustomOption.find($ADDED).destroy" >/dev/null 2>&1 || true

echo "== T7: cleanup =="
for id in "${created[@]}"; do curl "${A[@]}" -X DELETE "$U/work_packages/$id" -o /dev/null -w "  del #$id HTTP %{http_code}\n"; done

echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
