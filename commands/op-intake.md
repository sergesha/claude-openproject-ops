---
description: Review/triage the OpenProject idea-intake funnel
argument-hint: "[Track to focus on, optional]"
---

Run a review pass over the idea funnel using the `openproject-intake` skill (and `pm-craft` for
judgment). Optionally scope to Track `$ARGUMENTS`.

If `$ARGUMENTS` is `--reindex`, run the skill's **Full reindex** (drop and rebuild the `idea-index`)
and stop — don't run the review pass.

1. Search redis-memory for prior decisions/context on these ideas/tracks; **lazy-heal the semantic
   index** (skill → "Semantic deduplication") so duplicate detection in step 3 is complete.
2. List the funnel: `list_work_packages` in project **Intake**, type **Idea**, grouped by status
   (filter by Track if given).
3. For each idea not yet decided:
   - ensure **Track** and **Lens** are set; clarify value/scope in comments;
   - complete **RICE** (Reach/Impact/Confidence/Effort) and (re)compute the **RICE score**
     = Reach × Impact × (Confidence ÷ 100) ÷ Effort, write it;
   - surface duplicates (semantic `mem_search` over the `idea-index`, skill → "Semantic
     deduplication"; keyword fallback if memory is down) and stale items stuck in Under review / Deferred.
4. Present the ranked candidates (by RICE) and recommend which to **Approve**, **Reject** (with
   reason), or **Defer**. Apply the user's decisions as status changes + rationale comments.
5. Report: counts per status, top-N ready-to-convert ideas, and anything blocked on missing info.

This is upstream of `op-triage` (which refines the *delivery backlog*). Stop at Approved — use
`op-roadmap` to convert.
