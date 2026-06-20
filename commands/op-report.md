---
description: Generate a delivery status report (stakeholder highlight or portfolio rollup)
argument-hint: "<project|all> [--audience stakeholder|team]"
---

Generate a delivery report for $ARGUMENTS (use the `delivery-reporting` skill; numbers from
`delivery-metrics`).

1. Pull metrics via `/op-metrics` (velocity, current sprint, runway) and the period's sprint
   outcomes; pull open risks from the register (`/op-risks`).
2. Compose by audience:
   - **stakeholder** — period & goal progress, shipped (outcomes), in-flight, top risks (ROAM),
     next, asks. **Redact** all internals (secrets/host/infra/versions) — outbound-disclosure boundary.
   - **team** — may include operator detail.
   - **`all`** — portfolio rollup: one row per track (goal, velocity, runway, % done, top risk,
     Horizon vs delivery) + an aggregate health line.
3. Offer to publish via OpenProject **News** (`create_news`) or `generate_weekly_report`. Confirm
   before sending anything outward.
