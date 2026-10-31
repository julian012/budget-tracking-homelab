# OpenCode: MCP and plugins

Agent configuration in `opencode.jsonc` and `.opencode/`. This document covers the
enabled **MCP** servers (what they're for and how to configure them) and the
context plugin.

## MCP servers

| MCP | Type | Purpose |
|-----|------|----------|
| `codebase-memory-mcp` | local (binary) | Code graph: symbols, callers, and blast radius |
| `context7` | remote | Up-to-date library documentation |
| `postgres` | local (Docker) | Schema and read-only queries |

### codebase-memory-mcp

Code graph. First choice for structural questions (see the "Structural analysis
(graph-first)" section in `AGENTS.md`).

- Binary: `codebase-memory-mcp` (on your `PATH`)
- Config: `mcp["codebase-memory-mcp"]` in `opencode.jsonc`
- Excludes build artifacts via `.cbmignore`

### context7

Up-to-date library documentation (chi, pgx, Flutter, FastMCP). It's remote and
needs no installation.

- URL: `https://mcp.context7.com/mcp`
- Config: `mcp.context7` in `opencode.jsonc`
- Usage: explicitly ask for `use context7` in the prompt

### postgres

Schema inspection and query validation in **read-only** mode
(`--access-mode=restricted`). Runs `crystaldba/postgres-mcp` in Docker.

- Config: `mcp.postgres.command` → `scripts/opencode-postgres-mcp.sh`
- Credentials: the wrapper loads `DATABASE_URL` from `.env` (gitignored).
  Secrets are **never** committed.
- Network: the container joins `apps-network` to resolve `postgres_container`
  (the host used by `DATABASE_URL`).
- Network override: `PG_MCP_NETWORK` variable (default `apps-network`).

### budget-mcp (OpenClaw)

The repo's own MCP server (`mcp-server/`, FastMCP `budget-tools`) is served over
**HTTP (streamable-http)** in a dedicated container so OpenClaw can consume it
(the gateway is a Node image and can't launch the Python server over stdio).

- Service: `budget-mcp` on `apps-network` (defined in `docker-compose.yml` and
  `portainer-stack.yml`, image `ghcr.io/<your-user>/<your-repo>-mcp`).
- Transport via env: `MCP_TRANSPORT` (`stdio` | `streamable-http` | `sse`),
  `MCP_HOST` (default `0.0.0.0` in the container), and `MCP_PORT` (default `8000`).
  HTTP endpoint: `/mcp`.
- Register in OpenClaw (once, after deploying `budget-mcp`):

```bash
openclaw mcp add budget-tools --url http://budget-mcp:8000/mcp --transport streamable-http
```

- Verify: `openclaw mcp list` (must list `budget-tools`), `openclaw mcp probe`
  (5 tools: expenses by category, summary, chart, monthly trends, weekly
  spending), and try it from Telegram.
- `DATABASE_URL` points at `postgres_container:5432/budget` (resolved via
  `apps-network` DNS).

## Plugin: context-mode

Tool-output sandbox + session continuity (`plugin: ["context-mode"]`).

- Do **not** declare `mcp.context-mode`: the OpenCode loader would ignore the
  `ctx_*` tools (the plugin path suppresses MCP duplicates).
- Verify in a session: `ctx stats`.

## Requirements

- Docker (postgres MCP)
- Node >= 22.5 (context-mode plugin)

## Verification

```bash
opencode mcp list   # context7 and postgres should show as "connected"
```
