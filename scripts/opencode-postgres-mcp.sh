#!/usr/bin/env bash
# PostgreSQL MCP (crystaldba/postgres-mcp) for OpenCode, in read-only mode.
#
# Loads the connection string from the repo's .env (gitignored) so secrets are
# not versioned. The container joins `apps-network` to resolve
# `postgres_container`, which is the host used by DATABASE_URL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "opencode-postgres-mcp: ${ENV_FILE} does not exist (define DATABASE_URL)" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

: "${DATABASE_URL:?opencode-postgres-mcp: DATABASE_URL is not defined in .env}"

exec docker run -i --rm \
  --network "${PG_MCP_NETWORK:-apps-network}" \
  -e DATABASE_URI="${DATABASE_URL}" \
  crystaldba/postgres-mcp --access-mode=restricted
