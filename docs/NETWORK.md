# Network and deployment (self-hosted)

This guide uses example values. Replace them with your own Homelab values.

| Example value | Meaning |
|---------------------|-------------|
| `192.168.1.100` | Server LAN IP |
| `api.example.com` | Public domain (optional, requires DNS/tunnel) |
| `4000` | Backend port |
| `postgres_container` | PostgreSQL container name |

## Backend

| Field | Value |
|-------|-------|
| IP / host | `192.168.1.100` (or your domain) |
| Port | `4000` |
| Base URL | `http://192.168.1.100:4000` |
| Health check | `http://192.168.1.100:4000/health` |
| API prefix | `/api` |

## Mobile app

The default URL is set at build time:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=https://api.example.com
# or for LAN:
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:4000
```

Without `--dart-define`, the app uses `http://localhost:4000`. On the login screen
(debug build) you can also open **⚙️ Configurar servidor** (Configure server) and
change it on the fly; it's saved in `shared_preferences`.

### Exposing it to the Internet (optional)

Common Homelab options:

- **Cloudflare Tunnel** → `https://api.example.com` → `http://localhost:4000`
- **Tailscale / WireGuard** → private access without opening ports
- **Reverse proxy** (Caddy/Nginx/Traefik) + your own DNS

If you use a domain, add it to `ALLOWED_ORIGINS` in `.env` (it only affects browser
clients; the native app doesn't send an `Origin` header).

## Portainer (GitOps, optional)

| Field | Value |
|-------|-------|
| URL | `https://portainer.example.com` |
| Stack | `budget-backend` |
| Compose | `portainer-stack.yml` |
| Branch | `main` |
| Image | `ghcr.io/<your-user>/<your-repo>-backend:latest` (override: `BACKEND_IMAGE`) |
| Webhook | `https://portainer.example.com/api/stacks/webhooks/<ID>` |

### How deployment works

1. Set the `DEPLOY_ENABLED=true` variable (Settings → Secrets and variables
   → Actions → Variables). Without it, the deploy job is skipped.
2. `git push` to `main`.
3. GitHub Actions (`deploy.yml`):
   - **`check-changes`** detects the modified layers (`dorny/paths-filter`).
   - **`deploy-backend`** (if `backend/**`, `mcp-server/**`, or
     `portainer-stack.yml` changed): logs in to GHCR, publishes
     `ghcr.io/<your-user>/<your-repo>-backend:<sha>` + `:latest`, and triggers the
     Portainer webhook.
   - **`build-apk`** (if `mobile/**` changed): analyze + tests + release build
     (artifact) and debug (Firebase App Distribution).
4. Portainer `pull`s the image and recreates the container.

> Portainer does **not** build: the stack uses `image:` from GHCR and CI is what
> builds and publishes. If you'd rather build on the server, use
> `docker compose up -d --build` with `docker-compose.yml`.

### After restarting the server

`scripts/redeploy-backend.sh` triggers the webhook with retries until it gets
HTTP 204. It requires `WH_URL` in the environment (no hardcoded URL):

```bash
WH_URL="https://portainer.example.com/api/stacks/webhooks/<ID>" \
  bash scripts/redeploy-backend.sh
```

Example `@reboot` cron:

```
@reboot WH_URL="https://portainer.example.com/api/stacks/webhooks/<ID>" /opt/budget-tracking/scripts/redeploy-backend.sh >> $HOME/cron_jobs/logs/budget_redeploy.log 2>&1
```

### Registry secrets

On GitHub: `REGISTRY_USER` (your username) and `REGISTRY_PASSWORD` (PAT with
`write:packages`). On Portainer: Settings → Registries → Custom → `ghcr.io`
with the same username + PAT.

## Verify

```bash
curl http://192.168.1.100:4000/health
# → {"status":"ok"}
```
