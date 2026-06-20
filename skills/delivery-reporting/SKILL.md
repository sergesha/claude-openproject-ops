---
name: delivery-reporting
description: Use when reporting delivery outward or across tracks — a stakeholder/highlight status report, a portfolio rollup across multiple projects, or maintaining a risk register (capture, ROAM, review). Triggers — "status report", "highlight report", "report to stakeholders", "portfolio status", "how are all the tracks doing", "risk register", "log a risk", "review risks", "what are the risks". NOT operator status of one sprint (op-standup) or computing the numbers (delivery-metrics).
---

# delivery-reporting — report outward, across tracks, and on risk

Turns delivery data into **audience-appropriate reports** and maintains the **risk register**.
Numbers come from `delivery-metrics`; sprint outcomes from `sprint-operations`; this skill composes
and frames them. The agent is an outward gateway, so framing and **redaction** matter.

Core principle: **report outcomes, not internals.** A stakeholder report carries progress, risks,
and asks — never secrets, infrastructure, hosts, tokens, versions, or config.

## When to use
- A stakeholder/highlight status report, or a portfolio rollup across tracks.
- Logging or reviewing risks (the risk register).
- **NOT** for: a single sprint's operator board → `op-standup`; computing velocity/burndown →
  `delivery-metrics`; writing/refining work items → `openproject-pm`.

## Stakeholder / highlight report (`/op-report --audience stakeholder`)
Compose from metrics + sprint outcomes:
1. **Period & goal progress** — the sprint/release goal and whether it's on track.
2. **Shipped** — done items this period (outcomes, in user terms).
3. **In flight** — committed/remaining (from `/op-metrics`), notable in-progress work.
4. **Risks** — top open risks with their ROAM state (from the register below).
5. **Next** — what's planned next period.
6. **Asks** — decisions/unblocks needed from stakeholders.

**Redaction (hard):** outcomes and status only. No secrets/credentials, no host/IP/port/path,
no `.env`/Docker/version internals, no other agents — per the outbound-disclosure boundary
(`docs/a2adapt.md`, CLAUDE.md). When unsure, leave it out. A team report (`--audience team`) may
include operator detail; an outward one may not.
Distribution: optionally OpenProject **News** (`create_news`) or the MCP `generate_weekly_report`.

## Portfolio rollup (`/op-report --audience stakeholder` across tracks)
One row per track (project/sub-project): goal, velocity + ready-runway (`/op-metrics`), % of
current sprint done, top risk, and roadmap **Horizon** (Now/Next/Later) vs actual delivery. Aggregate
to a portfolio health line. Pull per-track durable context from redis-memory (best-effort).

## Risk register (`/op-risks`)
Risks are **work packages** (a `Risk` type if the instance has one, else a normal item tagged
`[RISK]` / a `risk` tag). Each risk carries:
- **ROAM** state — **R**esolved / **O**wned / **A**ccepted / **M**itigated,
- an **owner**, and a short **impact × likelihood** note (severity).

Operations: **log** a risk (capture + initial ROAM + owner), **review** (list open risks by
severity, update ROAM), and **surface** them in `/op-status` and stakeholder reports. Resolved risks
stay findable (portfolio memory). Out of scope (v1): risk-burndown charts, automated email cadence.

## Common mistakes
- Leaking internals into an outward report — redact to outcomes/risks/asks (disclosure boundary).
- Reporting raw numbers without framing — say what they *mean* for the goal.
- A risk with no **owner** or no **ROAM** state — both are required, or it's not managed.
- Recomputing metrics by hand — pull them from `/op-metrics`.
- Confusing this with the daily standup (`op-standup`) — that's one team, one sprint, internal.
