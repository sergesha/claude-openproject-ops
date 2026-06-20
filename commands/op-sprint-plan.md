---
description: Plan a sprint (OpenProject Version) for a project/track
argument-hint: "<project identifier> [sprint length, e.g. 2w]"
---

Facilitate sprint planning for $ARGUMENTS (use `pm-craft` for the craft, `openproject-pm`
to apply changes).

1. Inputs: refined backlog (priority-sorted query), recent **velocity** (compute via
   `/op-metrics` — the `delivery-metrics` skill), team capacity (per-person availability) for the
   period. Check committed SP ≤ velocity and per-assignee load ≤ availability (over-allocation).
2. Create/confirm the **Version** with start/finish dates; write a clear **Sprint Goal**
   (version description or a Wiki page).
3. Pull a *realistic* set of ready items into the version (respect velocity/capacity);
   confirm each has owner, story-point estimate, and acceptance criteria.
4. Surface dependencies (relations) that could block the goal.
5. Report the plan: goal, committed points vs velocity, items, risks. Save the goal +
   committed scope to redis-memory-mcp for the track.
