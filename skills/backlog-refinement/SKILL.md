---
name: backlog-refinement
description: Use when grooming or refining an existing delivery backlog in OpenProject — assessing backlog health, finding what is not ready for the sprint, applying a Definition of Ready, splitting oversized epics/stories, re-ranking, or replenishing the ready queue. Triggers — "refine the backlog", "groom the backlog", "груминг", "backlog refinement", "довести бэклог до ready", "backlog health", "what's not ready for the sprint", "Definition of Ready / DoR", "split this epic/story", "прибраться в бэклоге", "replenish the ready queue". NOT for new ideas (openproject-intake) or committing a sprint (op-sprint-plan).
---

# backlog-refinement — groom the delivery backlog to ready

Owns the **repeatable grooming procedure** for an existing *delivery* backlog: diagnose its
health, apply a Definition of Ready, propose a refinement plan, and — after sign-off — make the
edits. PM theory lives in **`pm-craft`** + `docs/pm-knowledge/facilitation-and-ceremonies.md`;
work-package CRUD/auth lives in **`openproject-pm`**; this skill is the *workflow* that drives
them. Read those rather than restating them.

Core principle: **refinement makes work *ready*; it does not commit it to a sprint** (that is
`op-sprint-plan`). Diagnose before you touch anything; **never write without the sign-off gate.**

## When to use
- Grooming/refining a backlog, or asking "what's not ready / is the backlog healthy".
- Splitting an oversized epic/story, writing missing AC/estimates, re-ranking, deduping.
- Scrumban: replenishing the ready queue.
- **NOT** for: brand-new ideas/use cases or raw inbound triage → `openproject-intake` / `op-triage`;
  committing items into a sprint/version → `op-sprint-plan`; estimation *theory* →
  `docs/pm-knowledge/estimation-and-metrics.md` (this skill *applies* estimates, never teaches them).

## The session (recipe — produce these outputs in order)
Command `/op-refine [project] [--runway N] [--top N] [--stale-days N]` or a trigger phrase.

1. **Context (read-before-write).** Via `openproject-pm`: the project + its types/statuses/versions/
   members, **velocity** (closed versions or redis-memory), and the project's **framework**. Search
   `redis-memory` for prior decisions on the track. Ambiguous which project/track → ask, don't guess.
2. **Define the delivery backlog.** A priority-sorted query, **excluding intake/new** (status=New
   with no version is `op-triage`'s zone). State the query you used.
3. **Backlog-health scorecard (read-only).** Always produce this table over the top-`N` (default 30):

   | Metric | How | Signal |
   |---|---|---|
   | Ready coverage | % of top-N passing DoR | top not ready |
   | Ready runway | ready-SP ÷ velocity → sprints of ready work | < 2 sprints = risk |
   | Oversized | count ≥ 13 SP not split | must split |
   | No estimate | missing story points | DoR #3 |
   | No AC | missing acceptance criteria | DoR #2 |
   | Orphans | no parent epic | DoR #6 |
   | Stale | no update > `--stale-days` (default 60) | review/drop |
   | Possible duplicates/overlap | semantic `similar()` over `backlog-index` (`semantic-search`) | combine/delete/split — discuss, never auto-merge |
   | Blocked | open `blocks` relations | resolve dependency |
   | Priority inversion | high-prio not-ready above ready low-prio | re-rank |
   | WIP (Scrumban) | in-progress vs limit | only if a limit is set |

4. **Select candidates.** Top of backlog up to the ready-runway target, plus everything flagged
   above, within `--top`.
5. **Refinement plan.** Per candidate, the concrete action vs the DoR: write AC / set estimate /
   split into N (with proposed child titles) / re-rank / link to epic / **resolve duplicate/overlap
   (combine / delete / split — see below)** / **escalate if value is unclear** (see boundary below).
   Nothing is written yet.
6. **GATE — sign-off.** Show the scorecard + the plan as a change-set ("18 edits on 9 items: 3
   splits, 5 AC, 4 estimates…"). Wait for approval; selective approval is fine. Bulk/destructive
   actions (mass re-rank, closing parents on split) get explicit confirmation.
7. **Execute** approved edits via `openproject-pm` (read `lockVersion` → PATCH/POST; split = create
   children, relink, transition the parent; set AC/estimate/priority/parent/relations).
8. **Report + remember.** Before/after **ready coverage** and **ready runway**, the list of changes,
   and what was escalated. Persist decisions/patterns/updated velocity to `redis-memory`.

## Duplicate & overlap resolution (combine / delete / split)
Detect by **meaning, not titles**: via the **`semantic-search`** skill (namespace `backlog`), pull
near-dup pairs from the `backlog-index` — for each item `similar(text, "backlog-index")`, collect
pairs **≥50%** (duplicate candidate) and **30–50%** (overlap to discuss) — embedder-calibrated bands,
see `semantic-search`. Read the bodies before judging. Per cluster, recommend:
- **combine** — consolidate description/AC into one item, `relates` the rest, close the redundant as
  `duplicates` (OpenProject has no native merge); preserve history — don't silently delete.
- **delete** — only a genuinely redundant, empty item.
- **split** — partial overlap: extract the shared slice, or split an over-broad item (ties into the
  oversized-split guidance).
**Advisory — present in the change-set at the GATE; the human decides, then execute.** Surface any
story-point double-count so runway math isn't inflated.

## Definition of Ready (canon — the bar in step 3/5)
A story/feature is **ready** when ALL hold. If the project has a wiki page **`Definition of Ready`**,
read and apply that instead (log "using project DoR").

1. **Value clear** — title = user-visible value (INVEST).
2. **Acceptance criteria** present, Gherkin (Given/When/Then), testable, as checkboxes.
3. **Estimated & small** — an estimate is set; ≤ 8 ready, 9–12 split candidate, **≥ 13 must split**.
   Estimate field = **story points** if the backlogs module is enabled, otherwise the project's
   configured estimate (`estimatedTime` / "Work", or a custom field). Detect which at step 1; the
   8/13 thresholds are story-point values — rescale if the unit differs.
4. **Priority** set.
5. **Dependencies** identified and non-blocking.
6. **Parent epic** linked; type/category set.
7. **No open questions.**

Bug variant of #1–2: repro steps + expected/actual + severity→priority.

## Framework → runway rubric (detect, don't impose)
- **Scrum** — continuous ceremony (~10% capacity); runway target = *N sprints* of ready work
  (`facilitation-and-ceremonies.md`).
- **Scrumban/Kanban** — this is **replenishment**: refill the ready queue when WIP drops below the
  limit; runway = ready-queue depth vs WIP, *not* sprints (`kanban-scrumban.md`).
- **PRINCE2/predictive** — clarify work packages before a stage; runway by the stage plan, not
  velocity. Do **not** force story points / sprints.

## The hard boundary — refine, don't invent (PM, not PdM)
Bring to ready only what is **already captured**. If an item's value/scope is genuinely unclear,
**stop and ask the owner** — do not fabricate acceptance criteria, invent product scope, or write
placeholder AC to clear the gate. A value gap is a question, not a writing task. (This and the
no-bluffing / outbound-disclosure / read-before-write rules are the repo's standing working
agreements — see `CLAUDE.md`; they are not restated here.)

## Common mistakes
- Producing prose instead of the **health scorecard** — always emit the table (ready coverage +
  runway are the headline numbers).
- Refining **intake/new** items here — that is `op-triage`; this skill grooms the delivery backlog.
- **Committing** the refined items into a sprint — stop at *ready*; `op-sprint-plan` commits.
- Writing AC for an item whose value is unclear — escalate instead.
- PATCHing without the current **lockVersion** — 409 / lost update.
- Detecting duplicates by **title only** or **auto-merging** them — match by meaning
  (`semantic-search`, `backlog-index`) and discuss **combine/delete/split**; the human decides.
