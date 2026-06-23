---
name: continuous-learning
description: Use when capturing a finding mid-work (a tool, doc, or workflow surprised you, or you found a better way worth remembering), when deciding what to do with a finding you just handled, or when running /op-learn to turn accumulated findings into plugin improvements. Triggers — "capture this", "op-learn", "analyze the findings", "improve the plugin from what we learned".
---

# Continuous learning

The agent records findings while it works, then `/op-learn` promotes them into the
versioned skills/docs/commands. **Memory holds only OPEN findings; git is the only record of
what was learned and fixed.** A finding's presence in memory *is* its "open" status — there is
no other status, and nothing stays in memory once it's handled.

## Capture (the operating contract checkpoint does this)

The operating contract requires every task completion to end with an `op-learn:` line.
That checkpoint is the capture mechanism — this skill does NOT restate it.

**What qualifies:** a tool/API/MCP surprise, a wrong or missing doc, a needed workaround, or a
materially better approach. **Not** routine successes, expected outcomes, files you created.

**Format:** `[slug] surprise → what to change`. No instance specifics (hostnames, IPs, paths,
tokens) — abstract to technique. No status fields (in-memory = open; handled = deleted).
Best-effort: if redis-memory is unavailable, skip silently.

## `/op-learn` — promote findings into the plugin

1. Load open findings (`mem_list`/`mem_search` tag `op-learn`). None → report and stop.
2. **Triage honestly.** Mark each real / already-fixed / not-a-defect. Don't manufacture work;
   read the target file and git history before deciding (regression context lives in git).
3. **Draft a changeset** — concrete edits to specific skills/docs/commands, tied to findings.
4. **Present the full changeset for approval. Do not apply or commit anything first** — even
   "obvious, reversible" edits go in the changeset, not straight to disk.
5. On approval: apply, commit (standard `Co-Authored-By` trailer), then **`mem_delete` every
   processed finding — implemented OR rejected — and save nothing in its place.**

## Lifecycle

| State | Action |
|---|---|
| **Open** | `mem_save`, tag `op-learn` — surfaced by `/op-learn` |
| **Processed** (implemented *or* rejected) | `mem_delete`. Nothing replaces it. Git is the record. |

A "wontfix" that keeps recurring self-resolves through the loop: its recurrence is a finding
whose fix is a skill rule saying "don't flag X."

## Rationalizations — STOP

| Excuse | Reality |
|---|---|
| "I'll save a `resolved`/`validated`/`done` record so memory reflects reality." | No. Processed = deleted. The git commit is the record. A resolution record re-pollutes `mem_search` and rebuilds the stale-redis dependency we deliberately removed. |
| "The hostname is just a 'confirmed on' data point, not a key." | It's still a host specific. Findings carry zero instance specifics. Abstract it. |
| "A `Status: PENDING` line lets memory remind me to finish." | Presence in memory already means open. No status fields — memory isn't a tracker. |
| "These edits are low-risk and reversible — I'll just apply them." | `/op-learn` drafts the whole changeset and gets approval before applying or committing. No self-apply. |

## Red flags

- About to `mem_save` with a tag like `resolved`/`done`/`validated`, or a `Status:` line.
- A finding names a host/IP/domain/path — even "confirmed on …".
- Applying or committing `/op-learn` edits before the full changeset was approved.
- Keeping a handled finding "for the record."

All of these mean: **delete the processed finding, save nothing in its place, strip the specifics.**
