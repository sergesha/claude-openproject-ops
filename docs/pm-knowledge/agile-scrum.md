# Agile & Scrum — reference

Primary: https://agilemanifesto.org/ · https://scrumguides.org/ (Scrum Guide 2020).

## Agile (the umbrella)

4 values: individuals & interactions > processes & tools; working software > documentation;
customer collaboration > contract negotiation; responding to change > following a plan
(while still valuing the right-hand items). 12 principles emphasize early & continuous
delivery, welcoming change, short cycles, motivated people, sustainable pace, technical
excellence, simplicity, self-organizing teams, and regular reflection.

## Scrum (2020 Guide)

A lightweight framework: a Product Owner orders work for a complex problem into a Product
Backlog, the Scrum Team turns a slice into an Increment each Sprint, results are inspected
and adapted. Empiricism (transparency, inspection, adaptation) + Lean thinking. Values:
commitment, focus, openness, respect, courage.

### Accountabilities (roles)
- **Product Owner** — maximizes product value; owns the Product Backlog (content, ordering,
  transparency). One person, not a committee.
- **Scrum Master** — establishes Scrum; coaches the team & org; removes impediments;
  facilitates events as needed; a true leader who serves.
- **Developers** — create a usable Increment each Sprint; own the Sprint Backlog & quality
  (Definition of Done). Cross-functional, self-managing.

### Events (all time-boxed; the Sprint contains the rest)
- **Sprint** — ≤1 month container; consistent length; no scope changes that endanger the goal.
- **Sprint Planning** — Why (Sprint Goal), What (selected PBIs), How (plan). Output: Sprint
  Backlog.
- **Daily Scrum** — 15 min, Developers re-plan toward the Sprint Goal.
- **Sprint Review** — inspect the Increment with stakeholders; adapt the backlog. (working
  session, not a demo theatre.)
- **Sprint Retrospective** — inspect people/process/tools; pick improvements (track them).

### Artifacts + commitments
- **Product Backlog** → commitment: **Product Goal**.
- **Sprint Backlog** → commitment: **Sprint Goal**.
- **Increment** → commitment: **Definition of Done** (quality bar; not done ≠ released).

### Definition of Done vs Acceptance Criteria
- **DoD** = team-wide quality gate applied to every item (tested, reviewed, documented…).
- **AC** = per-item, testable conditions of satisfaction (Gherkin Given/When/Then).

## → OpenProject mapping

| Scrum | OpenProject |
|---|---|
| Product Backlog | Backlogs "Product backlog" / a priority-sorted query |
| Sprint | a **Version** (start/finish dates) |
| Sprint Backlog | WPs assigned to the sprint Version; the **task board** |
| PBI / User Story | a **work package** (type User Story/Feature) |
| Story points | the **story points** field (Backlogs) |
| Increment progress | **burndown** chart |
| Impediments | WP relations (`blocks`) + a flagged/blocked status |
| Retro outcomes | Wiki page + improvement work packages |

See `facilitation-and-ceremonies.md` for how to run each event, and
`estimation-and-metrics.md` for points/velocity/forecasting.
