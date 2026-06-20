---
description: Cut / note / report a release (a Version distinct from sprints)
argument-hint: "<project> <cut|notes|status> [release name]"
---

Manage a **release** for $ARGUMENTS (use `openproject-pm` for the writes; see
`docs/release-management.md`). A release is an OpenProject **Version** that is *not* a sprint —
keep the two roles distinct (sprint = cadence; release = shipped increment).

- **cut** — create a release Version (name it as a release, e.g. `v1.4.0`; describe scope); map the
  roadmap **Horizon** (Now/Next/Later) it realizes. Do not reuse a sprint Version as a release.
- **notes** — generate release notes from the **work packages closed in / assigned to** the release
  Version (group by type: features / fixes / etc.); output Markdown. Exclude `Rejected`.
- **status** — what has shipped vs what is still open for the release; flag scope at risk.

Gate before creating/closing a release Version; report what changed. Respect the
outbound-disclosure boundary if notes go to an external audience.
