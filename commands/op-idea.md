---
description: Register and classify a product idea in the OpenProject intake funnel
argument-hint: "<idea, in your own words>"
---

Capture and triage a new idea using the `openproject-intake` skill.

1. Ensure the intake schema exists (skill's provisioning gate: the scratchpad `## Intake schema`,
   else run `provision.rb`). Search redis-memory for related prior ideas/decisions first.
2. **lazy-heal the semantic index** (skill → "Semantic deduplication"), best-effort — so the dedup
   search in step 3 sees a complete index.
3. **Dedup BEFORE creating** (search-first, so the new idea can't match itself):
   - `mem_search("<idea text>", tags="idea-index", top_k=5)` → candidates with similarity %.
   - redis down → keyword `search_work_packages` / `dedup_keyword_search` (query-expanded);
     unavailable → skip + note. Never block registration.
   - Confirm the top candidates by reading them. Bands (embedder-calibrated): **≥60%** clear match,
     **35–60%** related.
   - **Clear match** → present the duplicates (`#id` · title · % · status) and ask the user:
     **augment the existing item** (edit it / link `duplicates`, then reindex that WP) **or create new**.
   - **Related** → offer a `relates` link; default to create.
4. Register `$ARGUMENTS` as a **work package, type Idea, in project Intake**. Title = verb + user
   value; put the raw text + context in the description.
5. **Write-through index the new WP** (via the `semantic-search` skill, ns `idea`): compute `hash`,
   `mem_save(... tags="idea-index,wp-index", ttl_days=0)`, `kv_set("wpidx:idea:<id>", "{memId,
   lockVersion, hash}", ttl_days=0)`. Best-effort.
6. **Under review**: set draft **Track** and **Lens**; move status to Under review. (Duplicates were
   handled in step 3 — link `duplicates` there if the user kept both items.)
7. If the idea implies concrete scenarios, create/link one or more **Use case** work packages
   (`relates`) — index each (step 5).
8. Offer to score it (RICE) and take it to In discussion. Report the new `#ID`, Track/Lens, and any
   duplicates surfaced. Do not invent committee/approval steps — the user drives status changes.
