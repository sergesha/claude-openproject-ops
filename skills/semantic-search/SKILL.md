---
name: semantic-search
description: Use when checking whether OpenProject already has a similar work package ("do we already have anything like this?", "find duplicates by meaning", "/op-similar"), when keyword search misses paraphrases, or when maintaining a reusable semantic index over a work-package corpus (intake ideas, a delivery backlog) for dedup or near-duplicate detection. Triggers — "anything like X already", "similar items", "near-duplicate by meaning", "semantic dedup index", "search across everything by meaning".
---

# semantic-search — reusable semantic index over OpenProject work packages

Maintain a redis-memory **semantic index** over a set of OpenProject work packages and query it
**by meaning** (catches paraphrases keyword search misses). OpenProject stays the system of record;
the index is a **rebuildable cache**. **The names below are fixed conventions — use them verbatim**
so every session and every consumer reads/writes one compatible index. Deterministic helpers (source
them, never reinvent the text/hash): `skills/semantic-search/index.sh` (`dedup_text`, `dedup_hash`,
`dedup_decide`, `dedup_keyword_search`).

Parametrized by a **namespace** `ns` (a corpus) + a **corpus selector** (project + types).

## Conventions (the compatibility contract)

| Element | Value |
|---|---|
| Semantic entry | `mem_save(text, label=<title>, tags="<ns>-index,wp-index", ttl_days=0)` → `memId` |
| Tags | corpus tag `<ns>-index` **and** umbrella `wp-index` (both, every entry) |
| `text` | `dedup_text "<title>" "<≤200-char neutral summary>"` — **no secrets, host specifics, or full description** |
| Bookkeeping (KV) | `kv_set("wpidx:<ns>:<wpId>", "{memId, lockVersion, hash}", ttl_days=0)` |
| `hash` | `dedup_hash "<title>" "<summary>"` (sha256 of normalized text, first 16 hex) |

**Namespaces:** `idea` (intake: project Intake, types Idea + Use case) · `backlog` (refinement:
the delivery project, its epic/story/bug types). Corpus tags: `idea-index`, `backlog-index`.

## Index API (agent runs these via MCP; helpers pin the deterministic parts)

- **`lazy_heal(ns, corpus)`** — reconcile index ⇄ corpus; run **before any search**; best-effort.
  1. `list_work_packages` (corpus, **all** statuses) → `wpId` + `lockVersion` (one call).
  2. `kv_list("wpidx:<ns>:")` → `wpId → {memId, lockVersion, hash}`.
  3. per item, `dedup_decide`: `missing` → index (`mem_save`+`kv_set`); `fresh` → skip;
     `changed` → reindex (`mem_delete` old + `mem_save` + `kv_set`); `nontext` → update stored
     `lockVersion` only. `lockVersion` is the cheap gate — recompute `hash` only when it moved.
  4. `orphan` (in KV, not in corpus = deleted) → prune (`mem_delete` + `kv_delete`).
- **`similar(query, scope, [top_k=5])`** — `scope` = a corpus tag `<ns>-index` **or** `wp-index`
  (cross-corpus). `mem_search(query, tags=scope, top_k)` → ranked with similarity %. Bands
  (**calibrated for the current redis-memory embedder — it scores low**): **≥60%** strong (likely
  duplicate), **35–60%** related/overlap, **<35%** none (pure noise tops out ~25%). The score is a
  pre-filter; **always confirm the top candidates by reading them.** If the embedder model changes,
  recalibrate (run a few known dup/non-dup probes) and `reindex`.
- **`upsert(ns, wp)`** — write-through on create/edit: compute `text`/`hash`, `mem_save` + `kv_set`.
- **`reindex(ns)`** — `kv_list("wpidx:<ns>:")` → `mem_delete` each + `kv_delete` → rebuild. Escape hatch.

## Fallback (best-effort — never blocks the caller)

redis down → keyword `dedup_keyword_search` / `search_work_packages` (expand the query with
synonyms) → if unavailable, skip and note "semantic search unavailable". Never stall.

## `/op-similar "<text>" [scope]`

Ad-hoc "do we already have something like this?". Default `scope=wp-index` (across all corpora) or a
corpus tag. Runs `lazy_heal` for the scope (best-effort) then `similar`; prints ranked
`#id · title · % · type/status`. Better than keyword for paraphrases.

## Common mistakes
- Hand-writing the `text`/`hash` instead of sourcing `index.sh` → incompatible entries across sessions.
- Omitting the `wp-index` umbrella tag → cross-corpus `/op-similar` can't see the entry.
- Indexing the full description / secrets / host specifics → keep it to title + ≤200-char neutral summary.
- Re-embedding on every `lockVersion` bump → gate on `hash`; non-text edits don't re-embed.
- Treating the index as the source of truth → it's a rebuildable cache; OpenProject wins.
