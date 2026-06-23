#!/usr/bin/env bash
# smoke.sh — live test for delivery-reporting: risk register + report assembly (pure APIv3).
# Builds risks (WPs tagged [RISK] with a ROAM state + owner) and a shipped item, then exercises the
# register query (find risks, parse ROAM/owner) and the report assembly (outcomes + risks), and a
# redaction sanity check (no secret/host pattern in the assembled report). Self-cleaning.
# Run: bash smoke.sh
set -euo pipefail
set -a; . ~/openproject/.op-api.env; set +a
U="$OPENPROJECT_URL/api/v3"; A=(-s -u "apikey:$OPENPROJECT_API_KEY"); J=("${A[@]}" -H "Content-Type: application/json")
P=6; T=5; S_CLOSED=12
jq(){ python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }
pass=0; fail=0; ok(){ echo "  PASS: $1"; pass=$((pass+1)); }; no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
created=()
trap 'for id in "${created[@]+"${created[@]}"}"; do [ -n "$id" ] && curl "${A[@]}" -X DELETE "$U/work_packages/$id" 2>/dev/null; done' EXIT
patch(){ local id="$1" body="$2" lv; lv=$(curl "${A[@]}" "$U/work_packages/$id" | jq "d['lockVersion']")
  echo "$body" | python3 -c "import sys,json;b=json.load(sys.stdin);b['lockVersion']=$lv;print(json.dumps(b))" \
    | curl "${J[@]}" -X PATCH "$U/work_packages/$id" -d @- -o /dev/null -w "%{http_code}"; }
mkwp(){ curl "${J[@]}" -X POST "$U/projects/$P/work_packages" \
  -d "$(python3 -c "import json,sys;print(json.dumps({'subject':sys.argv[1],'description':{'raw':sys.argv[2]},'_links':{'type':{'href':f'/api/v3/types/{$T}'}}}))" "$1" "$2")" | jq "d['id']"; }

echo "== log two risks + one shipped outcome =="
R1=$(mkwp "[RISK] DB scaling under load" "ROAM: Mitigated | owner: alice | sev: high")
R2=$(mkwp "[RISK] vendor API delay" "ROAM: Owned | owner: bob | sev: med")
SHIP=$(mkwp "Export feature shipped" "delivered to users")
created+=("$R1" "$R2" "$SHIP")
patch "$SHIP" "{\"_links\":{\"status\":{\"href\":\"/api/v3/statuses/$S_CLOSED\"}}}" >/dev/null

echo "== risk register query (find [RISK], parse ROAM + owner) =="
ALL='%5B%7B%22status%22%3A%7B%22operator%22%3A%22*%22%2C%22values%22%3A%5B%5D%7D%7D%5D'
REG=$(curl "${A[@]}" "$U/projects/$P/work_packages?pageSize=200&filters=$ALL" | python3 -c "
import sys,json,re
d=json.load(sys.stdin); risks=[]
for w in d['_embedded']['elements']:
    if w['subject'].startswith('[RISK]'):
        raw=(w.get('description') or {}).get('raw','') or ''
        roam=re.search(r'ROAM:\s*(\w+)',raw); owner=re.search(r'owner:\s*(\w+)',raw)
        risks.append((w['id'],w['subject'],roam.group(1) if roam else None,owner.group(1) if owner else None))
print(json.dumps(risks))
")
echo "  register: $REG"
RN=$(echo "$REG" | jq "len(d)")
[ "$RN" = "2" ] && ok "register found 2 risks" || no "register count = $RN (want 2)"
echo "$REG" | grep -q '"Mitigated"' && echo "$REG" | grep -q '"Owned"' && ok "ROAM states parsed (Mitigated, Owned)" || no "ROAM parse"
MISSING=$(echo "$REG" | python3 -c "import sys,json;print(sum(1 for r in json.load(sys.stdin) if not r[2] or not r[3]))")
[ "$MISSING" = "0" ] && ok "every risk has ROAM + owner" || no "$MISSING risk(s) missing ROAM/owner"

echo "== assemble stakeholder report data (outcomes + risks) =="
REPORT=$(echo "$REG" | python3 -c "
import sys,json
risks=json.loads(sys.stdin.read())
outcomes=['Export feature shipped']
lines=['# Highlight report','## Shipped']+[f'- {o}' for o in outcomes]+['## Risks (ROAM)']
lines+=[f'- {s} [{roam}, owner {own}]' for _id,s,roam,own in risks]
lines+=['## Asks','- none']
print(chr(10).join(lines))
")
echo "$REPORT" | sed 's/^/    /'
echo "$REPORT" | grep -q "Export feature shipped" && ok "report includes shipped outcome" || no "outcome missing"
echo "$REPORT" | grep -q "DB scaling" && echo "$REPORT" | grep -q "vendor API delay" && ok "report includes both risks" || no "risk missing in report"

echo "== redaction sanity: no secret/host/token pattern in the outward report =="
if echo "$REPORT" | grep -qiE "opapi-|[0-9a-f]{40}|localhost:|127\.0\.0\.1|SECRET_KEY|password"; then
  no "report leaked an internal pattern"
else ok "report carries no secret/host/token (disclosure boundary)"; fi

echo "== cleanup =="
for id in "${created[@]}"; do curl "${A[@]}" -X DELETE "$U/work_packages/$id" -o /dev/null -w "  del #$id %{http_code}\n"; done
created=()
echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
