#!/usr/bin/env bash
# smoke.sh — live integration test for the backlog-refinement skill, pure APIv3 (MCP-independent).
# Validates the OpenProject mechanics the skill's recipe depends on:
#   - create a "dirty" backlog (oversized/no-AC, no-estimate, orphan, duplicate pair),
#   - detect each health-scorecard signal from real data (oversized, no-estimate, no-AC, orphan, dup),
#   - compute a ready-coverage % over the set (proves the rubric is computable via APIv3),
#   - perform ONE refine pass on the oversized item (write AC + set estimate ≤8 + SPLIT into children)
#     and re-check it now passes the Definition of Ready,
#   - clean up everything it created (T-cleanup).
# Estimate field = native story points (backlogs module enabled; storyPoints on story-types).
# The skill detects this at runtime; if backlogs were off it would fall back to estimatedTime/Work.
# Run: bash smoke.sh
set -euo pipefail
set -a; . ~/openproject/.op-api.env; set +a
U="$OPENPROJECT_URL/api/v3"
A=(-s -u "apikey:$OPENPROJECT_API_KEY")
J=("${A[@]}" -H "Content-Type: application/json")
pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }
jq(){ python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }

# NOTE: project Roadmap(6) only has the Epic type enabled (enabling User story would need Rails
# provisioning, which this skill deliberately avoids). The skill is type-agnostic, so the test
# uses the Epic type for every item — it validates API mechanics (estimate/AC/parent/relations/
# coverage), not type semantics.
T_STORY=5; T_EPIC=5; P=6           # Epic type, project Roadmap
DOR_MAX=8; SPLIT_AT=13              # story-point thresholds (≤8 ready, ≥13 must split)
created=()                          # work package ids to clean up (children first on delete)

mkwp(){ # subject  story-points-or-empty  description-raw  parent-id-or-empty  -> id
  local subj="$1" est="$2" desc="$3" par="$4"
  python3 - "$subj" "$est" "$desc" "$par" "$T_STORY" <<'PY' > /tmp/br_body.json
import json,sys
subj,est,desc,par,typ=sys.argv[1:6]
b={"subject":subj,"_links":{"type":{"href":f"/api/v3/types/{typ}"}}}
if desc: b["description"]={"raw":desc}
if est:  b["storyPoints"]=int(est)
if par:  b["_links"]["parent"]={"href":f"/api/v3/work_packages/{par}"}
print(json.dumps(b))
PY
  curl "${J[@]}" -X POST "$U/projects/$P/work_packages" -d @/tmp/br_body.json | jq "d['id']"
}

patch(){ # id  json-without-lockversion -> http code
  local id="$1" body="$2" lv
  lv=$(curl "${A[@]}" "$U/work_packages/$id" | jq "d['lockVersion']")
  echo "$body" | python3 -c "import sys,json;b=json.load(sys.stdin);b['lockVersion']=$lv;print(json.dumps(b))" \
    | curl "${J[@]}" -X PATCH "$U/work_packages/$id" -d @- -o /dev/null -w "%{http_code}"
}

est_of(){ # id -> integer story points (0 if none)
  curl "${A[@]}" "$U/work_packages/$1" | python3 -c "
import sys,json
d=json.load(sys.stdin); sp=d.get('storyPoints')
print(int(sp) if sp is not None else 0)"
}
has_ac(){ # id -> yes/no  (Gherkin markers in description)
  curl "${A[@]}" "$U/work_packages/$1" | python3 -c "
import sys,json; d=json.load(sys.stdin); r=(d.get('description') or {}).get('raw','') or ''
print('yes' if all(k in r for k in ('Given','When','Then')) else 'no')"
}
has_parent(){ curl "${A[@]}" "$U/work_packages/$1" | jq "'yes' if d['_links'].get('parent',{}).get('href') else 'no'"; }

echo "== build a dirty backlog =="
OVERSIZED=$(mkwp "SMOKE oversized export to PDF" 21 "" "");            created+=("$OVERSIZED"); echo "  #$OVERSIZED oversized(21h,no AC)"
NOEST=$(mkwp "SMOKE app should be faster" "" "" "");                   created+=("$NOEST");    echo "  #$NOEST no-estimate"
ORPHAN=$(mkwp "SMOKE improve onboarding" 5 "" "");                     created+=("$ORPHAN");   echo "  #$ORPHAN orphan(no epic)"
DUP1=$(mkwp "SMOKE export dashboard to PDF" 8 "Given x When y Then z" ""); created+=("$DUP1"); echo "  #$DUP1 dup-a"
DUP2=$(mkwp "SMOKE export dashboard to PDF" 13 "" "");                 created+=("$DUP2");     echo "  #$DUP2 dup-b"

echo "== T3: detect health signals from real data =="
[ "$(est_of "$OVERSIZED")" -ge "$SPLIT_AT" ] && ok "oversized detected (≥$SPLIT_AT)" || no "oversized"
[ "$(est_of "$NOEST")" -eq 0 ] && ok "no-estimate detected" || no "no-estimate"
[ "$(has_ac "$OVERSIZED")" = "no" ] && ok "no-AC detected" || no "no-AC"
[ "$(has_parent "$ORPHAN")" = "no" ] && ok "orphan (no parent) detected" || no "orphan"
# duplicate heuristic: identical normalized subjects
DUPN=$(curl "${A[@]}" "$U/work_packages/$DUP1" "$U/work_packages/$DUP2" 2>/dev/null; \
  python3 -c "
import json,urllib.request,os
h={'Authorization':None}
" 2>/dev/null || true)
S1=$(curl "${A[@]}" "$U/work_packages/$DUP1" | jq "d['subject']")
S2=$(curl "${A[@]}" "$U/work_packages/$DUP2" | jq "d['subject']")
[ "$S1" = "$S2" ] && ok "possible-duplicate detected (identical subjects, flagged not merged)" || no "duplicate detect"

echo "== T2/T4: relate the duplicate pair (relates) =="
rc=$(curl "${J[@]}" -X POST "$U/work_packages/$DUP2/relations" \
  -d "{\"type\":\"relates\",\"_links\":{\"to\":{\"href\":\"/api/v3/work_packages/$DUP1\"}}}" -o /dev/null -w "%{http_code}")
{ [ "$rc" = "201" ] || [ "$rc" = "200" ]; } && ok "duplicate relation created (HTTP $rc)" || no "relation (HTTP $rc)"

echo "== ready-coverage over the set (rubric computable) =="
READYN=0; TOTN=0
for id in "$OVERSIZED" "$NOEST" "$ORPHAN" "$DUP1" "$DUP2"; do
  TOTN=$((TOTN+1)); e=$(est_of "$id"); a=$(has_ac "$id"); p=$(has_parent "$id")
  if [ "$a" = "yes" ] && [ "$e" -gt 0 ] && [ "$e" -le "$DOR_MAX" ] && [ "$p" = "yes" ]; then READYN=$((READYN+1)); fi
done
echo "  ready coverage = $READYN/$TOTN"
[ "$READYN" -eq 0 ] && ok "dirty backlog reads 0% ready (as expected pre-refine)" || no "coverage baseline ($READYN ready, want 0)"

echo "== T6: REFINE the oversized item to DoR (AC + estimate≤8 + split) =="
EPIC=$(mkwp "SMOKE Reporting epic" "" "" ""); created+=("$EPIC")   # parent epic for the split children
C1=$(mkwp "SMOKE export current view to PDF" 5 "Given a dashboard When I export Then a PDF downloads" "$EPIC"); created+=("$C1")
C2=$(mkwp "SMOKE async PDF export for large dashboards" 5 "Given a large dashboard When I export Then I get an email link" "$EPIC"); created+=("$C2")
# the formerly-oversized item: give it AC, shrink estimate to 8, link under the epic
code=$(patch "$OVERSIZED" "{\"storyPoints\":8,\"description\":{\"raw\":\"Given a dashboard When I export Then a PDF downloads\"},\"_links\":{\"parent\":{\"href\":\"/api/v3/work_packages/$EPIC\"}}}")
[ "$code" = "200" ] && ok "refine PATCH applied (HTTP 200)" || no "refine PATCH (HTTP $code)"
e=$(est_of "$OVERSIZED"); a=$(has_ac "$OVERSIZED"); p=$(has_parent "$OVERSIZED")
{ [ "$a" = "yes" ] && [ "$e" -le "$DOR_MAX" ] && [ "$e" -gt 0 ] && [ "$p" = "yes" ]; } \
  && ok "refined item now passes DoR (AC=$a, est=${e}≤$DOR_MAX, parent=$p)" || no "refined item DoR (AC=$a est=$e parent=$p)"
# split children present under the epic (read the epic's children links)
KIDS=$(curl "${A[@]}" "$U/work_packages/$EPIC" | jq "len(d['_links'].get('children',[]))")
[ "$KIDS" -ge 3 ] && ok "split produced children under epic (parent has $KIDS children)" || no "split children ($KIDS)"

echo "== T7: cleanup (children before parents) =="
# delete in reverse creation order so children go before their epic
for ((i=${#created[@]}-1; i>=0; i--)); do
  id=${created[$i]}
  curl "${A[@]}" -X DELETE "$U/work_packages/$id" -o /dev/null -w "  del #$id HTTP %{http_code}\n"
done

echo "== RESULT: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
