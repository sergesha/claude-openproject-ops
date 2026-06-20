# Estimation, forecasting & metrics — reference

## Estimation
- **Story points** — relative size (effort + complexity + uncertainty), not hours. Use a
  modified Fibonacci scale (1,2,3,5,8,13,…). Estimate via **Planning Poker** / reference
  stories. Re-estimate when understanding changes; don't convert points→hours.
- **Ideal days / hours** — only for short, well-understood tasks (e.g. the Scrum task board).
- **T-shirt sizing** — coarse, for epics/early roadmap.
- Split anything ≥ ~13 points; large items hide risk.

## Velocity & forecasting (Scrum)
- **Velocity** = points completed (DoD-done) per sprint; use a rolling average of recent
  sprints, never a single one. Team-specific — never compare teams.
- Forecast a release: remaining backlog points ÷ average velocity = sprints left (give a
  range, not a point estimate). A **burnup** chart shows scope changes; **burndown** shows
  remaining work in a sprint.

## Flow metrics (Kanban)
- **Cycle time** (start→done), **Lead time** (request→done), **Throughput** (items/period),
  **WIP**. **Little's Law**: WIP = Throughput × Cycle time → limit WIP to cut cycle time.
- **CFD** (cumulative flow diagram) reveals bottlenecks (widening bands) and growing WIP.
- Forecast probabilistically (e.g. Monte Carlo on historical throughput) rather than from
  a single average.

## → OpenProject
- Story points: native field (Backlogs). Velocity/burndown: Backlogs charts per version.
- Flow metrics are **not** first-class — derive them from work-package **timestamps/status
  activity** via the APIv3 (read `created_at`, status-change journal entries) and compute
  cycle/lead time + throughput externally; document the method in the Wiki.
- Track velocity history in `redis-memory-mcp` so forecasts persist across sessions.
