---
name: run-tests
description: Run the correct test suite based on which layer changed
---

## When a task involves code changes, run tests before finishing

### Backend (Go)
```bash
cd backend && go test ./...
```

### MCP Server (Python)
```bash
cd mcp-server && python3 -m pytest . -v
```

### Mobile (Flutter)
```bash
cd mobile && flutter test
```

### All layers
Run each suite that corresponds to changed files.
If tests fail, fix them before declaring the task done.
