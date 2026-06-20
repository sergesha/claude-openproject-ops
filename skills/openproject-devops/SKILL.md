---
name: openproject-devops
description: Install, start/stop, upgrade, back up, restore, and troubleshoot a self-hosted OpenProject Community instance (Docker Compose, slim images). Use when the user wants to deploy OpenProject, bring the stack up or down, change configuration (.env: ports/host/HTTPS/SMTP/storage), upgrade OpenProject to a new release, back up or restore data, check service health, or read container logs. Trigger phrases: "install OpenProject", "start/stop OpenProject", "upgrade OpenProject", "back up OpenProject", "restore OpenProject", "OpenProject is down", "OpenProject logs", "change OpenProject port/domain", "configure OpenProject SMTP".
---

# openproject-devops — operate self-hosted OpenProject (Docker)

Run and maintain a self-hosted **OpenProject Community Edition** deployed with the official
**`openproject-docker-compose`** recipes using **slim** images. Full primary-source
reference: `docs/openproject-selfhost.md` — read it before non-trivial changes.

## Deployment layout on this host

- Upstream stack cloned into `openproject/openproject-docker-compose/` (gitignored: holds
  `.env` secrets + data). Run all `docker compose` commands from that directory.
- Use a **`-slim` image tag** (`TAG=<major>-slim`) — the compose stack requires slim images.
- Persisted data: PostgreSQL volume + the assets dir (`/var/openproject/assets`, uid 1000).
- This instance: **see CLAUDE.md → "This host"** for the confirmed host port / HTTPS / proxy.
  Default-decided values live there once set.
- The `openproject/proxy` image isn't on a registry — compose **builds it locally** from
  `./proxy`. The `pull access denied for openproject/proxy` warning during `up --pull always`
  is **benign**.

## Exposure & security (guardrail)

`scripts/setup.sh` binds to **localhost only** (`127.0.0.1:8080`) by default — keep it that
way unless asked. **Never publish the instance to the internet** (`OP_PORT=0.0.0.0:…`, a host
reverse proxy, or opening the firewall) **while it still uses default `admin/admin` or serves
plain HTTP — and never without the user's explicit go-ahead.** Before any public exposure:
change the admin password (see below), then prefer TLS. External-access assets (nginx vhost +
certbot, SSH tunnel, the `OP_PORT=0.0.0.0` shortcut) live in `deploy/` — note it needs DNS +
root, which the agent user may lack.

## Quick reference

| Action | Command (from `openproject/openproject-docker-compose/`) |
|---|---|
| Status | `docker compose ps` |
| Logs | `docker compose logs -f --tail=100 <web\|worker\|cron\|db\|cache\|proxy\|seeder>` |
| Start / apply config | `docker compose up -d --pull always` |
| Stop / teardown | `docker compose stop` / `docker compose down` (data persists) |
| Backup | `docker compose -f docker-compose.yml -f docker-compose.control.yml run backup` |
| Health probe | `curl -s -u apikey:<token> http://<host>/api/v3/work_packages \| head -c 200` |

## Core operations (run from `openproject/openproject-docker-compose/`)

```bash
# install (first time) — ONE idempotent command (the /op-setup command wraps this):
bash scripts/setup.sh        # clone + .env + SECRET_KEY_BASE + low-mem tuning + up + health-wait
# tune via env vars (see scripts/setup.sh header): OP_PORT OP_HOST OP_HTTPS OP_BRANCH OP_TAG OP_LOW_MEM
# re-running is safe — it preserves an existing .env (and its SECRET_KEY_BASE).

# manual equivalent (only if you can't run the script):
git clone https://github.com/opf/openproject-docker-compose.git --depth=1 \
  --branch=stable/17 openproject/openproject-docker-compose
cp .env.example .env   # then set TAG=<major>-slim, OPENPROJECT_HTTPS, PORT,
                       # OPENPROJECT_HOST__NAME, SECRET_KEY_BASE (keep stable)
docker compose up -d --pull always        # first boot migrates+seeds (minutes)

# day-to-day
docker compose ps
docker compose logs -f --tail=100 <web|worker|cron|db|cache|proxy|seeder>
docker compose stop | down | restart
```

Long-running ops (first `up`, upgrade) → run in background and watch the log; first boot
legitimately blocks while DB migration + seeding run. Default first login: **admin/admin**
— change immediately.

## Mobile app login (built-in OAuth)

The official **OpenProject mobile app** (Google Play / App Store, Beta) authenticates via
**OAuth2** — it needs the seeded **built-in OAuth application** enabled, plus the instance on
**HTTPS with a valid cert** and **≥ v17.0.0**. The built-in app ships **disabled**, so the app
fails at `/oauth/authorize` with a 401 and shows *"This client is not authorized to perform
this request using this method"*.

`scripts/setup.sh` enables it by default (`OP_MOBILE_OAUTH=true`). To toggle manually:

- **UI:** Administration → Authentication → OAuth applications (`/admin/oauth/applications`)
  → enable "Built-in OAuth applications".
- **CLI (idempotent):**
  ```bash
  docker compose exec -T web bundle exec rails runner \
    'a = Doorkeeper::Application.find_by(builtin: true); a&.update!(enabled: true); puts "enabled=#{a&.enabled}"'
  ```

In the app, enter the full `https://<host>` URL and log in. Login still requires a normal user
session — this only enables the OAuth client, it does not weaken authentication.

## Editing configuration (`.env`)

1. Edit `openproject/openproject-docker-compose/.env`. Common keys: `TAG`,
   `OPENPROJECT_HTTPS`, `PORT` (host bind `ip:port`), `OPENPROJECT_HOST__NAME`,
   `SECRET_KEY_BASE` (**never change after first boot**), SMTP/`OPENPROJECT_EMAIL__*`.
   Env-var nesting uses the `OPENPROJECT_` prefix + `__`.
2. `docker compose up -d` to apply (recreates affected containers).

## Admin password reset / lost credentials

Reset the built-in admin from the host (lost password, or hardening a fresh instance before
exposure) without the UI:

```bash
docker compose exec -T web bundle exec rails runner "
u = User.find_by(login: 'admin')
u.password = u.password_confirmation = '<NewStrongPass>'
u.force_password_change = false
u.save!(validate: true)"
```
Password policy: **≥10 chars with lower + upper + digit + special** (the `save!` raises with
the exact rule if it fails). First-boot default is `admin/admin` (force-change on first UI login).

## Upgrade procedure (safe order)

0. **Production: announce a maintenance window first.** `docker compose up -d` recreates
   containers and briefly drops active sessions; don't cut over silently under "users are
   waiting" pressure. For a real rehearsal, restore the backup onto a scratch instance and
   upgrade that before touching prod.
1. **Back up first** (below).
2. `git -C openproject/openproject-docker-compose pull` (or bump branch/`TAG` to new major).
3. **Diff `.env.example` vs `.env`** for new variables; merge custom values.
4. `docker compose pull && docker compose up -d`; watch the `migrate`/`seeder` step finish
   cleanly; smoke-test the URL and `/api/v3`.
5. Re-test the write MCP (`openproject-pm`) and the official `/mcp` endpoint — OpenProject
   ships features fast; the official MCP may gain write tools in a release.

## Backup / restore

**Use ONE format consistently so restore matches backup.** Canonical = logical `pg_dump`
(portable, version-tolerant, restores into a fresh DB cleanly):

```bash
# canonical backup: logical dump + assets
docker compose exec -T db pg_dump -U postgres -Fc openproject > backup/op-$(date +%F-%H%M).dump
tar czf backup/assets-$(date +%F-%H%M).tar.gz -C /var/openproject assets
```

```bash
# matching restore: stop app → recreate DB → pg_restore → restore assets → start
docker compose stop web worker
docker compose exec -T db dropdb -U postgres --if-exists openproject
docker compose exec -T db createdb -U postgres openproject
docker compose exec -T db pg_restore -U postgres -d openproject --clean --if-exists < backup/op-<ts>.dump
tar xzf backup/assets-<ts>.tar.gz -C /var/openproject
docker compose up -d
```

The compose repo's overlay `run backup` instead snapshots the **raw `$PGDATA` volume** (a
`tar` of the data dir) — a *different* format: restore that by stopping Postgres and extracting
the tar back into the volume, **not** via `pg_restore`. Don't mix the two. **Always back up
before upgrade; rehearse a restore into a scratch DB before relying on it** (see
`deploy/restore-runbook.md`).

## Troubleshooting checklist

- First boot / upgrade fails: read the `seeder`/`migrate` and `web` logs — DB migrations are
  the usual culprit.
- URL unreachable: `docker compose ps` (is `proxy`/`web` up?), confirm `PORT` and
  `OPENPROJECT_HOST__NAME` agree, check nothing else holds the host port.
- `Invalid host_name configuration` (typically when reaching it by raw IP — hits `/` and
  `/api/v3`), or wrong login/asset/link URLs / CORS-redirect errors: `OPENPROJECT_HOST__NAME`
  (and `OPENPROJECT_HTTPS`) must match how the browser actually reaches it. For IP access set
  `OPENPROJECT_HOST__NAME=<ip:port>`, or allow extra names via `OPENPROJECT_ADDITIONAL__HOST__NAMES`.
  Note `/health_checks/default` **bypasses** this check — health can be green while `/` 400s.
- OOM / restarts on a small box: `docker stats`; reduce web workers
  (`OPENPROJECT_WEB__WORKERS`) and Sidekiq concurrency; add swap; never build locally
  (pull prebuilt slim images).
- 500s after upgrade: usually a missed migration or a changed env var — re-diff `.env`.
- Inspecting the rendered UI on a headless host (no browser): create a temp admin via Rails
  with `force_password_change=false`, HTTP-login following redirects (with 2FA enforcement off,
  the `/two_factor_authentication/request` checkpoint passes through), fetch the page(s), then
  destroy the temp user. Don't fight the real `admin` account's force-password-change for this.
- Mobile app: *"This client is not authorized to perform this request using this method"* →
  the built-in OAuth application is disabled; enable it (see **Mobile app login**). Also
  requires HTTPS + valid cert and OpenProject ≥ v17.0.0. Confirm the actual failure in the
  `web` log: `path=/oauth/authorize ... status=401`.

## Definition of done after any deploy/upgrade

`docker compose ps` shows services healthy, migration/seeding finished, the URL serves the
app, `/api/v3` answers with an API token, the write MCP (see `openproject-pm`) still
authenticates, and the **instance scratchpad** `## Instance` section + the `CLAUDE.local.md`
`@`-import are in place and current (see `/op-setup` "After it reports UP" and CLAUDE.md →
"Instance scratchpad").
