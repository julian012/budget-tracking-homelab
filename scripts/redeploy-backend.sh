#!/bin/bash
# Redeploys the 'budget-backend' stack via the Portainer webhook (GitOps).
# Used on boot (cron @reboot) and manually. It does not manage the container
# directly: it only triggers Portainer, which is the source of truth.
#
# Retries the webhook until it gets HTTP 204 (with a cap), logging the HTTP
# code of each attempt and the final result. Idempotent: triggering the webhook
# several times is harmless (Portainer pulls and recreates with no effect if nothing changed).
set -uo pipefail

: "${WH_URL:?set WH_URL to the Portainer webhook URL (Stacks → stack → Webhooks)}"

# Retry cap (overridable from the environment if needed).
MAX_ATTEMPTS=${MAX_ATTEMPTS:-15}
RETRY_DELAY=${RETRY_DELAY:-20}
EXPECTED_CODE=204

log() { echo "[$(date -Is)] $*"; }

# 1) Wait for Docker to be available (avoids triggering before the daemon starts).
for i in $(seq 1 30); do
  if docker info >/dev/null 2>&1; then break; fi
  sleep 2
done

# 2) Trigger the webhook with retries until HTTP 204 is returned.
attempt=1
code=""
while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$WH_URL" 2>/dev/null || true)
  if [ "$code" = "$EXPECTED_CODE" ]; then
    log "webhook budget-backend OK (HTTP $code) — attempt $attempt/$MAX_ATTEMPTS"
    exit 0
  fi
  log "webhook budget-backend: attempt $attempt/$MAX_ATTEMPTS → HTTP ${code:-no-response} (expected $EXPECTED_CODE); retrying in ${RETRY_DELAY}s"
  attempt=$((attempt + 1))
  if [ "$attempt" -le "$MAX_ATTEMPTS" ]; then sleep "$RETRY_DELAY"; fi
done

log "webhook budget-backend FAILED after $MAX_ATTEMPTS attempts (last HTTP ${code:-no-response})"
exit 1
