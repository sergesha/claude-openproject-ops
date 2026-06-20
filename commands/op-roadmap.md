---
description: Show or rebuild the high-level Now/Next/Later roadmap; convert approved ideas
argument-hint: "[convert #<idea-id> [now|next|later]]  |  [show]"
---

Manage the high-level roadmap using the `openproject-intake` skill.

**Show (default):** list **Epics** in project **Roadmap**, grouped by **Horizon** (Now / Next /
Later) as swimlanes, each sorted by **RICE score**; optionally a second grouping by **Track**.
Report it skimmably with `#ID`s.

**Convert `#<idea-id>`:** for an **Approved** idea, perform the conversion (skill's "Conversion"
section):
1. create an **Epic** in project Roadmap; description starts with the **Origin** block
   `Origin: Idea #N · RICE <score> · Track <t> · Lens <l> · use cases #…`;
2. set **Horizon** (argument, default **Next**);
3. relate Idea→Epic (`relates`), comment `Converted → Epic #M` on the idea, set idea status
   **Converted**; link its use cases to the Epic;
4. report the new Epic `#ID` and its horizon. Hand the Epic to `openproject-pm` / `op-triage` for
   delivery decomposition — do not decompose it here.
