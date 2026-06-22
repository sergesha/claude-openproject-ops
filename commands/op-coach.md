---
description: Coach the startup to its next move — locate the phase, surface the decision, facilitate it
argument-hint: "[phase number, optional]"
---

Run the `startup-navigator` skill — the coach for the `docs/cookbook/` founder methodology.

1. Parse `$ARGUMENTS`: optional `phase` number. No arg → locate the current phase from live
   OpenProject state; explicit `phase` → coach that phase on demand.
2. Follow the skill's run contract: **Locate → Orient → Ask → Facilitate → Delegate → never decide**
   (read the active recipe as the source of truth; infer the phase, don't store it).
3. Surface the founder's decision with options + a recommendation, offer to draft the phase artifact,
   and hand any OpenProject mechanics to the owning `op-*` command. Business calls stay the founder's.
