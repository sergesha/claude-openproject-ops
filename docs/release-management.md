# Release management — reference

OpenProject **Versions** serve two distinct roles. Keep them separate or reporting gets confused:

| Role | What it is | Driven by |
|---|---|---|
| **Sprint** | a time-boxed cadence bucket (Backlogs) | `op-sprint-plan` / `sprint-operations` |
| **Release** | a shipped increment (what reaches users) | `/op-release` |

A work package can belong to a sprint (when it's built) and roll up to a release (when it ships).
Model the release as its own Version named like a release (`v1.4.0`), not by overloading a sprint.

## Cut a release
Create a release Version (status open), describe its scope, and record which roadmap **Horizon**
(Now/Next/Later, from the `openproject-intake` roadmap) it realizes — so the roadmap and the shipped
releases line up. Assign the work packages that will ship to the release Version.

## Release notes
Generated from the work packages **closed in / assigned to** the release Version:
- pull the version's items with a *done* status (`status.isClosed` and not `Rejected`),
- group by type (Features / Bugs / etc.), list `#id subject`,
- output Markdown; respect the outbound-disclosure boundary for external audiences.

There is no native "changelog" object — notes are derived from work-package data each time (single
source of truth), the same way RICE and metrics are computed rather than stored.

## Release status
What has shipped (done items in the release) vs what is still open; surface scope at risk early.
Close the release Version once everything has shipped (or carry the remainder to the next release).
