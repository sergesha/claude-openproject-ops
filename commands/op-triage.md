---
description: Triage raw inbound work into the delivery backlog (intake-side, not grooming)
argument-hint: "[project identifier, optional]"
---

Triage **new, unsorted inbound** work packages into the delivery backlog (use `openproject-pm`
and `pm-craft`). This is the intake-side first pass — *grooming the existing backlog to ready is
`/op-refine`* (the `backlog-refinement` skill), and the idea/use-case discovery funnel is
`/op-intake` (the `openproject-intake` skill).

1. Identify the inbound source for $ARGUMENTS (or each active track): the intake query, or work
   packages with **no version / status = New**.
2. For each item, make an initial routing decision:
   - reject / duplicate-link if not viable,
   - set type, priority, category; assign to the right track/project,
   - park it in the delivery backlog (or hand genuine product ideas to `/op-intake`).
3. Leave nothing un-triaged. Report counts triaged/accepted/rejected and what landed in each
   backlog. Hand the accepted items to `/op-refine` to bring them to **ready**.

Before starting, search redis-memory-mcp for prior decisions/context on these tracks.
