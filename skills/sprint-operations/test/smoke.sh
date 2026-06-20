#!/usr/bin/env bash
# smoke.sh — live test for sprint-operations close mechanics (APIv3 + Rails for versions).
# Validates the operations /op-sprint-close depends on: close a done item, carry an incomplete item
# to the next sprint version, and create a retro improvement work package. Self-cleaning.
# (The DoD-gating *judgment* — refusing to close a DoD-failing item — is covered by the RED/GREEN
#  subagent test, not here; this proves the underlying writes work.)
# Run: bash smoke.sh
set -euo pipefail
set -a; . ~/openproject/.op-api.env; set +a
U="$OPENPROJECT_URL/api/v3"; A=(-s -u "apikey:$OPENPROJECT_API_KEY"); J=("${A[@]}" -H "Content-Type: application/json")
P=6; T=5; S_CLOSED=12
RB(){ (cd ~/openproject/openproject-docker-compose && docker compose exec -T web bundle exec rails runner "$1") 2>/dev/null; }
jq(){ python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
pass=0; fail=0; ok(){ echo "  PASS: $1"; pass=$((pass+1)); }; no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
created=()
patch(){ local id="$1" body="$2" lv; lv=$(curl "${A[@]}" "$U/work_packages/$id" | jq "d['lockVersion']")
  echo "$body" | python3 -c "import sys,json;b=json.load(sys.stdin);b['lockVersion']=$lv;print(json.dumps(b))" \
    | curl "${J[@]}" -X PATCH "$U/work_packages/$id" -d @- -o /dev/null -w "%{http_code}"; }
mkwp(){ curl "${J[@]}" -X POST "$U/projects/$P/work_packages" -d "{\"subject\":\"$1\",\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T\"},\"version\":{\"href\":\"/api/v3/versions/$2\"}}}" | jq "d['id']"; }

echo "== create sprint + next versions (Rails) =="
VS=$(RB 'puts Version.create!(project_id:6,name:"SMOKE-sprint",status:"open").id' | tr -d '[:space:]')
VN=$(RB 'puts Version.create!(project_id:6,name:"SMOKE-next",status:"open").id' | tr -d '[:space:]')
echo "  sprint=$VS next=$VN"

DONE1=$(mkwp "SMOKE done item" "$VS"); INC1=$(mkwp "SMOKE incomplete item" "$VS"); created+=("$DONE1" "$INC1")

echo "== close the done item =="
code=$(patch "$DONE1" "{\"_links\":{\"status\":{\"href\":\"/api/v3/statuses/$S_CLOSED\"}}}")
ST=$(curl "${A[@]}" "$U/work_packages/$DONE1" | jq "d['_links']['status']['href'].rsplit('/',1)[-1]")
[ "$ST" = "$S_CLOSED" ] && ok "done item closed" || no "close ($ST)"

echo "== carry the incomplete item to next version =="
code=$(patch "$INC1" "{\"_links\":{\"version\":{\"href\":\"/api/v3/versions/$VN\"}}}")
NV=$(curl "${A[@]}" "$U/work_packages/$INC1" | jq "d['_links']['version']['href'].rsplit('/',1)[-1]")
[ "$NV" = "$VN" ] && ok "incomplete carried to next version" || no "carry-over ($NV)"
# carry-over reason as a comment
rc=$(curl "${J[@]}" -X POST "$U/work_packages/$INC1/activities" -d '{"comment":{"raw":"Carry-over: ran out of sprint capacity"}}' -o /dev/null -w "%{http_code}")
{ [ "$rc" = "201" ] || [ "$rc" = "200" ]; } && ok "carry-over reason recorded" || no "carry-over comment ($rc)"

echo "== create a retro improvement WP =="
RETRO=$(mkwp "SMOKE retro: tighten estimation" "$VN"); created+=("$RETRO")
[ -n "$RETRO" ] && ok "retro improvement WP created (#$RETRO)" || no "retro WP"

echo "== cleanup =="
for id in "${created[@]}"; do curl "${A[@]}" -X DELETE "$U/work_packages/$id" -o /dev/null -w "  del #$id %{http_code}\n"; done
RB "Version.where(id:[$VS,$VN]).destroy_all" >/dev/null && echo "  versions deleted"
echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
