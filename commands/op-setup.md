---
description: Deploy a fresh self-hosted OpenProject instance (one command, idempotent)
---

First-time deploy of self-hosted OpenProject Community Edition (Docker Compose, slim images),
using the `openproject-devops` skill. The workhorse is `scripts/setup.sh` — a single
idempotent command. Re-running is safe (it preserves an existing `.env` and its
`SECRET_KEY_BASE`).

## Run it

```bash
bash scripts/setup.sh
```

Tune via env vars (defaults in the script header) — do NOT hand-edit the generated `.env`
for things the script manages:

| Var | Default | Meaning |
|---|---|---|
| `OP_DIR` | `$HOME/openproject/openproject-docker-compose` | deploy workspace (data lives here) |
| `OP_BRANCH` / `OP_TAG` | `stable/17` / `17-slim` | compose branch + image tag (**must** be `-slim`) |
| `OP_PORT` | `127.0.0.1:8080` | host bind for the proxy (`ip:port` or `port`) |
| `OP_HOST` | `localhost:8080` | `OPENPROJECT_HOST__NAME` — how the browser reaches it |
| `OP_HTTPS` | `false` | `true` when TLS is terminated in-app / at a proxy |
| `OP_LOW_MEM` | `true` | inject small-box tuning (1 web worker, fewer threads) |
| `OP_MOBILE_OAUTH` | `true` | enable the built-in OAuth app so the OpenProject mobile app can log in |

Before running, **confirm the mobile-app choice with the user** (default: enable). The
official OpenProject mobile app logs in via OAuth2 and needs the seeded built-in OAuth
application turned on; it ships disabled, so without this the app fails with *"This client is
not authorized to perform this request using this method"*. Pass `OP_MOBILE_OAUTH=false` only
if they don't want mobile access. (Harmless on a localhost-only deploy — the app can't reach
it — so default-on is safe; it only matters once the instance is reachable over HTTPS.)

Example (expose on the LAN, more memory available):
```bash
OP_PORT=0.0.0.0:8080 OP_HOST=op.example.com OP_HTTPS=true OP_LOW_MEM=false bash scripts/setup.sh
```

## What the script does

1. Preflight (git/curl/docker/compose present, daemon reachable, tag is `-slim`).
2. Clone or fast-forward `opf/openproject-docker-compose` at `OP_BRANCH`.
3. Write `.env` from `.env.example`; generate a stable `SECRET_KEY_BASE` once; apply
   low-memory tuning when `OP_LOW_MEM=true`.
4. `docker compose up -d --pull always` (first boot migrates + seeds — minutes).
5. Poll `/health_checks/default` until healthy; print the URL and the `admin/admin` reminder.
6. Enable the built-in mobile OAuth application (unless `OP_MOBILE_OAUTH=false`) — idempotent;
   reports `Mobile: enabled` in the summary.

## After it reports UP

1. Open the URL, log in `admin`/`admin`, **change the password immediately**.
2. Create an API token (*My account → Access tokens*) for the write MCP / APIv3.
3. Smoke-test: `curl -s -u apikey:<token> http://<host>/api/v3/work_packages | head -c 200`.
4. Record the confirmed host port / HTTPS / proxy under **CLAUDE.md → "This host"**.
5. **Scaffold the instance scratchpad** (instance state delivered into every session by the plugin's
   SessionStart hook — CLAUDE.md → "Instance scratchpad"). Resolve its **canonical path** with
   `scripts/op-state-path.sh` (= `OP_STATE_FILE` if set, else `$HOME/.op-state.local.md`) — reader
   (hook) and writers all use this one path, so they can't diverge. If the file is missing, create
   it there from `templates/op-state.example.md`; then write/update the `## Instance` section from
   the deploy values — url, version, `deploy_dir`, the `~/openproject/.op-api.env` /
   `~/openproject/.op-admin.env` paths, and the write MCP. **No secrets — file paths only.**
   Idempotent: update the section in place if it already exists. (No `@import` needed — the hook
   delivers it.) If the scratchpad shouldn't live in `$HOME` (e.g. multiple instances on one host),
   set `OP_STATE_FILE` in the agent's environment to the chosen path.
6. **Offer to disable Claude auto-memory** (one-time). This workflow keeps instance facts in the
   scratchpad and PM knowledge in redis-memory; Claude's default free-form auto-memory (`MEMORY.md`)
   just pollutes context and isn't structured. A **plugin cannot** turn it off itself (plugin
   `settings.json` honors only `agent`/`subagentStatusLine`; a SessionStart hook is too late —
   auto-memory loads first). So, **with the operator's consent**, set it explicitly:
   `autoMemoryEnabled: false` in `~/.claude/settings.json` (user) or the workspace
   `.claude/settings.json` (project, after the trust prompt), or env `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`.
   Never flip it silently — ask first.

If the health check fails (small box): `docker compose logs --tail=120 seeder web` and
`docker stats --no-stream` to check for OOM kills; then re-run with `OP_LOW_MEM=true` and/or
add swap.
