# AI Budget Tracking

Monorepo for personal expense tracking with AI.

## Structure

- `backend/` — REST API in Go (chi, pgx, minio-go, JWT verification via Firebase's Identity Toolkit REST API)
- `mcp-server/` — MCP server in Python (FastMCP) for OpenClaw
- `mobile/` — Flutter + Firebase mobile app
- `.opencode/` — Agent, skill and prompt config
- `dist/` — Build artifacts (APKs)
- `scripts/` — Utility scripts (backup-db.sh, install-ios.sh)
- `docs/` — Documentation (SETUP, NETWORK, SELF_HOSTING, STYLE_GUIDE, BACKUP, db-schema, TESTING, ISSUES_GUIDE)

## Commands

### General (Makefile)
```bash
make check        # Verify installed toolchain
make build-backend    # Build backend (Docker)
make build-apk        # Build Flutter APK
make distribute       # Build APK + Firebase App Distribution
make test         # All tests
make deploy       # Backend + APK + distribution
```

### Backend (Go)
```bash
cd backend && go test ./...        # Tests
cd backend && go build ./cmd/server/  # Build (without Docker)
```

### MCP Server (Python)
```bash
cd mcp-server && python3 -m pytest . -v   # Tests
```

### Mobile (Flutter)
```bash
cd mobile && flutter run        # Dev with hot-reload
cd mobile && flutter test       # Tests
```

## Structural analysis (graph-first)

For structural questions about the code, use the `codebase-memory` MCP (code graph) **first** and leave `grep`/`read` for literal text, strings and docs. See the `graph-first` skill for details.

- **Before implementing**: `search_graph` + `trace_path` to map symbols and confirm real callers (do not assume from grep that something is unused).
- **Before the PR**: `detect_changes --since main` to validate the blast radius of the diff.
- **Hygiene**: `index_status` after large merges; `.cbmignore` excludes build artifacts; coverage is best-effort → `check_index_coverage` before asserting negatives.

## Testing conventions

- Every new function in `backend/` MUST have its test in `_test.go`
- Every new tool in `mcp-server/` MUST have a test in `test_server.py`
- Every new widget/screen in `mobile/` MUST have its `_test.dart` test
- Before committing, run `make test` (runs against the `budget_test` test DB, NEVER production)
- The `.githooks/pre-commit` hook blocks commits with **failing tests, incorrect lints/imports or dependencies with vulnerabilities** — **do not use `--no-verify`**. Checks per layer:
  - `backend/`: `go vet ./...` · `gofmt -l .` · `go mod tidy` with no changes to `go.mod`/`go.sum` · `govulncheck ./...`
  - `mobile/`: `flutter analyze` · `flutter pub get` with no changes to `pubspec.lock` · `osv-scanner scan -r pubspec.lock`
  - `mcp-server/`: `python3 -m pytest . -v`
- `TEST_DATABASE_URL` is required for Go tests; `make db-test-setup` creates/applies migrations to `budget_test`
- Flutter tests use `firebase_auth_mocks` (they need no real Firebase or network)
- `govulncheck`/`osv-scanner` are installed with `make setup`; if missing, the hook warns and skips that check

## Backup

```bash
bash scripts/backup-db.sh      # Manual backup (also runs via cron at 2:00 AM)
```

## Documentation

| File | Content |
|---------|-----------|
| `docs/SETUP.md` | Firebase / Google Cloud configuration |
| `docs/NETWORK.md` | Network, tunnel/reverse proxy and deployment |
| `docs/STYLE_GUIDE.md` | UI patterns, components, Flutter design tokens |
| `docs/BACKUP.md` | Daily backup + PostgreSQL restore |
| `docs/db-schema.md` | Table schema |
| `docs/TESTING.md` | Test user |
| `docs/ISSUES_GUIDE.md` | Issues/branches/PRs workflow |
| `docs/OPENCODE.md` | OpenCode MCPs and plugins (usage and configuration) |
| `docs/SELF_HOSTING.md` | Guide to fork and self-host |
| `user-flows.md` | Implemented user flows |

## Ports

- Backend API: `http://localhost:4000`
- PostgreSQL: `localhost:5432` (postgres_container)
- MinIO: `localhost:9900` (minio container)

## Stack

| Layer | Technology |
|------|-----------|
| Backend | Go 1.26+ (toolchain 1.26.9), chi, pgx v5, minio-go v7 |
| MCP | Python 3.10+, FastMCP, psycopg2, matplotlib |
| Mobile | Flutter 3.24+, Dart, Firebase Auth |
| Auth | Firebase Authentication (Google + Email) |
| DB | PostgreSQL 17 |
| Files | MinIO (S3-compatible) |
| Deploy | Portainer GitOps (backend) + Firebase App Distribution (mobile) |

## Task tracking

- **GitHub issues** are the source of truth for pending work (see `docs/ISSUES_GUIDE.md`)
- Any pending task you start working on is created as an Issue (template `feature`/`bug`), labeled with `layer:*`, `type:*` and `priority:*`
- Work is done in branches (`feature/`, `fix/`, `chore/`, `docs/`) and the issue is closed with `Closes #N` from the PR
- The issue is updated as the work progresses, and closed when the PR is merged

## Docs up to date

Documentation is updated **in the same PR** as the code change that affects it — not as a separate task, and this also applies to small features, not just large changes. Rule valid for any agent working in this repo (Claude Code, OpenCode, or manual).

- If an issue adds/changes a **user flow** → `user-flows.md`
- If an **API endpoint or contract** changes → `README.md` ("API endpoints" table)
- If a **UI pattern/component** changes → `docs/STYLE_GUIDE.md`
- If the **DB schema** changes (in addition to the `.up`/`.down` migration) → `docs/db-schema.md`
- If something about **network/deploy/infra** changes → `docs/NETWORK.md` / `docs/SETUP.md`
- A PR that changes visible behavior without touching the corresponding documentation is considered **incomplete**, unless the change is purely internal (refactor with no visible effect, infra chore with no documented impact). See the `resolve-issue` skill for the full workflow.
