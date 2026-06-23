---
name: sprint-operations
description: Use when running or closing a sprint in OpenProject — daily standup, surfacing/aging blockers, sprint review, verifying work against a Definition of Done, closing the sprint with carry-over, or running a retrospective. Triggers — "run standup", "what's blocked", "sprint review", "close the sprint", "Definition of Done / DoD", "carry over", "retro / retrospective", "did we finish". NOT sprint planning (op-sprint-plan) or backlog grooming (backlog-refinement).
---

# sprint-operations — run, close, and learn from the sprint

Drives the in-sprint and end-of-sprint ceremonies that turn a planned sprint into closed work +
improvements: **standup, blocker resolution, review, DoD-gated close, retro.** Planning is
`op-sprint-plan` (upstream); grooming is `backlog-refinement`; metrics come from `delivery-metrics`;
PM theory is `pm-craft` + `docs/pm-knowledge/facilitation-and-ceremonies.md`.

Core principle: **"Done" is verified against a Definition of Done, not asserted.** An item is not
closed because someone says so — it is closed because it meets the DoD.

## When to use
- Daily standup; "what's blocked"; sprint review; closing a sprint; retro.
- **NOT** for: planning/committing a sprint → `op-sprint-plan`; grooming the backlog →
  `backlog-refinement` / `/op-refine`; computing velocity/burndown → `delivery-metrics`.

## Definition of Done (canon — the close gate)
An item is **done** only when ALL hold. If the project has a Definition of Done document (ask the user to provide it, or check the version/project description), apply that instead.

1. **All acceptance criteria met** (checkboxes verified, not just present).
2. **Reviewed** — change reviewed/merged where applicable.
3. **Tested** — the relevant tests pass.
4. **No open blockers** (no open `blocks` relations).
5. **Docs/changelog** updated if user-facing.
6. **Demoable** — deployed/available in the target environment.
7. **Accepted** by the requester/PO.

DoD is the symmetric partner of the Definition of Ready (`backlog-refinement`): DoR gates entry,
DoD gates exit.

## Closing a sprint (`/op-sprint-close`)
1. Pull the sprint version's items (`delivery-metrics` for the burndown/remaining snapshot).
2. **For each item proposed as complete, verify it against the DoD.** Any unmet criterion →
   **do NOT close it**; report the specific gap and leave it open (or move to a "needs work" state).
   Closing a DoD-failing item is forbidden — letter and spirit.
3. Close the items that pass the DoD.
4. **Carry incomplete items to the next version** with a written carry-over reason (one line each).
5. Snapshot velocity/burndown via `/op-metrics`; record the sprint outcome.
6. Gate: confirm before bulk-closing / bulk-moving; report exactly what changed.

## Standup (`/op-standup`)
Current-sprint board state by status + **blockers** + **aging**: in-progress items not updated in
> N days, and items blocked > N days (N = 3 business days unless the user specifies `--aging-days`).
Re-plan toward the sprint goal; this is a working session, not a status report.

**Blocked-work loop (don't just detect):** for each blocked item — name the **impediment owner**,
the blocking item, and age; if blocked > N days, **escalate** it explicitly in the report. Surface →
own → escalate, until removed.

## Sprint review (`/op-sprint-review`)
Inspect the increment (DoD-passing items) with stakeholders; collect feedback and turn each piece
into a **follow-up work package** (don't lose it in a comment). Adapt the backlog (hand changes to
`/op-refine`). A working review, not a one-way demo.

## Retrospective (`/op-retro`)
Run a format (went-well / didn't / actions, or Start-Stop-Continue). Pick **a few** improvements and
create an **owned improvement work package** for each (so actions don't evaporate). Record the retro
summary in the sprint version description (wiki pages require manual UI entry — offer the content for the user to paste).

## Common mistakes
- Closing an item that fails the DoD because it's "basically done" — verify, don't assume.
- Carrying work over **without a reason** — always note why.
- Retro actions as talk only — create owned WPs.
- Detecting blockers but not driving them — surface → own → escalate.
- Re-doing planning here — that's `op-sprint-plan`.
