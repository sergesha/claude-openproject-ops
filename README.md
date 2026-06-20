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
| `commands/` | `/op-setup` `/op-status` `/op-triage` `/op-intake` `/op-idea` `/op-roadmap` `/op-refine` `/op-metrics` `/op-sprint-plan` `/op-standup` `/op-sprint-review` `/op-sprint-close` `/op-retro` `/op-release` `/op-report` `/op-similar` `/op-risks` `/op-learn` `/op-backup` `/op-upgrade` |
| `docs/` | primary-source reference (read these first) |
| `docs/pm-knowledge/` | the PM knowledge catalog (grown continuously) |
| `openproject/` | deployment workspace (cloned upstream compose stack; gitignored) |
| `deploy/` | reverse-proxy / external-access assets (to author) |
| `identity/` | a2adapt identity / bio notes |

See [CLAUDE.md](CLAUDE.md) for commands, working agreements, and the **continuous-learning**
process.
