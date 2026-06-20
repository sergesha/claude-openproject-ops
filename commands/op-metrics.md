---
description: Compute delivery metrics (velocity, burndown, throughput, runway) for a project
argument-hint: "[project identifier] [--window N] [--days D]"
---

Compute and report delivery metrics for $ARGUMENTS (use the `delivery-metrics` skill).

1. Resolve the project; confirm the backlogs module is on (else story points are 0).
2. Run `skills/delivery-metrics/metrics.sh <project> [window] [days]` — one APIv3 pass.
3. Report the headline numbers with the **explicit done-definition and window**:
   - **Velocity** (mean done-SP over last N closed versions, with samples),
   - **Current sprint** (committed / done / remaining / %),
   - **Throughput** (done items in last D days),
   - **Status distribution** (snapshot).
4. On request, derive **ready-runway** (ready-SP ÷ velocity, for `/op-refine`) and a **capacity
   check** (committed vs velocity; per-assignee load vs user-supplied availability, for
   `/op-sprint-plan`).
5. If there are no closed versions yet, say **insufficient data** — don't fabricate a number.
   Persist velocity to redis-memory if available (best-effort).
