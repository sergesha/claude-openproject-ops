# OpenProject MCP & API — reference

How the agent reads and **writes** OpenProject. Two layers exist; know which is which.

## Layer 0 — the official, built-in MCP (READ-ONLY)

Since **OpenProject 17.2** the server ships a built-in MCP endpoint at `/mcp`.

- **Read-only.** "OpenProject only offers read-only tools; tools to manipulate data might
  be added in the future." Exposes Projects, Work Packages, Users (search/get).
- **Enterprise add-on** — requires a paid plan; configured under *Administration →
  Artificial Intelligence (AI) → Model Context Protocol (MCP)*. Admins can rename/disable
  individual tools and choose response format (Full / Structured / Content-only).
- Auth: personal **API token** (single-user MCP clients) or **OAuth 2.0** with the `mcp`
  scope (multi-user). Endpoint: `https://<host>/mcp`.
- Source: https://www.openproject.org/docs/system-admin-guide/integrations/mcp-server/

➡️ Because it is read-only **and** Enterprise-gated, it does **not** satisfy this project's
need for write operations on Community Edition. Use it (if available) for safe reads;
otherwise use a community write-capable server below over the public APIv3.

## Layer 1 — community write-capable MCP servers (what we use for writes)

Both wrap **APIv3** with a personal API token, so they work against **Community Edition**.

> **Decision (this project):** adopt **AndyEverything** as the primary write MCP, with the
> **raw APIv3** (Layer 2 below) kept as a *complementary* fallback for anything the MCP
> doesn't cover or when a dependency-free path is preferred. Vet the source + pin a commit
> before installing.

### Option A — `AndyEverything/openproject-mcp-server` (recommended)
- Python 3.10+ (FastMCP), stdio or SSE. MIT. ~40+ tools, **full CRUD**.
- Tools: projects (create/update/delete), work packages (create/update/delete/get,
  `list_work_packages` with 23 filters, search, parent/child, relations), memberships,
  time entries, versions, users/roles, types/statuses/priorities, plus convenience filters
  (overdue, due-soon, unassigned, high-priority…).
- Install: `uv sync` after clone; needs `OPENPROJECT_URL`, `OPENPROJECT_API_KEY`.
- https://github.com/AndyEverything/openproject-mcp-server

### Option B — `firsthalfhero/openproject-mcp-server` (Tangaratta)
- Python 3.8+ (FastMCP), SSE. 19 tools, write-capable (projects, work packages,
  relations, assign-by-email, users, config). Docker deploy script. License unspecified.
- https://github.com/firsthalfhero/openproject-mcp-server

### Configure for Claude Code (stdio, Option A)

```bash
claude mcp add-json openproject '{
  "type": "stdio",
  "command": "uv",
  "args": ["--directory", "/abs/path/openproject-mcp-server", "run", "openproject-mcp-server"],
  "env": {
    "OPENPROJECT_URL": "http://localhost:8080",
    "OPENPROJECT_API_KEY": "<personal API token>"
  }
}'
```

Requires `uv`/`uvx` — install if absent
(`curl -LsSf https://astral.sh/uv/install.sh | sh`, lands in `~/.local/bin`).

> ⚠️ These are third-party. Before trusting one with write access: read the source, pin a
> commit/tag, and first exercise it against a throwaway project. Re-evaluate the **official**
> MCP at each upgrade — when it gains write tools, prefer it.

## Layer 2 — the raw APIv3 (the ground truth; fallback for anything the MCP lacks)

- Format: **HAL+JSON** (hypermedia links embedded). Base path: **`/api/v3`**.
- Auth: HTTP **Basic** with username `apikey` and the token as the password
  (`curl -u apikey:<token> ...`), or OAuth2. Generate a token in *My account → Access
  tokens → API*.
- Core resources: work packages, projects, users/groups, types, statuses, priorities,
  versions (≈ sprints, see PM doc), relations, time entries, activities, **queries**
  (saved filters/views), memberships, custom fields.
- Filtering: `?filters=[{"status":{"operator":"o","values":[]}}]` (URL-encoded JSON);
  pagination via `offset`/`pageSize`; sorting via `sortBy`.
- Writes: `POST /api/v3/work_packages`, `PATCH /api/v3/work_packages/{id}` (send the
  `lockVersion` you read back to avoid lost updates), etc.
- Docs: https://www.openproject.org/docs/api/  and the interactive APIv3 reference.

Quick connectivity probe:
```bash
curl -s -u apikey:<token> http://localhost:8080/api/v3/work_packages | head -c 400
```

## Identifier conventions

Work packages have a global numeric **ID** (`#1234`) shown across the instance. Projects
have an **identifier** slug (in the URL `/projects/<identifier>/`). Prefer `#ID` in prose
to the user; pass numeric IDs / hrefs to tools. Comments and descriptions accept
**OpenProject-flavored Markdown** (CommonMark + macros).
