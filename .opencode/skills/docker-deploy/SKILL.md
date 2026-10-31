---
name: docker-deploy
description: Build and deploy the backend and MCP server via Docker Compose
---

## When to use
Use this skill when changes to backend/ or mcp-server/ are ready to be tested locally.

## Commands

### Build and run
```bash
docker compose up -d --build
```

### Check logs
```bash
docker compose logs -f backend
docker compose logs -f mcp-server
```

### Restart a service
```bash
docker compose restart backend
```

### Stop everything
```bash
docker compose down
```

## Ports
- Backend API: `http://localhost:4000`
- PostgreSQL: `localhost:5432` (already running in postgres_container)
- MinIO: `localhost:9900` (already running in minio container)

## Network
All services connect via `apps-network` (external Docker network).
