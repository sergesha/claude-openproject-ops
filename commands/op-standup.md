---
description: Daily standup — current-sprint board, blockers, aging, re-plan to the goal
argument-hint: "<project> [--aging-days N]"
---

Run the standup for $ARGUMENTS (use the `sprint-operations` skill).

1. Show the current-sprint board state by status; restate the sprint goal.
2. **Blockers + aging:** in-progress items not updated in > N days; items blocked > N days.
3. **Blocked-work loop:** for each blocked item name the impediment owner, the blocking item, and
   age; if blocked > N days, **escalate** it explicitly — don't just list it.
4. Re-plan toward the goal (a working session, not a status report).
