---
name: openproject-intake
description: Use when registering, categorizing, scoring, discussing, approving, or rejecting product ideas, use cases, opportunities, or feature requests in OpenProject, and when converting an approved idea into a high-level Now/Next/Later roadmap. The discovery/intake funnel upstream of backlog refinement. Triggers — "register an idea", "идея: …", "capture this idea", "classify/score the ideas", "score by RICE", "what's in the funnel/intake", "review the intake", "approve/reject idea X", "convert X to the roadmap", "show the roadmap".
---

# openproject-intake — idea & use-case funnel → roadmap

Run product **discovery** inside OpenProject: capture ideas and use cases as work packages,
classify and score them, drive them through a lightweight flow, and convert approved ones into a
**Now/Next/Later roadmap**. This is the **upstream** arm. It stops at the roadmap; delivery
(decompose Epic → stories, sprints) is **`openproject-pm`** / **`op-triage`**, and PM theory is
**`pm-craft`**. Read `docs/idea-intake.md` for the methodology + the full field/ID reference.

Core principle: **one idea = one work package** (never a Document — Documents are UI-only, no
API/MCP, no workflow). Ideas and use cases are **parallel** types linked by `relates`
(many-to-many); the **Idea is the unit of decision**.

## When to use
- Someone proposes an idea / opportunity / feature request and it needs to be recorded and triaged.
- You need to classify (Track, Lens), score (RICE), or compare ideas.
- An idea is approved and must become a roadmap item.
- You need to see the funnel or the Now/Next/Later roadmap.
- NOT for delivery work on an already-approved Epic → use `openproject-pm` / `op-triage`.

## Out of scope — project manager, not product manager
This skill **operates the intake conveyor; the human owns the product calls.** It is a funnel
operator (capture, structure, deterministic scoring from inputs the user gives, routing), not a
product strategist. Keep the boundary hard so the role doesn't inflate into an open-ended PdM:

- ❌ Product discovery — user/market/competitor research, value hypotheses, personas, JTBD, OKR setting.
- ❌ Autonomous product decisions — never decide *whether* an idea is worth doing, its priority, or
  the product direction on your own. RICE numbers come from the user (or are flagged estimates the
  user confirms); approval/rejection is the user's call, applied on command.
- ❌ Inventing scope — don't expand an idea beyond what the source provided.
- ✅ In scope — register, classify (Track/Lens/Tags), compute the RICE score deterministically,
  drive the status flow on command, convert approved ideas to the roadmap, hand off to delivery.

If a request needs genuine product judgment, surface it to the user rather than deciding. Ideas
live in OpenProject (the system of record). redis-memory holds *decisions, rationale, and a
lightweight semantic index* of ideas — a short neutral **title + summary only** (no full
descriptions, no secrets, no host specifics). The full ideas stay in OpenProject; the index is a
rebuildable cache (see "Semantic deduplication").

## Provisioning gate (do this first, once)
The custom types/fields/statuses must exist. Their IDs live in the **instance scratchpad**
(injected by the SessionStart hook) → `## Intake schema` (already in context; CLAUDE.md → "Instance scratchpad").
- **Present** → use those IDs (fields are `customFieldN`).
- **Missing/empty** → run `provision.rb` (idempotent), then write its printed `SCHEMA_JSON` into
  the scratchpad `## Intake schema` section, and register `Intake`/`Roadmap` in `## Projects`:
  ```bash
  cd ~/openproject/openproject-docker-compose
  docker compose cp skills/openproject-intake/provision.rb web:/tmp/provision.rb
  docker compose exec -T web bundle exec rails runner /tmp/provision.rb   # prints SCHEMA_JSON=…
  ```
If you dispatch a subagent to provision/triage, **pass the schema IDs in its prompt** (subagents
don't inherit the scratchpad). Always search redis-memory for prior idea/track decisions before a
review pass.

## Quick reference (operation → tool)
| Need | Tool |
|---|---|
| Confirm context | `openproject:list_projects`, `openproject:list_statuses`, `openproject:list_types` |
| Register idea / use case | `openproject:create_work_package` (project Intake, type Idea/Use case) |
| Find duplicates | `openproject:search_work_packages` |
| Set status / fields | `openproject:update_work_package`; custom fields via APIv3 (below) |
| Link idea↔use case↔epic | `openproject:create_work_package_relation` (`relates`) |
| Decision / discussion note | `openproject:add_work_package_comment` |
| Funnel / roadmap view | `openproject:list_work_packages` (filter by type/status/Track/Horizon) |

**Custom-field writes** (MCP may not pass them): APIv3 PATCH with the lockVersion you just read —
```bash
set -a; . ~/openproject/.op-api.env; set +a
curl -s -u "apikey:$OPENPROJECT_API_KEY" "$OPENPROJECT_URL/api/v3/work_packages/<id>" \
  -X PATCH -H "Content-Type: application/json" \
  -d '{"lockVersion":<v>,"customField6":{"href":"/api/v3/custom_options/<id>"}}'
```
Single-select list fields (Impact/Confidence/Track/Lens/Horizon) take a **custom_option href**, not
a raw string. The **multi-value** field **Tags** (customField9) takes an **array** of hrefs:
`{"_links":{"customField9":[{"href":"/api/v3/custom_options/19"},{"href":".../20"}]}}`. Numeric
fields (Reach/Effort/RICE score) take the number directly. IDs in the scratchpad `## Intake schema`.
**Write to the real fields, never the description** — filters, the Horizon roadmap swimlanes and the
RICE sort read only `customFieldN`. After the PATCH, **read the WP back** to confirm the value
persisted. List-field values must be **provisioned** options (APIv3 can't list or create
custom_options — add a new Track/Lens via Rails/`provision.rb` first; never write a free-text value).

## Semantic deduplication (uses the `semantic-search` skill)
Dedup ideas/use-cases **by meaning** via the **`semantic-search`** skill, namespace **`idea`**
(project Intake, types Idea + Use case). At registration, **search before create** (see `/op-idea`):
bands (embedder-calibrated, see `semantic-search`) **≥50%** clear match → offer augment-vs-create;
**30–50%** related → offer `relates`; **<30%** → create. Keep Rejected/Converted indexed too. **Advisory — never block registration.** `/op-intake
--reindex` triggers a full rebuild. The index contract (tags `idea-index`+`wp-index`, KV
`wpidx:idea:<wpId>`, helper `index.sh`, lazy-heal, change detection, fallback) lives in
`semantic-search` — don't restate it here.

## Flow (agent-driven; you move statuses on the user's command)
`New → Under review → In discussion → Approved → Converted`, plus `Rejected`, `Deferred`.
Every transition: write a one-line **rationale comment** (the decision log lives in WP history, not
in a field). No approver roles, no committees — the user decides, you execute.

- **New** — registered, untriaged.
- **Under review** — screen duplicates (link `duplicates`), check scope, set draft Track/Lens.
- **In discussion** — accumulate arguments as comments; link/create **Use cases**; fill RICE.
- **Approved** — decision comment ("why yes"); RICE score frozen.
- **Converted** — see below.
- **Rejected** / **Deferred** — reason comment; stays findable (portfolio memory).

## RICE (default scoring)
Fields on Idea: **Reach**, **Impact** (0.25/0.5/1/2/3), **Confidence** (50/80/100 %), **Effort**
(person-weeks). OpenProject has no formula fields, so **you compute and write** the score:
```
RICE score = Reach × Impact × (Confidence ÷ 100) ÷ Effort
```
Fill RICE by the In-discussion stage; sort the funnel and roadmap by it. (WSJF is an optional SAFe
profile — not provisioned by default; see docs.)

## Classification (two structured single-selects + emergent tags)
- **Track** (single-select) — domain/stream (roadmap swimlane; maps to delivery tracks). Starts
  with `General`; add values as ideas arrive (`provision.rb` merges additively, or add via Rails/UI).
- **Lens** (single-select) — nature: Strategic / Tactical / Philosophical / Applied (extensible).
- **Tags** (**multi-value**, customField9) — cross-cutting, emergent themes orthogonal to Track/Lens
  (e.g. `security`, `mobile`, `tech-debt`, `ai`, `q3-okr`, `customer-acme`). Many per item; add new
  values freely on the fly. This is the escape-hatch — push the long tail here instead of bloating
  Track/Lens or inventing new axes.

Track + Lens required (at least draft) by Under review; Tags optional. Together they answer
portfolio questions like "strategic ideas in Track Platform tagged security". Tags are **truly
cross-cutting**: set on the Idea, propagated to the Epic at conversion, and carried into delivery.

## Conversion Approved → Roadmap (core)
OpenProject Community can't define custom relation types, so `converted_to` is expressed as
`relates` + explicit markers:
1. `openproject:create_work_package` — **Epic** in project **Roadmap**; description starts with an
   **Origin** block: `Origin: Idea #N · RICE <score> · Track <t> · Lens <l> · use cases #a,#b`.
2. Set **Horizon** = Now/Next/Later on the Epic (default **Next**); **copy the idea's Tags** to the
   Epic's Tags field (so cross-cutting filters work on the roadmap).
3. `create_work_package_relation` Idea→Epic (`relates`); add comment `Converted → Epic #M` on the
   Idea; set Idea status **Converted**.
4. **Relate each of the idea's use cases to the Epic** (`create_work_package_relation`, `relates`) —
   they stay in Intake (reusable) as candidate stories. (This is a distinct step from the
   Idea→Epic link in step 3; do both.)
5. Hand the Epic to `openproject-pm` / `op-triage` for delivery.

## Quality bar
- Idea title = **verb + user value** ("Export dashboard to PDF"), not a noun.
- Track + Lens set by Under review; RICE complete by In discussion.
- Decisions always as comments. Use cases written as a concrete scenario (who → wants → so that).

## Common mistakes
- Storing ideas as **Documents** (Idea/Proposal types) — UI-only, no automation. Use work packages.
- Forgetting RICE is **computed by you** — don't expect OpenProject to calculate it.
- Writing list custom fields as raw strings via APIv3 — they need a **custom_option href**.
- **Dumping custom-field values into the description** instead of the real `customFieldN` — invisible
  to filters/roadmap/RICE; PATCH the real field and read back to verify.
- **Inventing option values** (a Track/Lens not provisioned) — only provisioned options exist (Track:
  `General`; Lens: Strategic/Tactical/Philosophical/Applied); APIv3 can't enumerate or create them.
- PATCHing without the current **lockVersion** — causes 409 / lost updates.
- Trying to enable types or create fields via API — only **Rails** (`provision.rb`) can.
- Carrying delivery work here — stop at the roadmap Epic; hand off.
