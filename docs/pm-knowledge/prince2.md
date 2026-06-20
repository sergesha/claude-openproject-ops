# PRINCE2 (7th edition) — reference

Primary: https://www.peoplecert.org/ (PRINCE2 7), https://www.axelos.com/.
A structured, process-based method for managing projects; tailorable; strong governance.
Complements agile delivery (PRINCE2 Agile blends the two).

## 7 Principles (must all be applied, or it isn't PRINCE2)
1. Continued business justification (a viable Business Case throughout).
2. Learn from experience.
3. Defined roles, responsibilities & relationships.
4. Manage by stages.
5. Manage by exception (tolerances on the 7 aspects: cost, time, quality, scope, benefits,
   sustainability, risk; escalate only when exceeded).
6. Focus on products (product-based planning).
7. Tailor to suit the project.

## 7 "Practices" (formerly Themes) — applied throughout
Business Case · Organizing · Plans · Quality · Risk · Issues (& change) · Progress.
(PRINCE2 7 also foregrounds **people / sustainability** and the "project performance"
aspects above.)

## 7 Processes (the lifecycle)
- **Starting up a Project (SU)** — is it worthwhile/viable? outline Business Case, team.
- **Directing a Project (DP)** — the Project Board's decisions (authorize stages/exceptions).
- **Initiating a Project (IP)** — the PID, baselines, controls, plans.
- **Controlling a Stage (CS)** — day-to-day PM: authorize work, monitor, handle issues/risks.
- **Managing Product Delivery (MP)** — Team Manager builds & delivers Work Packages.
- **Managing a Stage Boundary (SB)** — plan next stage, update Business Case, lessons.
- **Closing a Project (CP)** — confirm acceptance, handover, evaluate.

## Key management products
Business Case, PID (Project Initiation Documentation), Project/Stage/Team Plans, Risk &
Issue Registers, Quality Register, Daily Log, Lessons Log, Highlight/Checkpoint/End-Stage/
End-Project Reports, Work Package (the PRINCE2 sense = assignment of work to a team).

## → OpenProject mapping

| PRINCE2 | OpenProject |
|---|---|
| Stages | top-level **phases** (parent work packages of type Phase) or sub-projects; the **Gantt** for stage plans |
| Work Package (assignment) | a parent **work package** with children (note: term collides with OpenProject's "work package" = any item) |
| Product breakdown / plans | WBS via **parent/child** WPs + **Gantt/timeline** |
| Business Case, PID, reports | **Wiki** pages / **Documents** |
| Risk Register / Issue Register | dedicated WP **types** (Risk, Issue) + a query, or custom fields |
| Tolerances / manage-by-exception | priority + status + a "needs Board decision" flag; report via a saved query |
| Highlight/End-Stage reports | generated from queries + a Wiki report page |

OpenProject's classic (Gantt-driven, phase-based) features make it a good PRINCE2 home;
combine with Backlogs for PRINCE2-Agile delivery within stages.
