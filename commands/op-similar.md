---
description: "Find existing work packages similar by meaning — \"do we already have anything like this?\""
argument-hint: "\"<text>\" [scope: wp-index (default) | idea-index | backlog-index]"
---

Answer "do we already have anything like this?" using the `semantic-search` skill. Better than
keyword search — catches paraphrases.

1. Parse `$ARGUMENTS`: the query text and optional `scope` (default **`wp-index`** = across all
   corpora; or a corpus tag like `idea-index` / `backlog-index`).
2. **lazy-heal** the relevant corpus/corpora for that scope (best-effort; skip if redis is down).
3. `similar(query, scope)` → `mem_search(query, tags=scope, top_k=5)`; redis down → keyword
   `dedup_keyword_search` and note the search was degraded.
4. Present ranked hits — `#id · title · similarity% · type/status` — with a one-line verdict
   (duplicate ≥50% / related 30–50% / nothing < 30% — embedder-calibrated). Confirm the top candidates by reading them;
   recommend reuse/relate where a strong match exists. Don't auto-act — advisory.
