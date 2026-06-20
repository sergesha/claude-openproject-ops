# OpenProject self-hosting (Community Edition, Docker Compose + slim images) — reference

Primary sources (re-verify before non-trivial changes):
- https://www.openproject.org/docs/installation-and-operations/installation/docker-compose/
- https://github.com/opf/openproject-docker-compose
- https://www.openproject.org/docs/installation-and-operations/installation/docker/ (all-in-one)

## Contents
- Which deployment we use (all-in-one vs compose+slim)
- Install (compose, slim) · Key environment variables
- Operating the stack · Upgrade (safe order) · Backup / restore
- Resource notes · Host constraints (kept locally)

## Which deployment we use

OpenProject ships two Docker paths:

1. **All-in-one container** (`openproject/openproject:<version>`) — web + workers + DB +
   cache in one container. Simplest, but **not scalable** and harder to back up/upgrade
   cleanly. Good for a quick demo only.
2. **Docker Compose with SLIM images** (`openproject/openproject:<version>-slim`) — the
   application image **without** an embedded database/proxy; each concern is a separate
   container (app, worker, cron/seeder, PostgreSQL, optional memcached, proxy). **This is
   the recommended production path and the one this project uses.**

> "OpenProject publishes `slim` containers that you should be using for this compose
> setup." Slim tags: `dev-slim`, `<MAJOR>-slim`, `<MAJOR>.<MINOR>-slim`,
> `<MAJOR>.<MINOR>.<PATCH>-slim`.

## Install (compose, slim)

```bash
# 1. Clone the upstream compose recipes pinned to a stable branch
git clone https://github.com/opf/openproject-docker-compose.git \
  --depth=1 --branch=stable/17 openproject/openproject-docker-compose
cd openproject/openproject-docker-compose

# 2. Configure
cp .env.example .env
#    edit .env — at minimum set:
#      TAG=17-slim                # or the stable major you pinned; use a *-slim tag
#      OPENPROJECT_HTTPS=false    # we terminate TLS at the host proxy (or run plain HTTP)
#      PORT=127.0.0.1:8080        # host bind; localhost-only (see host constraints)
#      OPENPROJECT_HOST__NAME=localhost:8080
#      SECRET_KEY_BASE=<64+ hex>  # generate once, KEEP STABLE forever

# 3. Data dir for uploaded assets (owned by uid 1000 = the app user)
sudo mkdir -p /var/openproject/assets && sudo chown 1000:1000 -R /var/openproject/assets
#    (no sudo here? mount a repo-local ./pgdata + ./assets in the compose override instead)

# 4. Bring it up (first boot runs DB migrations + seeding — can take minutes)
docker compose up -d --pull always
docker compose logs -f --tail=100   # watch until the 'seeder'/'migrate' steps finish
```

Default login after first boot: **`admin` / `admin`** — change immediately.

## Key environment variables (in `.env`)

| Variable | Default | Notes |
|---|---|---|
| `TAG` | `<major>-slim` | MUST be a `-slim` tag for the compose stack |
| `OPENPROJECT_HTTPS` | `false` | set `true` only when a TLS-terminating proxy is in front |
| `PORT` | `127.0.0.1:8080` | host bind `ip:port`; localhost-only by default |
| `OPENPROJECT_HOST__NAME` | `localhost:8080` | full external host:port; used in links/emails |
| `SECRET_KEY_BASE` | (generated once) | Rails secret — **keep stable** or sessions/encrypted data break |
| `OPENPROJECT_RAILS__RELATIVE__URL__ROOT` | (empty) | set only if serving under a sub-path |
| `IMAP/SMTP` `EMAIL_*` / `OPENPROJECT_EMAIL__DELIVERY*` | — | outbound mail config |
| `OPENPROJECT_SEED_LOCALE` | `en` | seed language |

Config can also be set under `x-op-app -> environment` in the compose file. OpenProject
maps env vars with the `OPENPROJECT_` prefix and `__` for nesting (e.g.
`OPENPROJECT_HOST__NAME`). Full list: docs → "Configuration" / "environment variables".

**HTTPS & host-name behaviour.** `OPENPROJECT_ADDITIONAL__HOST__NAMES` takes **one value only**
(it is NOT comma-split). With `OPENPROJECT_HTTPS=true`, a plain `http://localhost` call
**301-redirects to https** (no local TLS listener) — point API/MCP clients at the canonical URL,
or send header `X-Forwarded-Proto: https` for a local http call. First UI login is the default
**`admin/admin`** — change it immediately; the APIv3 token keeps working regardless of the UI password.

## Operating the stack

```bash
C="docker compose"   # run from openproject/openproject-docker-compose/
$C ps                          # service status
$C logs -f --tail=100 web      # follow a service (web, worker, cron, db, cache, proxy, seeder)
$C up -d --pull always         # (re)start / apply changes
$C stop                        # stop, keep containers
$C down                        # remove containers (named volumes / data persist)
$C restart web worker
```

## Upgrade (safe order)

1. **Back up first** (see below).
2. `git -C openproject/openproject-docker-compose pull` (or bump `--branch`/`TAG` to the
   new stable major).
3. **Diff `.env.example` vs your `.env`** for new variables; merge.
4. `docker compose pull && docker compose up -d` → watch the `migrate`/`seeder` step exit
   cleanly → smoke-test the URL and the API (`/api/v3`).

Re-test the MCP server (`docs/openproject-mcp.md`) and the official `/mcp` endpoint after
every upgrade — OpenProject ships features fast (e.g. the built-in MCP arrived in 17.2).

## Backup / restore

Critical artifacts: **PostgreSQL data** (all app data) and the **assets** directory
(`/var/openproject/assets` — attachments). **Pick one backup format and keep restore symmetric.**

Canonical = logical `pg_dump` (portable; restore matches via `pg_restore`):

```bash
$C exec -T db pg_dump -U postgres -Fc openproject > backup/op-$(date +%Y%m%d-%H%M).dump
tar czf backup/assets-$(date +%Y%m%d-%H%M).tar.gz -C /var/openproject assets
# restore: stop app → dropdb/createdb → pg_restore --clean --if-exists → untar assets → up
```

The compose repo's overlay `run backup`
(`docker compose -f docker-compose.yml -f docker-compose.control.yml run backup`) instead
snapshots the **raw `$PGDATA` volume** as a `tar` — a *different* format restored by extracting
the tar back into the volume (Postgres stopped), **not** by `pg_restore`. Don't mix them.

Always back up before `upgrade`. **Rehearse a restore into a scratch DB before relying on it**
(`deploy/restore-runbook.md`).

## Resource notes

OpenProject is heavier than it looks (Rails app + Sidekiq workers + Postgres + memcached).
Budget ~2 vCPU / 4 GB RAM minimum for a small instance; first-boot migration/seeding is the
peak. On constrained hosts, pull prebuilt images (never build locally), reduce worker
concurrency (`OPENPROJECT_WEB__WORKERS`, Sidekiq `*_CONCURRENCY`), and add swap.

## Host constraints (kept locally)

> Concrete host specifics — chosen host port, whether :80/:443 are free, sudo availability,
> docker-group membership, RAM/CPU/swap, and whether an external reverse proxy + DNS is needed
> (`deploy/`) — live in the deployment's **gitignored** local status file (e.g. `STATUS.local.md`)
> and CLAUDE.md → "This host", **never in this doc**.
