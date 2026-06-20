---
description: Maintain the risk register — log, review (ROAM), and surface risks
argument-hint: "<project> [log|review] [risk text]"
---

Maintain the risk register for $ARGUMENTS (use the `delivery-reporting` skill).

Risks are **work packages** (a `Risk` type if present, else an item tagged `[RISK]`). Each needs a
**ROAM** state (Resolved / Owned / Accepted / Mitigated), an **owner**, and an **impact × likelihood**
severity note.

- **log** — capture a new risk: create the WP, set initial ROAM + owner + severity.
- **review** — list open risks by severity; update ROAM states; close resolved ones (they stay
  findable). Search redis-memory for prior risk context first (best-effort).
- Surface the top risks in `/op-status` and stakeholder reports. A risk without an owner or a ROAM
  state is not yet managed — fix that.
