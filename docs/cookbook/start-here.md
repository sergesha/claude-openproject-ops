# Cookbook — start here

A growing collection of **recipes** for running our startup inside this OpenProject instance.
A recipe is a **methodology** — business moves, decisions, and methods that an **owner reads** to
run the business and an **agent follows** to support it. The thinking leads; OpenProject is only the
instrument where each decision gets recorded. Mechanics are never restated — each step links to the
skill, command, or doc that does the work.

## How to read a recipe (dual-audience contract)

- **Owner (human)** — read **Outcome → Why this phase → The decision you make → Method**. That is the
  business journey and the calls you own.
- **Agent** — read **You are here when → Make it real → Done when**. Self-locate by the business +
  OpenProject state, support the founder's decision, and advance only when every "Done when" box is checked.

## Standing rules (apply to every recipe)

These are the plugin's standing rules (from `context/operating-contract.md`) — not restated here:

- **Facilitate, don't decide (PM-not-PdM).** At every *The decision you make* point the agent lays
  out options + a recommendation; **the owner decides**. Never make autonomous product/marketing calls.
- **No secrets in the repo.** Concrete addresses, ports, domains, credentials and host specifics live
  only in gitignored local files.
- **Read before write; send `lockVersion` on PATCH; confirm bulk/destructive actions.**
- **No bluffing.** A genuine value/scope gap is a question for the human, not a writing task.

## The recipe template

Every recipe is a sequence of phases; **every phase uses this exact block** so recipes stay
consistent, owner-readable, and agent-followable:

```
## Phase N — <Name>
**Outcome:** the business state this phase produces.              (owner)
**You are here when:** entry signals — business + observable OpenProject state.  (agent)
**Why this phase:** 2–4 sentences (the owner's rationale).        (owner)
**The decision you make:** the founder call(s) + the method that forces it,
  the options I lay out, and the recommendation rule.            (owner; agent facilitates)
**Method:** the named methodology + 1–2 lines on how to run it.  (owner)
**Make it real:** lightweight steps + where the artifact lives in OpenProject
  (and which /op-* tool helps, if any).                          (agent)
**Done when:** checkable exit criteria.                          (both)
```

## Recipes

| Recipe | Use when | Status |
|---|---|---|
| [`scattered-thoughts-to-predictable-delivery.md`](scattered-thoughts-to-predictable-delivery.md) | A pile of unsorted ideas, no clear goals/roadmap — need to get to disciplined, predictable delivery | ready |

## Adding a recipe

1. Copy **The recipe template** for each phase; fill `Outcome … Done when`.
2. Keep it thin — **link** to the skill/command/doc that owns the mechanics; don't restate them.
3. Register a row in the **Recipes** table (`Use when`, `Status`).
4. For anything non-trivial, brainstorm it first (spec in `.superpowers/specs/`), then write it here.
5. Run `scripts/check-cookbook.sh` — template-conformance, link integrity, and no-leak must pass.
