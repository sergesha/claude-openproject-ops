# Kanban & Scrumban — reference

Primary: https://kanban.university/ (Kanban Method, David J. Anderson).

## The Kanban Method

Evolutionary improvement of an existing process; **start with what you do now**.

**Principles**
- Change-management: start where you are; pursue incremental change; respect current roles/
  responsibilities; encourage leadership at all levels.
- Service-delivery: understand & focus on customer needs; manage the work, not the people;
  evolve policies experimentally.

**Practices**
1. **Visualize** the workflow (a board: columns = stages).
2. **Limit WIP** (explicit per-column limits — the core mechanism; pull, don't push).
3. **Manage flow** (smooth, fast, predictable; watch for bottlenecks/blockers).
4. **Make policies explicit** (entry/exit criteria, classes of service, DoD per column).
5. **Implement feedback loops** (cadences: standup, replenishment, delivery, review).
6. **Improve collaboratively, evolve experimentally** (use models/metrics).

**Flow metrics** (see `estimation-and-metrics.md`): lead time, cycle time, throughput, WIP,
flow efficiency; cumulative flow diagram (CFD); Little's Law (WIP = throughput × cycle time).

**Classes of service**: Expedite, Fixed-date, Standard, Intangible — different policies/SLAs.

## Scrumban

Hybrid: Scrum's cadence/roles + Kanban's flow & WIP limits. Typical when a Scrum team needs
steadier flow or handles interrupt-driven work (support/ops). Common traits: pull from a
priority-ordered backlog with WIP limits instead of fixed sprint commitments; **on-demand
replenishment** when WIP drops below a threshold; keep retros; loosen the fixed Sprint
Backlog. Good migration path from Scrum → Kanban or for maintenance teams.

## → OpenProject mapping

| Kanban concept | OpenProject |
|---|---|
| Board, columns = stages | **Boards → Action (Status) board** — *free in Community on 17.3+*; on pre-17.3 Community use a status-grouped **query** + the Backlogs task board |
| WIP limits | per-column WIP limits / swimlanes are still *Enterprise* (verify per version); otherwise enforce via policy + monitor a query count |
| Pull / status change | move card (Action board) or change WP **status** |
| Classes of service | **priority** + a custom field / label; **type** for expedite lanes |
| Replenishment cadence | a recurring refinement of the backlog query |
| Flow metrics | derive from WP timestamps/activity via the API; OpenProject reporting is limited — export and compute lead/cycle time |
| Explicit policies | document in the project **Wiki**; encode as status/workflow rules |

⚠️ Confirm board availability for the running edition: **Action Boards are free in Community
since 17.3** (swimlanes / WIP limits remain Enterprise — verify per version). On pre-17.3
Community, run Kanban discipline through statuses + queries + the task board. Either way,
track flow metrics from API data (OpenProject reporting is limited).
