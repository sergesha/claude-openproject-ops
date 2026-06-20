---
description: Close a sprint — verify Definition of Done, carry over incomplete, snapshot velocity
argument-hint: "<project> [sprint/version name]"
---

Close the sprint for $ARGUMENTS (use the `sprint-operations` skill; metrics via `delivery-metrics`).

1. Pull the sprint Version's items; snapshot remaining/burndown via `/op-metrics`.
2. **Verify each "complete" item against the Definition of Done.** Any unmet criterion → **do not
   close it**; report the specific gap and leave it open. Closing a DoD-failing item is forbidden.
3. Close the DoD-passing items.
4. Carry incomplete items to the next Version with a one-line **carry-over reason** each.
5. Gate before bulk close/move; then report what changed + final velocity for the sprint.
