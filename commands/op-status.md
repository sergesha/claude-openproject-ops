---
description: Report self-hosted OpenProject health and current project/sprint status
argument-hint: "[project identifier or name, optional]"
---

Produce a concise status report for the self-hosted OpenProject instance.

1. **Infra health** (use the `openproject-devops` skill): from
   `openproject/openproject-docker-compose/`, confirm the stack is up
   (`docker compose ps`) and the instance URL + `/api/v3` respond. Flag any non-running
   container or resource pressure.
2. **Delivery status** (use the `openproject-pm` skill + the OpenProject MCP/APIv3): for
   $ARGUMENTS (or all active projects/tracks if none given), summarize per current
   **Version**/Epic:
   - done vs in-progress vs blocked counts,
   - items blocked (via `blocks`/`blocked_by` relations) and what they wait on,
   - anything In progress with no recent activity,
   - scope changes, and the **top open risks** from the register (`/op-risks` —
     `delivery-reporting`), each with its ROAM state,
   - velocity / runway / burndown via `/op-metrics` (`delivery-metrics`).

For a stakeholder-facing or cross-track (portfolio) report, use `/op-report`
(`delivery-reporting`) — and redact internals per the outbound-disclosure boundary.

Use readable `#ID`s in prose. Keep it skimmable; lead with what needs attention.
