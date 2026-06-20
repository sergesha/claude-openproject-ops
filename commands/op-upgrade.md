---
description: Safely upgrade the self-hosted OpenProject instance
argument-hint: "[target stable branch/major, e.g. stable/17]"
---

Upgrade OpenProject safely (use the `openproject-devops` skill). From
`openproject/openproject-docker-compose/`:

1. **Back up first** (run the `op-backup` flow); do not proceed without a fresh backup.
2. Update the recipes: `git pull` (or switch to $ARGUMENTS) and/or bump `TAG` to the new
   `<major>-slim`.
3. **Diff `.env.example` vs `.env`** for new variables; merge custom values. Keep
   `SECRET_KEY_BASE` and DB credentials unchanged.
4. `docker compose pull && docker compose up -d`; watch the `migrate`/`seeder` step finish
   cleanly; smoke-test the URL + `/api/v3`.
5. **Re-test integrations**: the write MCP (`openproject-pm`) auth, and the official `/mcp`
   endpoint — note if a release added write tools (then prefer the official MCP).
6. Report old→new version, env changes merged, and integration test results.
