# Hybrid project management — reference

Primary: PMI / PMBOK 7 (principles & performance domains), PMI **Disciplined Agile** (DA) —
https://www.pmi.org/disciplined-agile.

Hybrid = deliberately combining **predictive** (plan-driven, phase/stage, Gantt) and
**adaptive** (iterative, backlog/sprint) approaches on one endeavour, chosen to fit context
rather than dogma. Common in IT where some parts are well-understood (infra, compliance,
fixed-date integrations) and others are uncertain (product features, UX).

## When hybrid fits
- Fixed scope/regulatory milestones **and** evolving product scope coexist.
- A stage-gated governance/funding model wraps agile delivery inside stages
  (≈ PRINCE2 Agile).
- Hardware/infra (predictive) paced alongside software (agile).
- Stakeholders expect a roadmap/Gantt but the team runs sprints underneath.

## Patterns
- **Predictive shell, agile core** — phases/Gantt at the top; sprints inside delivery phases.
- **Front loaded discovery, then iterate** — predictive analysis/architecture, then adaptive
  build.
- **Stream split** — predictive workstreams (Gantt) + agile workstreams (backlog) under one
  plan, joined by dependencies.
- DA "**Way of Working**": choose the lifecycle (Agile/Lean/Continuous Delivery/Exploratory/
  Program) per team; tailor with goal-driven decisions.

## Choosing the mix (questions to ask the user)
Requirements stability? Regulatory/fixed milestones? Team agile maturity? Stakeholder
reporting needs (roadmap vs flow)? Funding model (project vs product)? Dependency density?

## → OpenProject mapping
OpenProject is well-suited to hybrid because it carries both worlds natively:

| Need | OpenProject |
|---|---|
| Top-level plan / milestones | **Gantt/timeline**, Phase & Milestone WP types |
| Stage gates / governance | phases (parent WPs) + status workflow + Wiki PID/reports |
| Adaptive delivery inside a phase | **Backlogs** (versions-as-sprints, story points, task board) |
| Roadmap for stakeholders | the project **Roadmap** (versions) + Gantt |
| Cross-stream dependencies | WP **relations** (`precedes`/`blocks`) shown on the Gantt |
| Reporting both ways | queries (flow/agile) + Gantt/roadmap (predictive) |

Guidance: pick the lightest governance that satisfies the constraints; make the predictive
parts explicit (Gantt + milestones) and let the adaptive parts run on versions/boards; keep
one source of truth (work packages) so both views derive from the same data.
