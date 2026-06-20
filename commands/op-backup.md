---
description: Back up the self-hosted OpenProject instance (DB + assets)
---

Back up OpenProject (use the `openproject-devops` skill). From
`openproject/openproject-docker-compose/`:

1. Prefer the control-plane overlay:
   `docker compose -f docker-compose.yml -f docker-compose.control.yml run backup`.
2. Otherwise dump manually: `pg_dump` the database (gzip) **and** tar the assets dir
   (`/var/openproject/assets`).
3. Verify the artifacts exist and are non-empty; report their paths, sizes, and timestamp.

Always run this **before** any `op-upgrade`. Note: a backup you haven't test-restored is
not yet trustworthy — recommend a periodic restore drill.
