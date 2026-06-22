---
name: openproject-pm
description: Drive the full project delivery lifecycle inside a self-hosted OpenProject workspace via a write-capable MCP server (or APIv3). Use when planning or running a sprint, creating or refining epics/stories/bugs, writing acceptance criteria, triaging intake, organizing versions/boards/queries, managing the backlog, setting priorities/estimates/assignees, running sprint planning/review/retro, or reporting project/portfolio status across parallel tracks. Trigger phrases: "plan the sprint", "create an epic/story/work package", "start/close a sprint/version", "write acceptance criteria", "project status", "what's blocked", "set up a project in OpenProject", "cut a release", "release notes" (release management → `/op-release`, see `docs/release-management.md`). (A dedicated backlog-grooming pass — health, Definition of Ready, splitting — is the `backlog-refinement` skill / `/op-refine`.)
---

# openproject-pm — run the project lifecycle in OpenProject

Execution arm for delivery in a self-hosted OpenProject workspace. **The PM craft**
(framework choice, facilitation, estimation theory) lives in the `pm-craft` skill +
`docs/pm-knowledge/`; **the tool↔practice mapping** in `docs/openproject-concepts-and-pm.md`;
**tooling/auth** in `docs/openproject-mcp.md`. Read those rather than duplicating them here.

Core principle: **read before you write**, model work as work packages, keep one source of
truth so every view (backlog, board, Gantt, report) derives from the same data.

## Tools

Reads: the official `OpenProject:` `/mcp` (read-only, Enterprise) if available, else APIv3.
Writes: the community `openproject` MCP (wraps APIv3) — see `docs/openproject-mcp.md`. Use
**fully-qualified tool names** (`openproject:<tool>`). If the MCP isn't wired, fall back to
APIv3 via `curl -u apikey:<token>` (`POST`/`PATCH /api/v3/work_packages`, sending the
`lockVersion` you read back). Fix any auth error before doing PM work; always run
`openproject:list_projects` + inspect the project's types/statuses/versions/members first.

## Quick reference (operation → tool)

| Need | Tool (community `openproject` MCP) |
|---|---|
| Confirm context | `openproject:list_projects`, `openproject:list_statuses`, `openproject:list_versions` |
| Create/refine item | `openproject:create_work_package`, `openproject:update_work_package` |
| Decompose | set `parent` via `openproject:set_work_package_parent` |
| Dependencies | `openproject:create_work_package_relation` (`blocks`/`precedes`/`relates`) |
| Sprint | `openproject:create_version` (start/finish dates) |
| Find work | `openproject:list_work_packages` (filters), `openproject:search_work_packages` |
| Estimate / time | story-points field on the WP; `openproject:create_time_entry` |

(Exact tool names vary by MCP build — confirm against `docs/openproject-mcp.md` / the server.)

## Quality bar (enforce when creating/refining)

- **User stories** — INVEST. Title = user-visible value, imperative. Description has
  **Context/why**, **Acceptance criteria** (Gherkin Given/When/Then, testable checkboxes),
  **Out of scope**, **dependencies**. Set type, status, priority, assignee, **version**
  (target sprint), **story points**, parent (epic), category.
- **Epics** (type) — outcome + target users + success metrics + scope + link to a PRD wiki;
  decompose into shippable child stories.
- **Bugs** — repro steps, expected vs actual, environment, severity→priority.
- Descriptions/comments are **OpenProject Markdown**. "Done" = acceptance criteria met +
  Definition of Done. One owner once a WP is "In progress".

## Cadence (condensed — full playbooks in docs/pm-knowledge/facilitation-and-ceremonies.md)

Set-up → refinement → sprint planning → during-sprint → review/close → retro → status. Each
maps to OpenProject via `docs/openproject-concepts-and-pm.md`. Always: a **Version** per
sprint with a written goal; pull a realistic refined set (respect velocity); on close,
verify AC, close done, **move incomplete WPs to the next version**, note carry-over.

The dedicated **backlog-grooming pass** (health scorecard, Definition of Ready, splitting,
ready-runway) is its own procedure — **REQUIRED SUB-SKILL:** use `backlog-refinement` (`/op-refine`)
for that, rather than improvising a refinement pass here. Likewise the **in-sprint / close-out
ceremonies** (standup, review, DoD-gated close, retro) are **`sprint-operations`**, and the
numbers (velocity/burndown/throughput) are **`delivery-metrics`**. This skill supplies the CRUD they
execute.

## New project setup (provisioning convention)

When you **create a new project**, apply the standing provisioning steps — full recipe in
`docs/openproject-project-provisioning.md`. The concrete instance IDs (admin group/role, type
IDs, backlogs mapping) live in the auto-loaded **instance scratchpad** → `## Provisioning IDs`
(already in context — no lookup; see CLAUDE.md → "Instance scratchpad"). If you dispatch a
subagent to do the work, **pass those IDs into its prompt** — subagents don't inherit the scratchpad.

1. **Enable the work-package types** it needs — new projects seed only Task/Milestone/Summary
   task; the types link is read-only via MCP/APIv3, so set `p.types = …` in the Rails console.
2. **Add the "All-Projects Admins" group** (Project admin role) and propagate via
   `Groups::CreateInheritedRolesService` — the org's "full rights in every project, not instance
   admin" pattern. Goes on **every** project.
3. **Delivery projects only:** enable the **Backlogs** module (story points + burndown). **Do
   NOT** enable it on intake/funnel projects (their Idea/Use-case types aren't story types).
4. **Register the project in the scratchpad** — add it to `## Projects` (`#id → purpose`) for
   navigation, and update `## Provisioning IDs` `backlogs_enabled_on` / `backlogs_off_on`.

## Multi-track operation (parallel, interrelated projects)

One project (or sub-project) per track; a parent project for the portfolio. Cross-track
dependencies = relations (`precedes`/`blocks`) on the cross-project Gantt. Portfolio view =
a cross-project query. Persist per-track durable context (goals, decisions, risks, velocity)
in `redis-memory` (`docs/memory-mcp.md`), namespaced by track; search it before planning.

## Common mistakes

| Mistake | Do instead |
|---|---|
| Creating WPs without reading existing ones | List/get project, versions, statuses, items first |
| PATCH without `lockVersion` | Read it back and send it (avoids lost updates) |
| Bulk/destructive change unconfirmed | Confirm scope, then report exactly what changed |
| Duplicating cadence/theory inline | Cross-reference `pm-craft` + `docs/` |
| Asserting Action Boards' edition gating from memory | Free in Community on **17.3+**, Enterprise before — verify the running version; on pre-17.3 Community drive Kanban via statuses + queries |
| Reclassifying a user-facing capability as a bare Task to skip AC | Keep it a Story/Feature. Quick-capture is fine, but write the AC stub, flag "unrefined" in the description, and schedule refinement before it enters a sprint — don't downgrade the type to dodge the quality bar |
| Guessing type/status/priority IDs to save a call | Resolve them (`openproject:list_statuses`, types/priorities) — IDs vary per instance |
| Padding estimates | Re-estimate; keep points relative & consistent |
| Treating a `relates` **422 "already been taken"** as a failure | Benign — the link already exists; check `openproject:list_work_package_relations` first, or treat that 422 as a no-op success |
| Putting custom-field values in the **description** | Write the real `customFieldN` via APIv3 PATCH (+ read back); description text is invisible to filters/roadmap/sort |
| Writing an **unprovisioned** list-field value | Only provisioned custom_options exist; APIv3 can't list/create them — add via Rails (`provision.rb`) first |
| Listing "all" work packages but getting only **open** ones | APIv3 default = open; pass `active_only=false` (or a `status` filter operator `*`) for closed/Converted/Rejected |
| Leaving decisions only in chat | Decisions → WP comments; durable knowledge → Wiki + `redis-memory` |

This agent is also the outward gateway: when acting on an a2adapt request, note which
contact asked and report results back through the same channel (`docs/a2adapt.md`).
