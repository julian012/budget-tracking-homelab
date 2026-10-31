@AGENTS.md

## Specialized agents

Mirror subagents of the ones defined in `opencode.jsonc` / `.opencode/` for OpenCode (which runs on the personal server). Use them via the Agent tool for changes scoped to a single layer; definitions in `.claude/agents/`:

- `go-backend` — Go, PostgreSQL, MinIO, Docker (`backend/`)
- `flutter-mobile` — Flutter, Dart, Firebase (`mobile/`)
- `python-mcp` — Python, FastMCP, PostgreSQL (`mcp-server/`)

If you edit the OpenCode prompts in `.opencode/prompts/`, mirror the change in the equivalent agent here so both flows stay aligned.
