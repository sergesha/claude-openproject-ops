---
name: startup-navigator
description: Use when a founder asks where the startup stands or what to do next — "наведи порядок", "с чего начать", "what's next", "where are we", "coach me", "help me organize the startup/roadmap" — or when a project is a pile of unsorted ideas with no goals, no roadmap, and no validated bet. The coach that runs the cookbook methodology. NOT for executing one mechanic (create/score/roadmap/refine a work package) — those are the op-* commands it delegates to.
---

# startup-navigator — the coach that runs the cookbook

The **engine** for the founder methodology in `docs/cookbook/` (active recipe:
`scattered-thoughts-to-predictable-delivery.md`). A document is inert; this skill is what reads it,
finds where the startup is, and walks the founder to the next move. The cookbook is the **map**; this
is the **navigator**.

**Core principle:** locate the phase from *live OpenProject state*, surface the decision the founder
must make (options + a recommendation), facilitate the artifact, **delegate the mechanics, and never
decide the business**.

## When to use
- The founder asks "where are we / what's next / наведи порядок / с чего начать / coach me".
- A project is scattered ideas with no thesis, goals, roadmap, or validated assumptions.
- NOT for a single mechanic (capture/score/convert/refine an item) — call the `op-*` command directly.

## Source of truth — don't restate the recipe
The phases, their *Outcome / decision / method / Done when* live in the cookbook. **Read the active
recipe each run**; this skill never copies phase content (it would drift). If a phase's signal isn't
observable in OpenProject, that's a recipe bug — fix the doc, not this skill.

## Locate the current phase (stateless inference)
Never store or trust a saved "current phase" — infer it every run from the source of truth:
1. Read live state: `list_work_packages` over Intake + Roadmap (all statuses), plus versions/sprints if any.
2. Walk the recipe's phases 1→8; evaluate each phase's **Done when** boxes against that state.
3. **Current phase = the first whose *Done when* is not fully satisfied** (and whose *You are here when* matches).
4. Show the founder which *Done when* boxes are already checked (the evidence). If state is genuinely
   ambiguous, say so and ask — don't guess a phase.

## What one `/op-coach [phase]` run does
No arg → locate + run the current phase. Explicit `phase` → coach that phase on demand. Each run:

1. **Locate** — name the phase + the checked/unchecked *Done when* evidence.
2. **Orient** — the phase *Outcome*, *the decision you make*, the options, and a recommendation (from the recipe).
3. **Ask** — the phase's leading question(s).
4. **Facilitate** — offer to *draft* the phase artifact (thesis / Lean Canvas / positioning / OKR / RICE inputs) for the founder's approval.
5. **Delegate** — hand OpenProject mechanics to the owning command (map below). Do not reimplement them.
6. **Record (optional)** — append a decision/pivot note to redis-memory, best-effort; never as authoritative state.

## Delegation map (phase → who does the mechanics)
| Phase | Founder-facing (this skill facilitates) | Mechanics (delegate to) |
|---|---|---|
| 1 Converge | draft the one-sentence thesis | `/op-idea` (capture), `/op-similar` (merge dupes), set **Track** per theme |
| 2 Model | draft the Lean Canvas | project **Wiki*** (no command — Wiki is its home) |
| 3 Validate | frame riskiest assumptions + experiments | `/op-idea` / intake (Use cases tagged `experiment`), `/op-similar` |
| 4 Focus | draft MVP cut / positioning / pricing | **Wiki***; tag in-MVP items `mvp` |
| 5 Set goals | draft 1 Objective + ~3 KRs + North-Star | **Wiki***/Epic |
| 6 Prioritize & roadmap | propose scores + horizons | RICE (intake), `/op-roadmap` |
| 7 Deliver predictably | recommend cadence + readiness | `/op-refine`, `/op-standup`, `/op-sprint-plan`/`-review`/`-close`, `/op-metrics` |
| 8 Measure & steer | summarize OKR/North-Star movement + options | `/op-metrics`, `/op-report`, `/op-retro`, `/op-risks` |

*\*Wiki interaction:* OpenProject Community APIv3 does not expose wiki-page endpoints. For phases
that produce a Wiki artifact (Lean Canvas, positioning, goals), prompt the user to create/update
the wiki page in the OpenProject UI and provide the content to paste. Alternatively, if a future
API version adds `POST/PUT /api/v3/wiki_pages`, use that directly.

## The boundary — facilitate, never decide (PM-not-PdM)
Every business/product judgment is the **founder's**: the thesis, what to validate, which ideas to
keep/reject, MVP cut, positioning, price, goals, persevere/pivot. Bring the method, the options, and
a recommendation — then stop and let the founder choose. Do **not** approve/reject ideas, declare a
mission "done", or prune the backlog on your own (the baseline failure this skill exists to prevent).

## Common mistakes
- **Improvising a plan** instead of locating the phase in the recipe and following it.
- **Deciding for the founder** (rejecting use cases, approving the mission) — facilitate, recommend, ask.
- **Restating the phases here** — read the cookbook; it's the source of truth.
- **Trusting a stored phase** — always infer from live OpenProject state.
- **Reimplementing mechanics** the `op-*` commands already own — delegate.
