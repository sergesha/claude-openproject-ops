# OpenProject data model ↔ PM/Scrum/Kanban practice — reference

How OpenProject's primitives map to project-management practice. Drives the
`openproject-pm` skill. Framework theory lives in `docs/pm-knowledge/`; this file is the
**tool ↔ practice bridge**. Re-verify Community-vs-Enterprise gating against primary docs.

## Contents
- Hierarchy · practice→primitive mapping table
- Edition gating (Community vs Enterprise — verify per release)
- Boards (Kanban) · Backlogs (Scrum)
- Writing work packages (quality bar) · Lifecycle / workflow
- Cadence the skill drives · Best-practice guardrails

## Hierarchy

```
Instance
 └─ Project ............. a product / team / deliverable; own members, types, workflow
     ├─ Work Package .... the unit of work; has a TYPE (Task, Bug, Feature, Epic,
     │     │              User Story, Milestone, Phase, …) — types are configurable
     │     ├─ parent/child hierarchy (work breakdown structure / decomposition)
     │     ├─ relations: relates to / duplicates / blocks / precedes-follows / parent
     │     ├─ status (workflow), priority, assignee, accountable, version, story points
     │     ├─ description (Markdown), activity/comments, attachments, watchers
     │     ├─ time entries (spent time / worklogs), custom fields
     ├─ Versions ........ releases / **SPRINTS** (Backlogs module treats a version as a sprint)
     ├─ Categories ...... lightweight grouping/routing within a project
     ├─ Queries ......... saved, filtered, sortable views of work packages (the workhorse)
     ├─ Wiki / Documents  durable knowledge: PRDs, specs, retros, runbooks
     └─ sub-projects .... portfolio / program structure across teams
```

There is no separate "Initiative/Module/Cycle/Intake" object as in some tools. The
equivalents:

| Practice concept | OpenProject primitive |
|---|---|
| Portfolio / program | parent **project** with sub-projects (or a cross-project query) |
| Initiative / large outcome | **Epic** work-package type (or a parent WP) |
| Epic → Story → Task | **parent/child work packages** (WBS) |
| Sprint / iteration | a **Version** (Backlogs module) |
| Product backlog | a **query** sorted by priority, or the Backlogs "Product backlog" |
| Sprint backlog | work packages assigned to the sprint **Version** |
| Kanban board | **Boards** module (Status/Action board) — *free in Community on 17.3+; Enterprise before* |
| Task board (Scrum) | **Backlogs** task board — *Community* |
| Triage inbox | a **query** (e.g. status=New, no version) or a dedicated "Inbox" project |
| Wiki / PRD / retro | project **Wiki** pages / **Documents** |
| Dependencies | work-package **relations** (`blocks`/`precedes`) + the Gantt |
| Estimate | **Story points** (Backlogs) and/or **Estimated time** |

## Edition gating (VERIFY per release — features migrate to Community over time)

- **Community (free):** work packages + types + custom workflows, **Gantt/timeline**,
  **Backlogs** (product backlog, sprints-as-versions, story points, task board, burndown),
  Wiki, Documents, time tracking, queries, basic boards, and — **since 17.3 — all Action
  Boards** (Status/Kanban/Assignee/Version/Subproject/Parent-child auto-updating boards).
- **Enterprise add-on (often):** the built-in **MCP** server, baseline comparison, some
  reporting/branding, and advanced board refinements (e.g. swimlanes / WIP limits — verify
  per version). **Action Boards moved to Community in 17.3**; on **pre-17.3 Community** they
  were Enterprise — there, drive Kanban via **queries + status changes** (or the Backlogs
  task board). Source: openproject.org/docs/release-notes/17-3-0.

Don't assert gating from memory in front of the user — confirm against
`openproject.org/docs` for the running version, since the line moves.

## Boards (Kanban) — when available

- **Basic board:** free-form columns; moving a card changes **nothing** on the WP. Use for
  ideation / coordination.
- **Action board:** each column = an attribute value; moving a card **updates** the WP:
  - **Status board** = classic Kanban (column = status).
  - **Assignee / Version / Subproject / Parent-child** boards reassign that attribute.

## Backlogs (Scrum) — Community

- Two backlog kinds: **Product backlog** (ordered, all upcoming stories) and **Sprint
  backlogs** (each is a Version with start/finish dates).
- **Story points** estimate stories; **burndown** charts track sprint progress.
- The **task board** breaks each story into Task work packages (To do / In progress / Done).
- Enable per project: *Project settings → Modules → Backlogs*; set which types are
  "stories" vs "tasks" in *Administration → Backlogs*.

## Writing work packages (the quality bar the skill enforces)

**Epics** — outcome-oriented: problem/opportunity, target users, success metrics, scope
(in/out), rough sizing, link to the PRD wiki page. Decompose into shippable stories
(children).

**User stories / Features** — INVEST. Title = user-visible value, imperative. Description:
```
## Context / why
<problem, user, link to epic / PRD>
## Acceptance criteria
- [ ] Given <context> when <action> then <outcome>   (Gherkin, testable)
- [ ] ...
## Out of scope
## Notes / dependencies
```
Set: type, status, priority, assignee, **version** (target sprint), story points / estimate,
category, parent (epic).

**Bugs** — steps to reproduce, expected vs actual, environment, severity → priority.

Use **relations** for dependencies (`blocks`/`precedes`); **parent/child** for breakdown.

## Lifecycle / workflow

Statuses are per-type and governed by the project's **workflow** (allowed transitions per
role). A typical agile flow: `New → In specification → Specified → In progress → Developed →
In testing → Closed/Rejected`. Keep every WP carrying an accurate status, an assignee once
started, a priority, and a version once committed to a sprint. "Done" = acceptance criteria
met. Configure workflows in *Administration → Work packages → Status / Workflow*.

## Cadence the skill drives

1. **Backlog refinement** — triage the intake query, write/clarify stories, estimate
   (story points), set priority, link epics↔stories, set type/category.
2. **Sprint planning** — create/confirm a **Version** with dates, write the sprint goal
   (Version description or a wiki page), pull a realistic refined set into the version
   (respect capacity), ensure owner + estimate + AC on each.
3. **During the sprint** — keep statuses current (task board / status changes), surface
   blockers via relations, record decisions as comments, log spent time.
4. **Sprint review/close** — verify AC, close completed WPs, **move incomplete items to the
   next version**, note carry-over and why; check the burndown.
5. **Retro** — capture in a wiki page (went well / didn't / actions) → create improvement
   work packages from the actions.
6. **Status report** — per version/epic: done vs in-progress vs blocked, scope changes,
   risks. Use `#ID` in prose.

## Best-practice guardrails

- One clear owner per work package once it is "In progress".
- Acceptance criteria mandatory for Features/Stories; "done" = criteria met.
- Prefer small, vertical, testable slices over big tickets.
- Keep estimates relative & consistent; re-estimate, don't pad.
- Don't let the intake/triage query rot — refine every cadence.
- Decisions → comments on the WP; durable knowledge → Wiki/Documents.
- Read before you write (list/get project, version, statuses, existing WPs) to avoid
  duplicates and mis-links. Send the `lockVersion` on PATCH to avoid lost updates.
