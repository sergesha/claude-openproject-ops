# Recipe: from scattered thoughts to predictable delivery

> Read `start-here.md` first for the dual-audience contract and standing rules.
> A founder's methodology — the business moves that turn a pile of ideas into clear goals and
> predictable results. OpenProject is the instrument where each decision is recorded; the work here
> is the **thinking**, not the tooling.
> This is a **quarterly loop, not a line** — Phase 8 resets Phases 5–6 (or Phase 3 on a pivot).

**The discipline in one line:** nothing gets *built* (7) that doesn't serve a *goal* (5) that
doesn't come from a *validated bet* (3).

**The loop at a glance:**

```
scattered ideas
  → 1 Converge → 2 Model → 3 Validate → 4 Focus
  → 5 Set goals → 6 Prioritize & roadmap → 7 Deliver → 8 Measure & steer
  ↺ back to 5/6 each cycle  (or back to 3 on a pivot)
```

## Phase 1 — Converge
**Outcome:** One written thesis (the vision) and the scattered ideas grouped into themes — a map instead of a pile.
**You are here when:** you have many unsorted ideas at mixed altitudes (vision vs scenario vs feature vs task) and no single statement of what you're building or why.
**Why this phase:** You can't prioritize or set goals on top of noise. Naming the one thesis — the change you're betting the company on — and grouping the rest by theme turns scattered thoughts into navigable territory and reveals what's actually one idea versus many.
**The decision you make:** *What is the single thesis under all of this?* — I draft a thesis from your notes plus a proposed clustering; recommendation rule: one sentence a stranger understands, betting on one change in the world; you pick and sharpen it.
**Method:** Vision / "why" (Sinek's golden circle) + affinity clustering of the brain-dump into 3–7 themes (one **Track** per theme).
**Make it real:** dump every thought into Intake as Idea/Use case work packages (`/op-idea`); set a **Track** on each to group by theme; merge duplicates with `/op-similar`; write the thesis on the project overview/Wiki.
**Done when:**
  - [ ] a one-sentence thesis is written and visible;
  - [ ] every captured item has a Track;
  - [ ] obvious duplicates are merged.

## Phase 2 — Model
**Outcome:** The business on one page — who it's for, the problem, the value, the economics — coherent enough to critique.
**You are here when:** the thesis exists but the business model (customer, value, channels, revenue) is implicit and unstated.
**Why this phase:** A one-page model forces the parts to fit: a real customer segment, a problem worth paying to solve, a unique value proposition, plausible channels and economics. Gaps and contradictions surface *before* you spend money building.
**The decision you make:** *Who exactly is the customer, and why would they pay?* — I draft the nine boxes from what we know and flag the riskiest blanks; recommendation rule: name a reachable ICP and a problem they already try to solve today; you decide.
**Method:** **Lean Canvas** (problem · customer segments/ICP · unique value prop · solution · channels · revenue · cost · key metrics · unfair advantage).
**Make it real:** write the Lean Canvas as a project **Wiki** page (OpenProject has no canvas object — the Wiki is its home); link the ideas/use cases that populate each block.
**Done when:**
  - [ ] a Lean Canvas page exists with no empty critical block;
  - [ ] the ICP is named;
  - [ ] the top 2–3 riskiest assumptions are listed (they feed Phase 3).

## Phase 3 — Validate
**Outcome:** Evidence — not opinion — on whether the riskiest assumptions hold: problem-solution fit, or a clear pivot.
**You are here when:** the canvas rests on unproven beliefs and nothing has been tested with real customers.
**Why this phase:** Most startups die building something nobody wants. Testing the assumptions that would kill the business — cheaply, before building — is the highest-return work an early founder does.
**The decision you make:** *Which assumption do we test first, and does the evidence say persevere or pivot?* — I rank assumptions by (impact-if-false × uncertainty) and propose, for each, the cheapest experiment with a success threshold; you choose what to test and read the result.
**Method:** **Customer Development** (problem/solution interviews) + **continuous discovery** (opportunity-solution tree) + riskiest-assumption tests (interview, landing page, concierge, Wizard-of-Oz).
**Make it real:** capture each experiment as a Use case tagged `experiment` with a written hypothesis + success threshold; record results as comments; a falsified core assumption becomes a logged pivot decision on the thesis.
**Done when:**
  - [ ] each top assumption has a run experiment with a recorded result;
  - [ ] a persevere/pivot call is logged;
  - [ ] problem-solution fit is claimed only with evidence behind it.

## Phase 4 — Focus
**Outcome:** A sharp, defensible scope — what the MVP is (and isn't), how you're positioned, how you'll charge.
**You are here when:** assumptions are validated but scope is still everything-for-everyone, with no positioning and no price.
**Why this phase:** Validation tells you what *could* work; focus decides the smallest, sharpest bet to bring to market. These are the hardest-to-reverse calls and they gate all delivery.
**The decision you make:** *What's in the MVP, what's our positioning, what's the price?* — I draft an in/out cut, a positioning statement, and 2–3 pricing options with trade-offs; you decide (or defer pricing explicitly).
**Method:** **April Dunford positioning** (competitive alternative → unique attributes → value → best-fit customer) + **MVP** scope cut (smallest test of the core bet) + value-based **pricing/packaging**.
**Make it real:** Wiki pages "MVP scope", "Positioning", "Pricing"; tag the in-MVP use cases `mvp`; everything else stays in the funnel as Later.
**Done when:**
  - [ ] MVP in/out is decided and the in-set is tagged;
  - [ ] a positioning statement exists;
  - [ ] a pricing hypothesis exists (or is explicitly deferred).

## Phase 5 — Set goals
**Outcome:** Clear, conscious goals — one objective with measurable key results for the quarter, and a single North-Star metric.
**You are here when:** you know what to build but "success" is undefined, so progress can't be judged.
**Why this phase:** Goals convert strategy into a yardstick. An objective plus key results make "are we winning?" answerable; a North-Star metric aligns everyone on the one number that proxies real customer value.
**The decision you make:** *What does success look like this quarter?* — I draft 1 Objective + ~3 outcome (not output) Key Results from the validated bet and propose a North-Star; recommendation rule: KRs measure customer/business outcomes, never "shipped X"; you commit them.
**Method:** **OKRs** (Doerr) — one ambitious Objective + ~3 measurable Key Results · a **North-Star metric** with a supporting **AARRR** funnel.
**Make it real:** a Wiki "OKRs Q<x>" page (or an Epic per Objective with KRs as a checklist); name the North-Star and where it will be measured. Keep it light — one objective, not ten.
**Done when:**
  - [ ] one Objective with ~3 measurable KRs is committed;
  - [ ] a North-Star metric is named;
  - [ ] each KR has a current baseline.

## Phase 6 — Prioritize & roadmap
**Outcome:** A short, ordered, outcome-based Now/Next/Later roadmap where everything "Now" serves the OKR.
**You are here when:** you have goals plus a backlog of ideas but no agreed order — or items unrelated to the goal are competing for attention.
**Why this phase:** Sequence is strategy. Scoring forces honest comparison; an outcome roadmap tied to the OKR keeps the team from drifting into pet features.
**The decision you make:** *What's Now vs Next vs Later, and does each "Now" item serve the OKR?* — I compute scores from your inputs and flag any "Now" candidate that doesn't ladder up to a Key Result; you set the horizons.
**Method:** **RICE/ICE** prioritization + an **outcome-based Now/Next/Later** roadmap (horizons of confidence, not dated feature lists).
**Make it real:** score ideas (intake RICE fields); convert the chosen ones to Roadmap **Epics** with a Horizon (`/op-roadmap`); push anything that doesn't serve the current OKR to Later.
**Done when:**
  - [ ] the top ideas are scored;
  - [ ] a Now/Next/Later roadmap exists;
  - [ ] every "Now" Epic links to a Key Result.

## Phase 7 — Deliver predictably
**Outcome:** Work shipping at a forecastable rate — a cadence, ready work, and metrics that let you predict "when".
**You are here when:** a roadmap Epic is "Now" but there's no ready, estimated, sequenced delivery work and no measured flow.
**Why this phase:** "Predictable results" is a delivery discipline: ready work + a steady cadence + flow metrics turn a roadmap into reliable forecasts instead of hope.
**The decision you make:** *Which cadence fits us, and is the work ready to forecast?* — I recommend the lightest cadence for two founders and produce a readiness/refinement plan; you sign off.
**Method:** lightweight **flow** (Kanban/Scrumban for a tiny team) or short Scrum sprints · a **Definition of Ready** · **velocity/throughput forecasting** (`docs/pm-knowledge/`).
**Make it real:** decompose "Now" Epics into ready, estimated stories (`/op-refine`); run the cadence (`/op-standup`, `/op-sprint-plan`, `/op-sprint-review`, `/op-sprint-close`); track velocity/throughput (`/op-metrics`).
**Done when:**
  - [ ] a cadence is chosen;
  - [ ] "Now" Epics have ready, estimated stories;
  - [ ] at least one cycle is closed with a measured throughput/velocity — a forecast now exists.

## Phase 8 — Measure & steer
**Outcome:** A judged result — did the bet move the North-Star/OKR? — and a decision to persevere, pivot, or pick the next bet, feeding the loop.
**You are here when:** a cycle/quarter has closed and the OKR/North-Star outcome hasn't been reviewed against the bet.
**Why this phase:** A startup compounds by learning faster than it burns. Reviewing outcomes (not output), grading the OKR, and explicitly deciding persevere-or-pivot is what makes the next quarter smarter — and closes the loop back to goals and roadmap.
**The decision you make:** *Did it work, and what's the next bet?* — I summarize KR/North-Star movement versus target and lay out continue/cut/pivot options plus the next candidate objective; you decide.
**Method:** **OKR grading** + **validated learning** (build-measure-learn) + **pivot-or-persevere** + **Bullseye** channel testing for growth.
**Make it real:** score the OKR + North-Star (`/op-metrics`, `/op-report`); run the retro (`/op-retro`); update risks (`/op-risks`); fold learnings back into Ideas/RICE and the next OKR — return to **Phase 5/6** (or **Phase 3** if pivoting).
**Done when:**
  - [ ] the OKR is graded and the North-Star movement is recorded;
  - [ ] a persevere/pivot/next-bet decision is logged;
  - [ ] the next cycle's goals/roadmap are updated — the loop is closed.

## Common mistakes
- Jumping to Phase 7 (building) before Phases 3–5 (a validated bet and clear goals) — shipping fast in the wrong direction.
- **Output** goals instead of **outcome** goals — "shipped feature X" is not a Key Result.
- A roadmap of dated features instead of outcomes laddering to the OKR.
- Treating this as a line — it is a **quarterly loop**; Phase 8 resets Phases 5–6.
- Leaving mixed altitudes in the funnel (vision vs feature vs task) — separate them in Phase 1.

## When to stop and ask the founder
Every genuine business or product judgment — the thesis, what to validate, the MVP cut, positioning,
price, the goals, persevere-or-pivot — is the **founder's** call. The agent brings the method, the
options, and a recommendation; the founder decides. Facilitate, never fabricate.
