---
name: db-migration
description: Create and apply PostgreSQL migrations for the budget database
---

## When to use
Use this skill when adding or modifying database tables, indexes, or seed data.

## Conventions
- Migration files live in `backend/migrations/`
- Format: `NNN_description.up.sql` and `NNN_description.down.sql`
- Apply via Go migration runner or manually via psql

## Current schema
```sql
users(id, firebase_uid, email, name, created_at)
categories(id, name, icon, color, user_id)
expenses(id, user_id, category_id, amount, description, expense_date, source, receipt_url, audio_url, created_at)
```

## Connection
DATABASE_URL=postgres://budget:budget@localhost:5432/budget

## Steps
1. Write the up migration
2. Write the corresponding down migration (reverse of up)
3. Run `go test ./internal/repository/...` to verify
