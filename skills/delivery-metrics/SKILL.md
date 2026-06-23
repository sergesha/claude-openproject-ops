---
name: delivery-metrics
description: Use when computing or reporting delivery metrics for an OpenProject project — velocity, sprint burndown/remaining, throughput, cycle-flow/status distribution, ready-runway, or capacity vs load. Triggers — "what's our velocity", "show metrics", "burndown", "how much is left this sprint", "throughput", "are we on track", "how many sprints of runway", "capacity check". Computes from live data; feeds /op-refine (runway) and /op-sprint-plan (capacity).
---

# delivery-metrics — compute delivery numbers from live data

Turns OpenProject data into the numbers the rest of the toolkit needs: **velocity, current-sprint
burndown, throughput, status distribution, ready-runway, capacity vs load**. Metrics are *computed*,
never read off a chart and never guessed. PM interpretation lives in `pm-craft` +
`docs/pm-knowledge/estimation-and-metrics.md`; this skill produces the figures.

Core principle: **one explicit definition of "done", one explicit window — stated every time.**

## When to use
- Anyone asks for velocity / burndown / throughput / "are we on track" / runway / capacity.
- `/op-refine` needs velocity to compute ready-runway; `/op-sprint-plan` needs velocity + capacity.
- **NOT** for: writing/refining work items (`openproject-pm`, `backlog-refinement`); PM theory
  (`pm-craft`); historical CFD-over-time charts (out of scope — see Limits).

## The recipe
Command `/op-metrics [project] [--window N] [--days D]`, or run the script directly:
```bash
bash skills/delivery-metrics/metrics.sh <PROJECT_ID> [WINDOW=3] [DAYS=14]
```
1. **Define "done"** — `status.isClosed AND name != "Rejected"` (the script applies this). If the
   team uses a different done bar, say so and adjust.
2. **Run the script** — it makes one APIv3 pass (statuses + versions + all work packages, including
   closed) and prints a readable summary + a JSON line.
3. **Report** the four headline numbers and, when asked by `/op-refine` / `/op-sprint-plan`, derive:
   - **ready-runway** = ready-SP ÷ velocity (sprints of ready work) — pass ready-SP from refinement.
   - **capacity check** = committed SP vs (velocity × confidence) and per-assignee load vs
     availability (availability is **user-supplied**; the tool applies it, never invents it).
4. **Persist** velocity per track to redis-memory when available (best-effort; never block — see
   CLAUDE.md memory guard).

## What it computes
| Metric | Definition |
|---|---|
| Velocity | mean done-story-points over the last `WINDOW` **closed** versions (samples shown) |
| Current sprint | the open version's committed / done / remaining SP and % complete |
| Throughput | count of done items updated within the last `DAYS` |
| Status distribution | snapshot count of items per status (a point-in-time CFD bucket) |

Degrades gracefully: with no closed versions it reports **"insufficient data"** rather than a fake
number.

## Capacity ≠ velocity
- **Velocity** = team throughput in SP (forecasting / runway).
- **Capacity** = individual availability (person-days) for assignment and over-allocation checks.
Keep them separate; `/op-sprint-plan` uses both. Don't pull a sprint above velocity, and don't load
one person above their availability.

## Limits (honest)
- **No historical burndown/CFD *series*.** True time-series needs journal mining; v1 gives the
  current snapshot + remaining, not a day-by-day curve. Treat OpenProject Backlogs charts as a
  visual cross-check, not the source of truth — the source is this computation.
- Story points come from the backlogs module; if it's off, points are 0 and velocity is unusable —
  enable backlogs on delivery projects (Administration → Projects → [project] → Modules → check Backlogs; or via the provisioning script `skills/openproject-intake/provision.rb`).

## Common mistakes
- Reporting velocity without the **done-definition and window** — always state both.
- Forgetting the **all-status filter** — the default query hides closed items, zeroing velocity.
- Quoting Backlogs-chart numbers instead of computing — compute, then cross-check.
- Treating velocity as capacity — they answer different questions.
