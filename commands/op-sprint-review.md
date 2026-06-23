---
description: Sprint review — inspect the increment, capture feedback as follow-up work
argument-hint: "<project> [sprint/version name]"
---

Run the sprint review for $ARGUMENTS (use the `sprint-operations` skill).

0. If no active sprint/version exists for the project, report this to the user and stop — don't proceed with stale data.
1. Inspect the increment — the DoD-passing items completed this sprint.
2. Collect stakeholder feedback; turn each item into a **follow-up work package** (not a buried
   comment). Respect the outbound-disclosure boundary if reporting outward.
3. Adapt the backlog: hand new/changed items to `/op-refine`. A working review, not a one-way demo.
