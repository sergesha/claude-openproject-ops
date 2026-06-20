---
description: Refine (groom) a delivery backlog to ready — health scorecard + Definition of Ready
argument-hint: "[project identifier] [--runway N] [--top N] [--stale-days N]"
---

Run a backlog-refinement pass for $ARGUMENTS (use the **`backlog-refinement`** skill; craft from
`pm-craft`, execution via `openproject-pm`). This grooms the **existing delivery backlog** — it is
NOT intake triage (`/op-triage`) and NOT sprint planning (`/op-sprint-plan`).

1. **Context** — read project, types/statuses/versions, framework; get **velocity via
   `/op-metrics`** (the `delivery-metrics` skill); search redis-memory for prior track decisions
   (best-effort). Ambiguous which project/track → ask, don't guess.
2. **Health scorecard** — over the top-N delivery backlog (excluding intake/new): ready coverage,
   **ready runway** (sprints of ready work), oversized (≥13), no-estimate, no-AC, orphans, stale,
   possible duplicates, blocked, priority inversion.
3. **Plan** — per flagged item, the concrete action vs the Definition of Ready (write AC, set
   estimate, split, re-rank, link to epic, **resolve duplicate/overlap — combine/delete/split, by
   meaning via `semantic-search`** — or **escalate unclear value**).
4. **Gate** — present the scorecard + change-set; wait for sign-off (selective ok). Nothing is
   written before approval; bulk/destructive actions get explicit confirmation.
5. **Execute** approved edits via `openproject-pm` (read `lockVersion`; split = children + relink).
6. **Report** before/after ready coverage + runway and what was escalated; persist decisions and
   updated velocity to redis-memory.
