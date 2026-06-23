---
description: Retrospective — capture a few improvements as owned work packages
argument-hint: "<project> [format]"
---

Facilitate the retrospective for $ARGUMENTS (use the `sprint-operations` skill).

0. If no active sprint/version exists for the project, report this to the user and stop — don't proceed with stale data.
1. Run a format (went-well / didn't / actions, or Start-Stop-Continue).
2. Pick **a few** improvements; create an **owned improvement work package** for each so the action
   doesn't evaporate.
3. Record the retro summary (wiki page or the sprint Version description). Search redis-memory for
   recurring patterns first (best-effort).
