#!/usr/bin/env bash
# metrics.sh — compute delivery metrics for one OpenProject project from APIv3 (MCP-independent).
# Velocity (rolling window of closed versions), current-sprint snapshot, throughput, and a status
# distribution (snapshot CFD) — all from the live data, with an explicit "done" definition.
#
#   done        = status.isClosed AND status.name != "Rejected"   (Rejected is closed-but-not-done)
#   velocity    = mean done-story-points over the last WINDOW *closed* versions
#   throughput  = count of done items updated within the last DAYS
#   current     = the open version's committed / done / remaining story points
#
# Usage: metrics.sh PROJECT_ID [WINDOW=3] [DAYS=14]
# Requires ~/openproject/.op-api.env (OPENPROJECT_URL, OPENPROJECT_API_KEY). Outputs a readable
# summary then a JSON blob (last line) for programmatic use. Degrades gracefully when data is thin.
set -euo pipefail
[ -f ~/openproject/.op-api.env ] || { echo "ERROR: ~/openproject/.op-api.env not found" >&2; exit 1; }
set -a; . ~/openproject/.op-api.env; set +a
: "${OPENPROJECT_URL:?OPENPROJECT_URL not set in .op-api.env}"
: "${OPENPROJECT_API_KEY:?OPENPROJECT_API_KEY not set in .op-api.env}"
U="$OPENPROJECT_URL/api/v3"; A=(-s -u "apikey:$OPENPROJECT_API_KEY")
P="${1:?project id required}"; WINDOW="${2:-3}"; DAYS="${3:-14}"
[[ "$P" =~ ^[0-9]+$ ]] || { echo "ERROR: PROJECT_ID must be numeric" >&2; exit 1; }
[[ "$WINDOW" =~ ^[0-9]+$ ]] || { echo "ERROR: WINDOW must be numeric" >&2; exit 1; }
[[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "ERROR: DAYS must be numeric" >&2; exit 1; }

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# status id -> {name, isClosed}
curl "${A[@]}" "$U/statuses" > "$TMPDIR/statuses.json"
# versions of the project (id, name, status open/closed/locked)
curl "${A[@]}" "$U/projects/$P/versions" > "$TMPDIR/versions.json"
# all work packages of the project (paginated). The status filter with operator "*"
# overrides the default "open only" query so CLOSED (done) items are included — essential, since
# velocity/throughput are computed from done work.
# Decoded: [{"status":{"operator":"*","values":[]}}]  — include closed items
ALLSTATUS='%5B%7B%22status%22%3A%7B%22operator%22%3A%22*%22%2C%22values%22%3A%5B%5D%7D%7D%5D'
PAGE=1; PAGESIZE=1000
while true; do
  OFFSET=$(( (PAGE - 1) * PAGESIZE ))
  curl "${A[@]}" "$U/projects/$P/work_packages?pageSize=$PAGESIZE&offset=$OFFSET&filters=$ALLSTATUS" \
    > "$TMPDIR/wps_page_${PAGE}.json"
  TOTAL=$(python3 -c "import sys,json; print(json.load(open(sys.argv[1]))['total'])" "$TMPDIR/wps_page_${PAGE}.json") \
    || { echo "ERROR: failed to parse API response" >&2; exit 1; }
  if [ $(( OFFSET + PAGESIZE )) -ge "$TOTAL" ]; then break; fi
  PAGE=$((PAGE + 1))
done

python3 - "$WINDOW" "$DAYS" "$P" "$TMPDIR" <<'PY'
import sys, json, datetime, os, glob
window, days = int(sys.argv[1]), int(sys.argv[2])
project_id = sys.argv[3]
tmpdir = sys.argv[4]
S = json.load(open(os.path.join(tmpdir, 'statuses.json')))
V = json.load(open(os.path.join(tmpdir, 'versions.json')))
# merge paginated work-package pages
wp_pages = sorted(glob.glob(os.path.join(tmpdir, 'wps_page_*.json')))
W = json.load(open(wp_pages[0]))
for pg in wp_pages[1:]:
    W['_embedded']['elements'] += json.load(open(pg))['_embedded']['elements']

st = {}                                   # status id -> (name, isClosed)
for s in S['_embedded']['elements']:
    st[str(s['id'])] = (s['name'], bool(s.get('isClosed')))
def is_done(sid):
    n, c = st.get(str(sid), ('', False)); return c and n != 'Rejected'

ver = {}                                  # version id -> {name, status}
for v in V['_embedded']['elements']:
    ver[str(v['id'])] = {'name': v['name'], 'status': v.get('status', 'open')}

def sid_of(wp):  h=(wp['_links'].get('status') or {}).get('href','');  return h.rsplit('/',1)[-1] if h else ''
def vid_of(wp):  h=(wp['_links'].get('version') or {}).get('href','') or ''; return h.rsplit('/',1)[-1] if h else ''
def sp_of(wp):   v=wp.get('storyPoints');  return v if isinstance(v,(int,float)) else 0

wps = W['_embedded']['elements']
now = datetime.datetime.now(datetime.timezone.utc)

# velocity over closed versions
per_ver = {}                              # vid -> done SP
for wp in wps:
    vid = vid_of(wp)
    if vid and ver.get(vid, {}).get('status') == 'closed' and is_done(sid_of(wp)):
        per_ver[vid] = per_ver.get(vid, 0) + sp_of(wp)
closed_vids = [v for v in ver if ver[v]['status'] == 'closed']
# order closed versions by id (proxy for recency) and take the last WINDOW
recent = sorted(closed_vids, key=lambda x: int(x))[-window:]
vel_samples = [per_ver.get(v, 0) for v in recent]
velocity = round(sum(vel_samples)/len(vel_samples), 1) if vel_samples else None

# current sprint = open version(s); report the one with most committed SP
open_vids = [v for v in ver if ver[v]['status'] == 'open']
def snapshot(vid):
    committed = done = 0
    for wp in wps:
        if vid_of(wp) == vid:
            sp = sp_of(wp); committed += sp
            if is_done(sid_of(wp)): done += sp
    return {'version': ver[vid]['name'], 'committed': committed, 'done': done,
            'remaining': committed - done,
            'pct': round(100*done/committed) if committed else 0}
current = max((snapshot(v) for v in open_vids), key=lambda s: s['committed'], default=None)

# throughput: done items updated within DAYS
thr = 0
for wp in wps:
    if is_done(sid_of(wp)):
        try:
            u = datetime.datetime.fromisoformat(wp['updatedAt'].replace('Z','+00:00'))
            if (now - u).days <= days: thr += 1
        except Exception: pass

# status distribution snapshot (CFD bucket)
dist = {}
for wp in wps:
    n = st.get(sid_of(wp), ('?', False))[0]; dist[n] = dist.get(n, 0) + 1

ready_runway = None
if velocity and current is not None:
    ready_runway = round(current['remaining']/velocity, 1) if velocity else None

print(f"== Delivery metrics (project {project_id}) ==")
print(f"Done = status.isClosed and name != 'Rejected'. Velocity window = last {window} closed versions.")
print(f"Velocity        : {velocity if velocity is not None else 'insufficient data (no closed versions with points)'}"
      + (f"  samples={vel_samples}" if vel_samples else ''))
if current: print(f"Current sprint  : {current['version']} — committed {current['committed']} / done {current['done']} / remaining {current['remaining']} ({current['pct']}%)")
else:       print("Current sprint  : no open version with work")
print(f"Throughput      : {thr} done items in last {days} days")
print(f"Status snapshot : " + (', '.join(f'{k}:{v}' for k,v in sorted(dist.items())) or 'no items'))
print(json.dumps({'velocity': velocity, 'velocity_samples': vel_samples, 'current': current,
                  'throughput': thr, 'days': days, 'window': window, 'status_distribution': dist}))
PY
