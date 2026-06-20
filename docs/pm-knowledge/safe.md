# SAFe (Scaled Agile Framework) — reference

Primary: https://framework.scaledagile.com/. For coordinating many agile teams on large
solutions. Heavyweight — use only when scale genuinely demands it; otherwise prefer Scrum/
Kanban. Configurations: **Essential**, **Large Solution**, **Portfolio**, **Full**.

## Core constructs
- **Agile Release Train (ART)** — a long-lived team-of-teams (50–125 people) delivering
  value on a common cadence (the **Program Increment**).
- **Program Increment (PI)** — a timebox (~8–12 weeks) of several iterations + an
  Innovation & Planning (IP) iteration.
- **PI Planning** — the cadence-setting event where all teams plan the PI together, surface
  dependencies, set PI Objectives, build the program board.
- **ART Sync / Scrum of Scrums + PO Sync**, **System Demo**, **Inspect & Adapt**.

## Backlog hierarchy
Portfolio **Epics** → **Capabilities** (Large Solution) → **Features** (Program) → **Stories**
(Team). **Enablers** at each level for architecture/infra. WSJF (Weighted Shortest Job
First) for prioritization.

## Key roles
RTE (Release Train Engineer), Product Management, System Architect, Business Owners (program);
Scrum Master/Team Coach, Product Owner, Dev Team (team); Epic Owners, Enterprise Architect,
LPM / portfolio (portfolio level). **Lean Portfolio Management** connects strategy↔execution.

## Lean-Agile foundation
Lean-Agile leadership, core values (alignment, transparency, built-in quality, program
execution), SAFe principles (economic view, systems thinking, assume variability/preserve
options, fast feedback, milestone via working systems, limit WIP, cadence & sync,
unlock motivation, decentralize decisions, organize around value).

## → OpenProject mapping

| SAFe | OpenProject |
|---|---|
| Portfolio | a parent **project** (portfolio) with team sub-projects, or cross-project queries |
| Portfolio Epic / Capability / Feature / Story | **work-package types** in a parent/child hierarchy |
| ART | a project (or program) grouping the team sub-projects |
| PI | a long **Version**, or a phase WP spanning the team iterations |
| Iteration (sprint) | a **Version** per team |
| Program board / dependencies | cross-project **Gantt** + WP **relations** (`precedes`/`blocks`) |
| PI Objectives, WSJF | Wiki page + custom fields (WSJF components) on epics/features |
| System Demo / Inspect & Adapt | Wiki pages + improvement work packages |

OpenProject is not a purpose-built SAFe tool; model the hierarchy with projects + WP types +
relations, and lean on cross-project Gantt for the program view. Be explicit with the user
that SAFe overhead is heavy — recommend it only at real scale.
