# Daily Backup — Database (PostgreSQL)

> **Goal:** automatic daily dump of the `budget` database, rotating the last
> 7 days. All paths and credentials are configurable via environment variables.

---

## Backup Script

Location: `scripts/backup-db.sh`

**What it does:**
1. Runs `pg_dump` from the PostgreSQL container.
2. Compresses with `gzip`.
3. Saves to `$BACKUP_DIR` (default `$HOME/backups/postgres`).
4. Rotates: keeps only the last 7 daily backups.
5. Logs the result.

Supported variables (with defaults):

| Variable | Default |
|----------|---------|
| `CONTAINER` | `postgres_container` |
| `DB_NAME` | `budget` |
| `DB_USER` | `budget` |
| `BACKUP_DIR` | `$HOME/backups/postgres` |
| `RETENTION_DAYS` | `7` (editable in the script) |

**Manual run:**

```bash
CONTAINER=postgres_container DB_USER=budget DB_NAME=budget \
  bash scripts/backup-db.sh
```

---

## Cron Setup (Daily at 2:00 AM)

```bash
crontab -e
```

Add the line (adjust the repo path):

```
0 2 * * * BACKUP_DIR=$HOME/backups/postgres /opt/budget-tracking/scripts/backup-db.sh >> $HOME/backups/postgres/backup.log 2>&1
```

Verify:

```bash
crontab -l
```

---

## Restore from Backup

```bash
# 1. Decompress
gunzip "$HOME/backups/postgres/budget-2026-08-06.sql.gz"

# 2. Restore into the container
docker exec -i postgres_container psql -U budget -d budget \
  < "$HOME/backups/postgres/budget-2026-08-06.sql"
```

> ⚠️ Restoring overwrites the current database. Take a manual backup first if you
> need to preserve the current state:

```bash
bash scripts/backup-db.sh
```

---

## File Structure

```
$HOME/backups/postgres/
├── budget-2026-07-30.sql.gz
├── budget-2026-07-31.sql.gz
├── budget-2026-08-01.sql.gz
├── ...
└── backup.log
```

---

## Verification

```bash
ls -lth "$HOME"/backups/postgres/budget-*.sql.gz | head -1
zcat "$HOME"/backups/postgres/budget-2026-08-06.sql.gz | head -50
```
