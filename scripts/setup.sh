#!/usr/bin/env bash
#
# setup.sh — one-command, idempotent deploy of self-hosted OpenProject Community Edition
# via the official opf/openproject-docker-compose stack (slim images).
#
# Re-running is safe: an existing .env (and its SECRET_KEY_BASE) is preserved, the repo is
# updated in place, and the stack is reconciled. This is the portable artifact behind the
# openproject-devops skill and the /op-setup command — tune via env vars, not edits.
#
# Usage:
#   ./setup.sh                      # deploy with defaults
#   OP_PORT=0.0.0.0:8080 ./setup.sh # expose on all interfaces
#   OP_LOW_MEM=false ./setup.sh     # skip small-box tuning
#
# Tunables (env var = default):
#   OP_DIR     = $HOME/openproject/openproject-docker-compose   # deploy workspace (gitignored data lives here)
#   OP_BRANCH  = stable/17                                       # compose repo branch
#   OP_TAG     = 17-slim                                         # OpenProject image tag (must be -slim)
#   OP_PORT    = 127.0.0.1:8080                                  # host bind for the proxy (ip:port or port)
#   OP_HOST    = localhost:8080                                  # OPENPROJECT_HOST__NAME (how the browser reaches it)
#   OP_HTTPS   = false                                           # true if terminating TLS in-app/at proxy
#   OP_LOW_MEM = true                                            # inject low-memory tuning (1 web worker, fewer threads)
#   OP_PULL    = always                                          # docker compose --pull policy (always|missing|never)
#   OP_WAIT    = 600                                             # seconds to wait for first-boot health
#   OP_MOBILE_OAUTH = true                                       # enable the built-in OAuth app so the OpenProject mobile app can log in
#
set -euo pipefail

OP_DIR="${OP_DIR:-$HOME/openproject/openproject-docker-compose}"
OP_REPO="${OP_REPO:-https://github.com/opf/openproject-docker-compose.git}"
OP_BRANCH="${OP_BRANCH:-stable/17}"
OP_TAG="${OP_TAG:-17-slim}"
OP_PORT="${OP_PORT:-127.0.0.1:8080}"
OP_HOST="${OP_HOST:-localhost:8080}"
OP_HTTPS="${OP_HTTPS:-false}"
OP_LOW_MEM="${OP_LOW_MEM:-true}"
OP_PULL="${OP_PULL:-always}"
OP_WAIT="${OP_WAIT:-600}"
OP_MOBILE_OAUTH="${OP_MOBILE_OAUTH:-true}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx \033[0m %s\n' "$*" >&2; exit 1; }

# --- preflight ---------------------------------------------------------------
log "Preflight checks"
command -v git    >/dev/null || die "git not found"
command -v curl   >/dev/null || die "curl not found"
command -v docker >/dev/null || die "docker not found"
docker compose version >/dev/null 2>&1 || die "docker compose v2 plugin not found"
timeout 10 docker info >/dev/null 2>&1 || die "Docker daemon not reachable (is Docker running?)"
case "$OP_TAG" in *-slim) : ;; *) die "OP_TAG must be a -slim tag (got '$OP_TAG'); the compose stack requires slim images" ;; esac

# --- clone or update ---------------------------------------------------------
if [ -d "$OP_DIR/.git" ]; then
  log "Updating existing checkout: $OP_DIR"
  git -C "$OP_DIR" fetch --depth=1 origin "$OP_BRANCH"
  git -C "$OP_DIR" checkout -q "$OP_BRANCH" 2>/dev/null || git -C "$OP_DIR" checkout -q -B "$OP_BRANCH" "origin/$OP_BRANCH"
  git -C "$OP_DIR" reset --hard "origin/$OP_BRANCH"
else
  log "Cloning $OP_REPO ($OP_BRANCH) -> $OP_DIR"
  mkdir -p "$(dirname "$OP_DIR")"
  git clone --depth=1 --branch="$OP_BRANCH" "$OP_REPO" "$OP_DIR"
fi

cd "$OP_DIR"

# --- .env --------------------------------------------------------------------
# set_env KEY VALUE — replace an existing assignment or append it.
set_env() {
  local key="$1" val="$2"
  if grep -qE "^${key}=" .env; then
    # use a non-/ delimiter; values may contain / and :
    # escape sed-special chars in val: \ must be first (avoid double-escaping)
    local escaped_val="${val//\\/\\\\}"
    escaped_val="${escaped_val//&/\\&}"
    escaped_val="${escaped_val//|/\\|}"
    sed -i "s|^${key}=.*|${key}=${escaped_val}|" .env
  else
    printf '%s=%s\n' "$key" "$val" >> .env
  fi
}

if [ -f .env ]; then
  log ".env already present — preserving it (incl. SECRET_KEY_BASE)"
  FRESH_ENV=false
else
  log "Creating .env from .env.example"
  cp .env.example .env
  chmod 600 .env
  FRESH_ENV=true
fi

set_env TAG "$OP_TAG"
set_env OPENPROJECT_HTTPS "$OP_HTTPS"
set_env PORT "$OP_PORT"
set_env OPENPROJECT_HOST__NAME "$OP_HOST"

# SECRET_KEY_BASE must be stable for the life of the instance — only generate once.
if grep -qE '^SECRET_KEY_BASE=(OVERWRITE_ME)?$' .env || ! grep -qE '^SECRET_KEY_BASE=.+' .env; then
  log "Generating SECRET_KEY_BASE"
  # read plenty of entropy: ~24% of random bytes survive the alnum filter, so 512B -> ~120 chars
  SECRET="$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 64)"
  set_env SECRET_KEY_BASE "$SECRET"
else
  log "Keeping existing SECRET_KEY_BASE"
fi

if [ "$OP_LOW_MEM" = "true" ]; then
  log "Applying low-memory tuning (1 web worker, reduced threads)"
  set_env OPENPROJECT_WEB__WORKERS 1
  set_env RAILS_MIN_THREADS 2
  set_env RAILS_MAX_THREADS 4
fi

chmod 600 .env

# --- bring up ----------------------------------------------------------------
log "Starting stack (docker compose up -d --pull $OP_PULL) — first boot migrates+seeds (minutes)"
docker compose up -d --pull "$OP_PULL"

# --- wait for health ---------------------------------------------------------
# Probe through the published proxy port. Strip an ip: prefix for the curl target.
PROBE_PORT="${OP_PORT##*:}"
PROBE_HOST="127.0.0.1"
HEALTH_URL="http://${PROBE_HOST}:${PROBE_PORT}/health_checks/default"
log "Waiting up to ${OP_WAIT}s for $HEALTH_URL"
if ! [[ "$OP_WAIT" =~ ^[0-9]+$ ]]; then echo "ERROR: OP_WAIT must be a number, got '$OP_WAIT'" >&2; exit 1; fi
deadline=$(( $(date +%s) + OP_WAIT ))
ok=false
while [ "$(date +%s)" -lt "$deadline" ]; do
  # send the configured Host header — OpenProject validates host_name on most routes
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "Host: ${OP_HOST}" "$HEALTH_URL" 2>/dev/null || echo 000)"
  if [ "$code" = "200" ]; then ok=true; break; fi
  printf '\r    health: HTTP %s (seeding/migrating...) ' "$code"
  sleep 10
done
printf '\n'

docker compose ps

if [ "$ok" = "true" ]; then
  log "OpenProject is UP"
  SCHEME=http; [ "$OP_HTTPS" = "true" ] && SCHEME=https

  # --- mobile app login -------------------------------------------------------
  # The official OpenProject mobile app authenticates via OAuth2 and needs the seeded
  # built-in OAuth application enabled. It ships DISABLED, so /oauth/authorize answers 401
  # ("This client is not authorized to perform this request using this method"). Flip it on
  # here (idempotent). Harmless on a localhost-only deploy (the app can't reach it); only an
  # externally reachable HTTPS instance can actually use it.
  MOBILE_STATUS="skipped (OP_MOBILE_OAUTH=false)"
  if [ "$OP_MOBILE_OAUTH" = "true" ]; then
    log "Enabling built-in mobile OAuth application (OpenProject mobile app login)"
    # Capture stderr so a failure (missing row, DB not ready, container gone) is shown, not
    # swallowed; on success the bundler/deprecation noise is simply not printed.
    if mobile_out="$(docker compose exec -T web bundle exec rails runner '
        a = Doorkeeper::Application.find_by(builtin: true)
        abort("no built-in OAuth application found (seeding incomplete?)") if a.nil?
        a.update!(enabled: true) unless a.enabled
        puts "built-in mobile OAuth app ##{a.id} enabled=#{a.enabled}"
      ' 2>&1)"; then
      MOBILE_STATUS="enabled"
    else
      MOBILE_STATUS="FAILED — enable manually: Administration -> Authentication -> OAuth applications"
      warn "Could not enable the built-in mobile OAuth app automatically. $MOBILE_STATUS"
      warn "rails said: ${mobile_out}"
    fi
  fi

  echo
  echo "  URL:    ${SCHEME}://${OP_HOST}"
  echo "  Login:  admin / admin   <-- CHANGE IMMEDIATELY"
  echo "  Mobile: ${MOBILE_STATUS}   (app needs HTTPS + a reachable host to log in)"
  echo "  Data:   docker volumes pgdata + opdata (see 'docker volume ls')"
  echo "  Manage: cd $OP_DIR && docker compose ps | logs -f <svc> | stop | down"
  echo
  echo "  Next: log in, change the admin password, then create an API token under"
  echo "        My account -> Access tokens for the write MCP / APIv3."
else
  warn "Health check did not pass within ${OP_WAIT}s."
  warn "Inspect:  cd $OP_DIR && docker compose logs --tail=120 seeder web"
  warn "On a small box, watch for OOM kills: docker stats --no-stream"
  exit 1
fi
