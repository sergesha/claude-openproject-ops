#!/usr/bin/env bash
# smoke.sh — live test for delivery-metrics: build a known dataset, assert the computed metrics.
# Versions are created via Rails (APIv3 can't create them on this build); work packages, story
# points, version assignment and status transitions go through APIv3. Self-cleaning.
#
# Dataset:
#   closed version VC: done SP 5 + done SP 8 (+ a non-done SP 3 that must NOT count) -> velocity 13
#   open   version VO: committed SP 8 (in progress) + SP 2 (done)                    -> committed 10, done 2, remaining 8
#   throughput: 3 done items touched now
# Run: bash smoke.sh
set -euo pipefail
set -a; . ~/openproject/.op-api.env; set +a
U="$OPENPROJECT_URL/api/v3"; A=(-s -u "apikey:$OPENPROJECT_API_KEY"); J=("${A[@]}" -H "Content-Type: application/json")
P=6; T=5; S_CLOSED=12; S_INPROG=7    # project Roadmap, type Epic, status Closed / In progress
RB(){ (cd ~/openproject/openproject-docker-compose && docker compose exec -T web bundle exec rails runner "$1") 2>/dev/null; }
jq(){ python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
pass=0; fail=0; ok(){ echo "  PASS: $1"; pass=$((pass+1)); }; no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
created=()
trap 'for id in "${created[@]+"${created[@]}"}"; do [ -n "$id" ] && curl "${A[@]}" -X DELETE "$U/work_packages/$id" 2>/dev/null; done; [ -n "${VC:-}" ] && RB "Version.where(id:[$VC]).destroy_all" 2>/dev/null; [ -n "${VO:-}" ] && RB "Version.where(id:[$VO]).destroy_all" 2>/dev/null' EXIT

echo "== create two open versions via Rails =="
VC=$(RB 'puts Version.create!(project_id:6,name:"SMOKE-mv-closed",status:"open").id' | tr -d '[:space:]')
VO=$(RB 'puts Version.create!(project_id:6,name:"SMOKE-mv-open",status:"open").id' | tr -d '[:space:]')
echo "  VC=$VC VO=$VO"

mkwp(){ # sp version-id -> id   (Epic in project, with story points + version)
  curl "${J[@]}" -X POST "$U/projects/$P/work_packages" \
    -d "{\"subject\":\"SMOKE metric wp\",\"storyPoints\":$1,\"_links\":{\"type\":{\"href\":\"/api/v3/types/$T\"},\"version\":{\"href\":\"/api/v3/versions/$2\"}}}" | jq "d['id']"
}
setstatus(){ # id status-id
  local lv; lv=$(curl "${A[@]}" "$U/work_packages/$1" | jq "d['lockVersion']")
  curl "${J[@]}" -X PATCH "$U/work_packages/$1" -d "{\"lockVersion\":$lv,\"_links\":{\"status\":{\"href\":\"/api/v3/statuses/$2\"}}}" -o /dev/null -w "%{http_code}"
}

echo "== populate work packages =="
WPA1=$(mkwp 5 "$VC"); WPA2=$(mkwp 8 "$VC"); WPA3=$(mkwp 3 "$VC")      # VC: 2 done + 1 not-done
WPB1=$(mkwp 8 "$VO"); WPB2=$(mkwp 2 "$VO")                          # VO: 1 in-progress + 1 done
created+=("$WPA1" "$WPA2" "$WPA3" "$WPB1" "$WPB2")
for id in "$WPA1" "$WPA2" "$WPB2"; do setstatus "$id" "$S_CLOSED" >/dev/null; done   # done items
setstatus "$WPB1" "$S_INPROG" >/dev/null                                        # in-progress
# verify the done transitions actually took (workflow could block)
DONEN=0; for id in "$WPA1" "$WPA2" "$WPB2"; do
  c=$(curl "${A[@]}" "$U/work_packages/$id" | jq "d['_links']['status']['href'].rsplit('/',1)[-1]")
  [ "$c" = "$S_CLOSED" ] && DONEN=$((DONEN+1)); done
[ "$DONEN" -eq 3 ] && ok "status transitions applied (3 done)" || no "status transitions ($DONEN/3 done — workflow blocked?)"

echo "== close version VC via Rails =="
RB "Version.find($VC).update!(status:\"closed\")" >/dev/null; echo "  VC closed"

echo "== run metrics and assert =="
OUT=$(bash "$(dirname "$0")/../metrics.sh" 6)
echo "$OUT" | sed 's/^/  | /'
JSON=$(echo "$OUT" | tail -1)
VEL=$(echo "$JSON" | jq "d['velocity']")
REM=$(echo "$JSON" | jq "d['current']['remaining'] if d['current'] else 'none'")
COM=$(echo "$JSON" | jq "d['current']['committed'] if d['current'] else 'none'")
THR=$(echo "$JSON" | jq "d['throughput']")
[ "$VEL" = "13.0" ] && ok "velocity = $VEL (want 13.0)" || no "velocity = $VEL (want 13.0)"
[ "$COM" = "10" ] && ok "current committed = $COM (want 10)" || no "current committed = $COM (want 10)"
[ "$REM" = "8" ] && ok "current remaining = $REM (want 8)" || no "current remaining = $REM (want 8)"
[ "$THR" -ge 3 ] && ok "throughput = $THR (>=3 done recently)" || no "throughput = $THR (want >=3)"

echo "== cleanup =="
for id in "${created[@]}"; do curl "${A[@]}" -X DELETE "$U/work_packages/$id" -o /dev/null -w "  del wp #$id %{http_code}\n"; done
RB "Version.where(id:[$VC,$VO]).destroy_all" >/dev/null && echo "  versions deleted"
created=(); VC=; VO=

echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
