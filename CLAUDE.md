# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`claude-openproject-ops` is a **distributable Claude Code plugin** for a **multi-role agent** around a
self-hosted **OpenProject Community Edition** instance. Working language: **English**. End goal:
skills + commands + settings + hooks + MCP wiring packaged as an installable plugin.

Four interlocking roles → their skills (details live in each skill):
1. **Certified PM craft** (Agile/Scrum/Kanban/PRINCE2/SAFe/hybrid) → `pm-craft` + `docs/pm-knowledge/`.
2. **DevOps** (Docker-slim deploy/upgrade/backup) → `openproject-devops` + `docs/openproject-selfhost.md`.
3. **Lifecycle driver (PM)** (backlog/sprints/triage/report across parallel tracks) → `openproject-pm`;
   discovery funnel → `openproject-intake`; backlog grooming → `backlog-refinement`.
4. **Networked agent** — durable memory in `redis-memory-mcp`, outward channel via `a2adapt`.

## Layout

```
.claude-plugin/   plugin + marketplace manifests
skills/           pm-craft · openproject-pm · openproject-devops · openproject-intake ·
                  backlog-refinement · delivery-metrics · sprint-operations · delivery-reporting ·
                  continuous-learning · semantic-search · startup-navigator
commands/         /op-* slash commands (setup, status, triage, refine, metrics, sprint-*, report, risks, release, …)
context/          the runtime operating contract (single source of truth for standing rules)
hooks/            SessionStart hook — injects the contract + instance scratchpad into every session
docs/             primary-source reference — READ before non-trivial work; docs/pm-knowledge/ catalog
templates/        committed scaffolding templates (op-state.example.md — instance scratchpad schema)
scripts/          op-state-path.sh · setup.sh · check-cookbook.sh · check-session-context.sh · test-*
openproject/      deployment workspace (gitignored)
deploy/           external-access reverse-proxy + restore runbook (committed)
identity/         a2adapt identity bio/persona (committed)
```

Treat `docs/*` as the source of truth distilled from primary docs; if OpenProject (or a
framework) changes, re-verify against the primary source and update `docs/`.

**`docs/` is documentation ONLY.** Working / intermediate artifacts — superpowers specs & plans,
design drafts, eval / test logs, status trackers — must NOT live under `docs/` (or anywhere
tracked). They go in a **gitignored `.superpowers/`** (specs/, plans/, logs/). The superpowers
skills default to `docs/superpowers/`; override that path to `.superpowers/` every time.

## Setup & integrations (one-time — see docs/commands)

- **Deploy / upgrade / backup OpenProject:** `/op-setup` + `docs/openproject-selfhost.md`
  (Docker slim; a `-slim` tag is required).
- **Write MCP / redis-memory / a2adapt** are **install-with-approval** — `docs/openproject-mcp.md`
  · `docs/memory-mcp.md` · `docs/a2adapt.md`. (The official `/mcp` is read-only/Enterprise; writes
  go via a community MCP over APIv3.)

## Local deployment notes (instance specifics are NOT committed)

This is a distributable plugin: **concrete addresses, ports, domains, credentials and host
specifics live ONLY in gitignored local files — never in this repo.** For a real deployment the
actual values are kept in:
- `openproject/openproject-docker-compose/.env` — the live compose `.env` (host name, HTTPS,
  secrets); the entire `openproject/` workspace is gitignored.
- `~/openproject/.op-api.env` — APIv3 base URL + admin token (Basic `apikey:<token>`).
- `~/openproject/.op-admin.env` — admin UI login/password.
- `deploy/.deploy.local` — server IP / public domain / identity for external HTTPS.
- `.op-state.local.md` (canonical path via `scripts/op-state-path.sh`) — the **instance scratchpad** (see below).

### Instance scratchpad (`.op-state.local.md`)

A small, skill-maintained file holding the instance's stable schema/pointers, so they're in context
at session start. Generic structure: `templates/op-state.example.md` (committed, placeholders only).
The live file is gitignored, **host-local, NO secrets** (file paths only), at the canonical path
from `scripts/op-state-path.sh`; the SessionStart hook injects it and the writers (op-setup,
provisioning, section-owner skills) use the same resolver, so reader and writers can't diverge.

Four sections — `## Instance` / `## Projects` / `## Provisioning IDs` / `## Intake schema` — each
**owned/updated by one skill** (owners noted in `templates/op-state.example.md`); reads are free.
**Subagents don't receive the hook injection → the main loop forwards needed values into the subagent prompt.**

Claude auto-memory stays **off** for this workflow (the scratchpad + redis-memory replace it) — a
one-time setting `/op-setup` offers at install; the how-to lives there.

Deploy/runtime specifics (HTTPS + host-name behaviour, low-memory tuning, first-login change) live
in `docs/openproject-selfhost.md`.

## Continuous learning

The PM expertise and toolkit keep improving — the canonical checklist **and** the "what's worth
building here" guidance (discipline rules are env-enforced by these guardrails; build
**technique/reference** skills and validate with live self-cleaning smoke tests) live in the
**`pm-craft`** skill → "Continuous learning". Keep `docs/*` current against primary sources, and
re-evaluate the official `/mcp` for write tools each OpenProject release.

Mid-work findings worth changing how the agent works are captured as **`op-learn`** entries and
promoted by **`/op-learn`**; discipline and format live in the **`continuous-learning`** skill.
(Distinct from `/op-retro`, the team delivery retrospective.)

## Project status & plan

Internal project status, deployment specifics, progress, and next-steps are an **operator
tracker** kept in a gitignored local file (`STATUS.local.md`) — deliberately **not** in this
public repo. This file stays generic guidance only.
