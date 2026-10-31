---
name: mcp-tool
description: Add or modify MCP tools in the budget MCP server for OpenClaw
---

## When to use
Use this skill when adding new query tools or chart types to the MCP server.

## Structure
All tools are defined in `mcp-server/server.py` using FastMCP.
Database queries live in `mcp-server/db.py`.
Chart generation lives in `mcp-server/charts.py`.

## Adding a new tool
1. Write the query function in `db.py`
2. Register the tool in `server.py` with `@mcp.tool()`
3. Write a test in `mcp-server/test_server.py`
4. Run `python3 -m pytest mcp-server/ -v`

## Registering with OpenClaw
After changes, the MCP server is automatically available.
To re-register manually:
```bash
openclaw mcp set budget-tools '{"command":"python3","args":["-m","budget_mcp"],"cwd":"/path/to/mcp-server"}'
openclaw mcp probe budget-tools
```
