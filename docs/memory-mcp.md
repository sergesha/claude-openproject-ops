# redis-memory-mcp — reference (the agent's durable memory)

Persistent cross-session memory: a semantic-search store + a key/value store with
auto-expiry, over MCP. Source: https://github.com/sergesha/redis-memory-mcp (MIT, v0.2.1).
The repo is a Claude **marketplace** (root `.claude-plugin/marketplace.json` → plugin
`redis-memory` from `./plugin`); install it as a plugin — **no manual clone needed**.

> **Memory is best-effort, never a blocker.** Every skill's "search memory first" step is
> conditional: if this MCP is unavailable (not installed, or disabled to save RAM), proceed and
> note that prior context wasn't consulted — never block on it (per the operating contract). Concrete deploy state for a given host lives in that host's gitignored local
> status file, not here.

## Tools (8)

- **KV** (`kv_set`, `kv_get`, `kv_delete`, `kv_list`) — exact lookups, O(1), TTL-refreshing,
  tag/pattern filtering. No embeddings needed.
- **Semantic** (`mem_save`, `mem_search`, `mem_list`, `mem_delete`) — store/recall text by
  meaning (cosine similarity over a 768-dim HNSW vector index).

## Stack (Docker Compose) — 3 services + an init

The plugin's `.mcp.json` is **self-installing**: when the plugin is enabled, its `start.sh`
fetches the repo to `~/.cache/redis-memory-mcp`, brings up the infra (`docker compose up`),
and launches the MCP server over stdio. So enabling the plugin is what starts the stack:
- **redis** — `redis/redis-stack` (RediSearch + HNSW), `--maxmemory 2gb`,
  `--maxmemory-policy volatile-lru`, append-only persistence to `./redis_data`. Ports
  6379 (Redis) + 8001 (RedisInsight UI).
- **redis-init** — one-shot: creates the `idx:memories` HNSW index (DIM 768, COSINE).
- **embeddings** — HuggingFace **TEI** (`ghcr.io/huggingface/text-embeddings-inference:cpu-latest`),
  model `sentence-transformers/paraphrase-multilingual-mpnet-base-v2` (multilingual, 768d),
  port 8081→80, model cached in `./embeddings_cache`. **This is the heavy part** (~1 GB
  model download + RAM to serve it).
- **redis-memory-mcp** — the Python FastMCP server (stdio), built from `./server`.

### ⚠️ Resource note
The TEI embeddings service needs roughly **~1.5–2 GB RAM** to serve the model (plus a ~1 GB
one-time model download). On a RAM-tight host this can OOM — ensure headroom (add swap, or stop
other heavy stacks) before enabling. The self-installer brings the stack up on first enable.

## Environment variables

| Var | Default | Notes |
|---|---|---|
| `REDIS_URL` | `redis://redis:6379/0` (compose) / `redis://localhost:6379/0` (host) | Redis Stack |
| `EMBED_URL` | `http://embeddings:80` (compose) / `http://localhost:8081` (host) | TEI |
| `INDEX_NAME` | `idx:memories` | HNSW vector index |
| `KEY_PREFIX` | `mem:` | semantic-memory key prefix |
| `DEFAULT_TTL` | `7776000` (90 days) | auto-expiry |

## Wiring it into Claude Code (chosen method: the plugin)

Install as a plugin:
```bash
claude plugin marketplace add sergesha/redis-memory-mcp
claude plugin install redis-memory@redis-memory-marketplace
claude plugin enable  redis-memory@redis-memory-marketplace   # starts Redis+TEI on first use
```
The plugin also brings a `persistent-memory` skill + a session-init hook + the self-
installing MCP. To activate later: `claude plugin enable redis-memory@redis-memory-marketplace`
(it auto-starts Redis+TEI). Then verify with a `kv_set`/`kv_get` and a
`mem_save`/`mem_search` round-trip.

## How this agent should use it (two layers — keep distinct)

- **Instance scratchpad** (`.op-state.local.md`, injected by the SessionStart hook — see
  `templates/op-state.example.md` and CLAUDE.md → "Instance scratchpad") — small, stable,
  **always-needed instance schema & pointers**: the instance pointer, the project→purpose registry, provisioning IDs, the intake
  schema. Structured, skill-owned, already in context at session start. **Not** redis.
- **redis-memory-mcp** — *cross-track, queryable PM memory*: decisions & rationale, stakeholder
  context, recurring risks, per-track state & velocity that must survive and be searchable across
  sessions and tracks. **On-demand**: `mem_search` it at the start of planning/triage. **Not** the
  home for instance pointers/schema — those live in the scratchpad.

Convention: namespace KV keys by track (`track:<slug>:<field>`, e.g. `track:alpha:goal`),
and tag semantic memories with the track/project slug so recall can be scoped.
