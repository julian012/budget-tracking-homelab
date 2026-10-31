# Testing Guide

## Test credentials

Create the user in Firebase Console → Authentication → Users → **Add user**:

| Field | Value |
|-------|-------|
| Email | `test@example.com` (or whatever you prefer) |
| Password | `ChangeMe123!` |

> These credentials are **not** preloaded into the app: the login screen no longer
> fills them in automatically. Type them by hand.

## Test database (IMPORTANT)

The Go backend tests must **NEVER** point at the production database.

| Variable | Example value |
|----------|------------------|
| `TEST_DATABASE_URL` | `postgres://budget:change-me@localhost:5432/budget_test` |

- The repository (`getTestDB`) **fails** if `TEST_DATABASE_URL` is empty or does not
  contain `budget_test`.
- Cleanup uses `TRUNCATE expenses, categories, users` — safe because it only
  runs against `budget_test`.
- Create/apply migrations to the test DB (idempotent):

```bash
make db-test-setup
```

> ⚠️ **Never** run `go test ./...` without `TEST_DATABASE_URL`, and never point that
> variable at the production database.

## Running tests

```bash
make test              # Backend + Flutter (uses budget_test)
make test-backend      # Go only (TEST_DATABASE_URL set automatically)
make test-mobile       # Flutter only
make db-test-setup     # Create/update budget_test
```

## Pre-commit hook

The `.githooks/pre-commit` hook (enabled via `core.hooksPath`) runs the tests plus
per-layer checks:

| Layer | Checks |
|------|----------|
| `backend/` | `go vet ./...` · `gofmt -l .` · `go mod tidy` with no changes · `govulncheck ./...` |
| `mobile/` | `flutter analyze` · `flutter pub get` with no `pubspec.lock` changes · `osv-scanner scan -r pubspec.lock` |
| `mcp-server/` | `python3 -m pytest . -v` |

- The scanners (`govulncheck`, `osv-scanner`) are installed by `make setup`; if
  they're missing, the hook warns and skips that check.
- `pubspec.lock` is committed (reproducible builds).
- **Don't use `--no-verify`**. If the hook fails, fix the issue before committing.

## Test build

```bash
make build-apk-debug
```

The debug APK includes the server configuration panel.

## App configuration

1. Build with your backend URL:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://192.168.1.100:4000
   ```
   (without `--dart-define` it uses `http://localhost:4000`)
2. Expand ⚙️ **Configurar servidor** (Configure server) on the login screen to change it on the fly.
3. Enable ☑ **Mostrar indicador de conexión** (Show connection indicator).
4. Press **Probar conexión** (Test connection) → it should show ✅ `Conexión exitosa`.
5. Sign in with the user you created in Firebase.

## Verifications

| Test | Expected result |
|--------|-------------------|
| Email/password login | ✅ Redirects to HomeScreen |
| Close and reopen the app | ✅ Goes straight to HomeScreen (persistent session) |
| Sign-out button | ✅ Returns to LoginScreen |
| 🟢 indicator on login | ✅ `Conectado` next to the title |
