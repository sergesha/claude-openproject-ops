#!/usr/bin/env bash
# release-smoke.sh — live test for /op-release "notes" logic (APIv3 + Rails for the release Version).
# Builds a release Version with done + rejected items, generates notes (done items only, Rejected
# excluded), asserts the right items appear. Self-cleaning. See docs/release-management.md.
# Run: bash release-smoke.sh
set -euo pipefail
set -a; . ~/openproject/.op-api.env; set +a
U="$OPENPROJECT_URL/api/v3"; A=(-s -u "apikey:$OPENPROJECT_API_KEY"); J=("${A[@]}" -H "Content-Type: application/json")
P=6; T=5; S_CLOSED=12; S_REJECTED=14
RB(){ (cd ~/openproject/openproject-docker-compose && docker compose exec -T web bundle exec rails runner "$1") 2>/dev/null; }
jq(){ python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
pass=0; fail=0; ok(){ echo "  PASS: $1"; pass=$((pass+1)); }; no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
created=()
patch(){ local id="$1" body="$2" lv; lv=$(curl "${A[@]}" "$U/work_packages/$id" | jq "d['lockVersion']")
  echo "$body" | python3 -c "import sys,json;b=json.load(sys.stdin);b['lockVersion']=$lv;print(json.dumps(b))" \
    | curl "${J[@]}" -X PATCH "$U/work_packages/$id" -d @- -o /dev/null -w "%{http_code}"; }
mkwp(){ curl "${J[@]}" -X POST "$U/projects/$P/work_packages" -d "{\"subject\":\"$1\",\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T\"},\"version\":{\"href\":\"/api/v3/versions/$2\"}}}" | jq "d['id']"; }

echo "== cut a release Version (Rails) =="
REL=$(RB 'puts Version.create!(project_id:6,name:"SMOKE-v1.0.0",status:"open",description:"release").id' | tr -d '[:space:]')
echo "  release version=$REL"

SHIP1=$(mkwp "SMOKE shipped feature A" "$REL"); SHIP2=$(mkwp "SMOKE shipped fix B" "$REL"); REJ=$(mkwp "SMOKE rejected C" "$REL")
created+=("$SHIP1" "$SHIP2" "$REJ")
patch "$SHIP1" "{\"_links\":{\"status\":{\"href\":\"/api/v3/statuses/$S_CLOSED\"}}}" >/dev/null
patch "$SHIP2" "{\"_links\":{\"status\":{\"href\":\"/api/v3/statuses/$S_CLOSED\"}}}" >/dev/null
patch "$REJ"   "{\"_links\":{\"status\":{\"href\":\"/api/v3/statuses/$S_REJECTED\"}}}" >/dev/null

echo "== generate notes: done items in the release (isClosed & not Rejected) =="
# all items in the release version, all statuses
FILT="%5B%7B%22version%22%3A%7B%22operator%22%3A%22%3D%22%2C%22values%22%3A%5B%22$REL%22%5D%7D%7D%2C%7B%22status%22%3A%7B%22operator%22%3A%22*%22%2C%22values%22%3A%5B%5D%7D%7D%5D"
NOTES=$(curl "${A[@]}" "$U/work_packages?pageSize=100&filters=$FILT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
done=[w for w in d['_embedded']['elements']
      if (w['_links'].get('status') or {}).get('title') not in (None,'Rejected')
      and w['_links']['status']['title']=='Closed']
for w in done: print(f\"#{w['id']} {w['subject']}\")
")
echo "$NOTES" | sed 's/^/    /'
echo "$NOTES" | grep -q "SMOKE shipped feature A" && ok "shipped feature in notes" || no "feature missing"
echo "$NOTES" | grep -q "SMOKE shipped fix B" && ok "shipped fix in notes" || no "fix missing"
echo "$NOTES" | grep -q "SMOKE rejected C" && no "rejected item leaked into notes" || ok "rejected excluded from notes"
CNT=$(echo "$NOTES" | grep -c "SMOKE" || true)
[ "$CNT" -eq 2 ] && ok "exactly 2 done items noted" || no "note count = $CNT (want 2)"

echo "== cleanup =="
for id in "${created[@]}"; do curl "${A[@]}" -X DELETE "$U/work_packages/$id" -o /dev/null -w "  del #$id %{http_code}\n"; done
RB "Version.where(id:[$REL]).destroy_all" >/dev/null && echo "  release version deleted"
echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
