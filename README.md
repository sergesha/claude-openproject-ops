# claude-openproject-ops

A Claude Code plugin (and its single-plugin marketplace) for a **multi-role agent** around a
self-hosted [OpenProject](https://www.openproject.org) **Community Edition** instance:

- **Certified PM craft** — Agile, Scrum, Kanban, Scrumban, PRINCE2, SAFe, hybrid in IT.
  → skill [`pm-craft`](skills/pm-craft/SKILL.md) + knowledge base [`docs/pm-knowledge/`](docs/pm-knowledge/)
- **DevOps** — install / upgrade / configure / back up self-hosted OpenProject (Docker
  Compose, slim images). → skill [`openproject-devops`](skills/openproject-devops/SKILL.md)
- **Lifecycle driver (PM)** — run the full delivery lifecycle (epics, stories, sprints,
  triage, multi-track portfolio) through a write-capable OpenProject MCP / APIv3.
  → skill [`openproject-pm`](skills/openproject-pm/SKILL.md), plus the discovery funnel
  [`openproject-intake`](skills/openproject-intake/SKILL.md) (ideas → roadmap) and the backlog
  grooming pass [`backlog-refinement`](skills/backlog-refinement/SKILL.md) (health + Definition of Ready)

The agent keeps durable, searchable memory in **redis-memory-mcp** and talks to the outside
world over an **a2adapt** identity (end-to-end-encrypted agent-to-agent messaging); external
parties drive OpenProject *through* this agent.

## Layout

| Path | What |
|---|---|
| `.claude-plugin/` | plugin + marketplace manifests |
| `skills/pm-craft/` | certified PM methodology & facilitation (the brain) |
| `skills/openproject-pm/` | run the lifecycle in OpenProject (MCP/APIv3) |
| `skills/openproject-devops/` | operate OpenProject (Docker) |
| `skills/openproject-intake/` | idea/use-case discovery funnel → roadmap (+ semantic dedup) |
| `skills/backlog-refinement/` | groom the delivery backlog to ready (health + DoR) |
| `skills/delivery-metrics/` | compute velocity / burndown / throughput / runway from live data |
| `skills/sprint-operations/` | run/close the sprint: standup, review, DoD-gated close, retro |
| `skills/delivery-reporting/` | stakeholder/portfolio reports + the risk register (ROAM) |
| `skills/continuous-learning/` | capture findings while working; `/op-learn` promotes them into the plugin |
| `skills/semantic-search/` | reusable semantic index over work packages; "anything like X?" / dedup by meaning |
| `skills/startup-navigator/` | the coach that runs the `docs/cookbook/` methodology — locate the phase, facilitate the founder's decision, delegate the mechanics (`/op-coach`) |
| `commands/` | `/op-setup` `/op-status` `/op-triage` `/op-intake` `/op-idea` `/op-roadmap` `/op-refine` `/op-metrics` `/op-sprint-plan` `/op-standup` `/op-sprint-review` `/op-sprint-close` `/op-retro` `/op-release` `/op-report` `/op-similar` `/op-risks` `/op-learn` `/op-coach` `/op-backup` `/op-upgrade` |
| `docs/` | primary-source reference (read these first) |
| `docs/cookbook/` | staged startup **recipes** the agent follows to organize our work (start at `start-here.md`) |
| `docs/pm-knowledge/` | the PM knowledge catalog (grown continuously) |
| `openproject/` | deployment workspace (cloned upstream compose stack; gitignored) |
| `deploy/` | reverse-proxy / external-access assets (to author) |
| `identity/` | a2adapt identity / bio notes |
| `context/` | the runtime **operating contract** (single source of truth for standing rules) |
| `hooks/` | the **SessionStart hook** that injects the contract + instance scratchpad |

## Context delivery (operating contract & instance scratchpad)

A plugin's root `CLAUDE.md` is **not** auto-loaded into sessions — it loads only when the working
directory is the plugin repo (i.e. while developing the plugin). So the agent's standing operating
rules can't live there; they'd never reach a runtime session in another cwd. Instead:

- The **operating contract** (`context/operating-contract.md`) is the single source of truth for the
  standing rules (disclosure boundary, no-bluffing, read-before-write, memory-best-effort, scratchpad
  usage, `/op-coach`, …). A **SessionStart hook** (`hooks/session-context.sh`, wired in
  `hooks/hooks.json`) prints it to stdout so Claude Code injects it into **every** top-level session,
  addressed via `${CLAUDE_PLUGIN_ROOT}` — works from any cwd and any install location (e.g. the
  plugin cache). It is delivered **only** by the hook, never `@import`ed/inlined in `CLAUDE.md`
  (that would double-inject in dev sessions). Subagents don't get it — the main loop forwards what
  they need.
- The **instance scratchpad** (host-local `.op-state.local.md`, instance schema/IDs, no secrets) is
  **not** shipped in the plugin. The same hook resolves it via `OP_STATE_FILE` (set per deployment)
  or falling back to `$HOME/.op-state.local.md`, then appends it with its resolved path so the
  agent can read-modify-write it.
- `scripts/check-session-context.sh` is the deterministic harness for all of the above.

`CLAUDE.md` carries only guidance for an agent **working on the plugin**; the standing operating
rules and `continuous-learning` process are the contract + the `continuous-learning` skill.
