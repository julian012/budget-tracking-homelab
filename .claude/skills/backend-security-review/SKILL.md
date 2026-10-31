---
name: backend-security-review
description: Security and error-handling checklist for backend Go changes — ownership validation, auth, uploads, CORS. Use before finishing any change to backend/internal/handler, service or middleware.
---

## When to use

Before finishing any change in `backend/internal/{handler,service,middleware}`, or when resolving a `layer:backend` issue related to security or error handling.

## Checklist

### Ownership / IDOR
- [ ] Every client-supplied ID referencing another resource (`category_id`, `card_id`, etc.) is validated against the token's `user_id` **before** being used in an INSERT/UPDATE — not only in direct updates of that resource. Reference pattern already used in `UpdateCard`/`UpdateCategory`: `WHERE id=$1 AND user_id=$2`.

### Authentication
- [ ] No path in `middleware/auth.go` produces a valid `userID` (nor a fallback `"dev-user-id"`) when expected configuration is missing — fail closed, not open.
- [ ] If `CreateUser`/`GetOrCreateUser` fails, the request is aborted (it does not continue with an empty or partial `userID`).

### Error handling
- [ ] Every error is wrapped with context via `fmt.Errorf("...: %w", err)` — never discarded with `_` unless it is explicitly harmless (e.g., a `Close()` in an already-logged defer).
- [ ] Error HTTP responses **never** return raw `err.Error()` to the client — log server-side and respond with a generic message and a consistent status code.

### Uploads (MinIO)
- [ ] The uploaded file type is validated against its actual content (magic bytes), not just the `Content-Type` header sent by the client.
- [ ] Size remains limited with `http.MaxBytesReader` before reading the body.

### CORS / config
- [ ] `Access-Control-Allow-Origin` is not a hardcoded `"*"` wildcard — it comes from config/env with known origins.
- [ ] No development credential (`budget:budget`, etc.) remains as a silent fallback when the production env var is missing — at least log a visible warning.

## Reference

Checklist derived from the code audit of 2026-08-25 (issues #39-#47). It exists as an identical duplicate in `.opencode/skills/backend-security-review/SKILL.md` and `.claude/skills/backend-security-review/SKILL.md` (previously symlinked from `skills/`, see #64) — if you edit it, replicate the change in both copies.
