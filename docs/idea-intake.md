# Idea intake — methodology & OpenProject mapping

Reference for the `openproject-intake` skill. The skill is the **discovery** arm; it produces a
high-level **Now/Next/Later** roadmap and hands approved Epics to delivery (`openproject-pm`,
`op-triage`). Theory lives in `pm-craft` + `docs/pm-knowledge/`.

## Methodology grounding
- **Dual-track agile** — discovery runs as its own track, separate from delivery. This skill *is*
  the discovery track: validate *what* and *why* before delivery commits to *how*.
- **Lean idea funnel / stage-gate** — ideas enter wide and are filtered: New → Under review → In
  discussion → Approved, with Rejected/Deferred as attrition. Light gates, no bureaucracy.
- **Opportunity Solution Tree** — a **Use case** ≈ an opportunity (a real user need/scenario); an
  **Idea** ≈ a candidate solution. One opportunity justifies many solutions and vice-versa, hence
  the many-to-many `relates` link rather than a hierarchy.
- **RICE** (default prioritization) — transparent, comparable, sortable; good for an idea funnel.
- **WSJF** (optional SAFe profile) — Cost of Delay ÷ Job Size; enable only if running a SAFe
  portfolio. Not provisioned by default (YAGNI).
- **Now / Next / Later** (Cagan/ProdPad school) — a high-level product roadmap without false dates;
  commitment decreases with distance.

## Scoring
**RICE score = Reach × Impact × (Confidence ÷ 100) ÷ Effort** — computed by the skill (OpenProject
has no formula fields) and written to the `RICE score` field.
- Reach: users (or events) affected per period (integer).
- Impact: 3 massive / 2 high / 1 medium / 0.5 low / 0.25 minimal.
- Confidence: 100 high / 80 medium / 50 low (%).
- Effort: person-weeks (float).

**WSJF (optional)** = (User/Business value + Time criticality + Risk/Opportunity) ÷ Job size.
Would add four fields to the Idea type; deferred.

## Classification axes
Two **structured single-selects** + one **emergent multi-value** classifier — distinct on
cardinality, governance, and purpose, so they complement rather than duplicate.
- **Track** (single) — domain/stream → roadmap swimlane, maps to a delivery track/project. Seed `General`.
- **Lens** (single) — nature of the idea: Strategic, Tactical, Philosophical, Applied (extensible).
- **Tags** (**multi-value**) — cross-cutting, emergent themes orthogonal to Track/Lens
  (`security`, `mobile`, `tech-debt`, `ai`, `q3-okr`, `customer-acme`…). Many per item, fast-growing
  vocabulary, added on the fly. The long-tail escape-hatch that keeps Track/Lens from bloating.
  Propagates Idea → Epic → delivery stories, so it is genuinely cross-cutting across the lifecycle.

OpenProject has **no native tags/labels**; Tags is implemented as a global **multi-value list
custom field** (`multi_value: true, is_for_all: true`). Project Categories are project-scoped and
single-value, so they cannot serve as a cross-cutting classifier.

Three axes is the ceiling — push new emergent dimensions into Tags rather than adding a 4th axis.

## Concept → OpenProject object mapping
| Concept | OpenProject object |
|---|---|
| Idea (unit of decision) | Work package **type Idea**, project **Intake** |
| Use case (opportunity) | Work package **type Use case**, project **Intake** |
| Idea ↔ use case (justification) | relation **`relates`** (many-to-many) |
| Duplicate at screening | relation **`duplicates`** |
| RICE inputs / score | custom fields Reach, Impact, Confidence, Effort, **RICE score** |
| Track / Lens | custom single-select fields |
| Tags (cross-cutting, emergent) | custom **multi-value** list field; propagated Idea→Epic→stories |
| Stage of the funnel | **statuses** New / Under review / In discussion / Approved / Converted / Rejected / Deferred |
| Decision + rationale | work package **comment** (history is the audit log) |
| Roadmap item | Work package **type Epic**, project **Roadmap** |
| Now / Next / Later | custom field **Horizon** on the Epic |
| converted_to | `relates` Idea→Epic + **Origin** block in Epic description + "Converted → Epic #M" comment + Idea status Converted |

## Schema IDs
Authoritative source: the instance scratchpad `## Intake schema` section (injected by the
SessionStart hook; written from `provision.rb`'s `SCHEMA_JSON`). The IDs below are illustrative defaults from one provisioning run
(verify against the scratchpad / live instance):
- Types: Idea 8, Use case 9, Epic 5.
- Fields: Reach cf1, Impact cf2, Confidence cf3, Effort cf4, RICE score cf5, Track cf6, Lens cf7, Horizon cf8, **Tags cf9 (multi-value)**.
- Statuses: New 1, Under review 15, In discussion 16, Approved 17, Converted 18, Rejected 14, Deferred 19.
- Projects: Intake 5, Roadmap 6.
(Re-run `provision.rb` after any OpenProject reseed; it is idempotent and reprints the map.)

## Access layers
- **Provisioning** (once, idempotent): Rails `provision.rb` — types, fields, statuses, workflow,
  projects. APIv3/MCP cannot create these.
- **Runtime**: community `openproject` MCP (CRUD, relations, comments, search).
- **Fallback**: APIv3 PATCH for custom-field values (list fields take a `custom_option` href; send
  the current `lockVersion`).
