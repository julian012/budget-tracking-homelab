# Self-hosting / Fork

This repo is a working Homelab expense-tracker template. It ships no credentials,
domains, or personal data: everything private is configured through `.env`,
`--dart-define`, and CI secrets.

## 1. Clone

```bash
git clone https://github.com/<your-user>/<your-repo>.git budget-tracking
cd budget-tracking
```

## 2. Create your Firebase project

Follow `docs/SETUP.md` (sections 1–3). You'll need:

- `backend/firebase-service-account.json` (gitignored)
- `mobile/android/app/google-services.json` (gitignored)
- `mobile/ios/Runner/GoogleService-Info.plist` (gitignored, iOS only)
- The **web client ID** for Google Sign-In

## 3. Configure variables

```bash
cp .env.example .env
$EDITOR .env
```

At minimum:

```bash
FIREBASE_WEB_API_KEY=...
DATABASE_URL=postgres://budget:<strong-password>@postgres_container:5432/budget
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=<strong-password>
ALLOWED_ORIGINS=https://your-domain.example.com
```

> `ALLOW_DEV_AUTH=true` is only meant for local development without Firebase. Never in
> production (auth should fail closed).

## 4. Database, MinIO, and network

`docker-compose.yml` assumes:

- An external network named `apps-network`:
  ```bash
  docker network create apps-network
  ```
- A PostgreSQL 17 reachable as `postgres_container` (or change the host in
  `DATABASE_URL`).
- A MinIO reachable as `minio:9000` (or change `MINIO_ENDPOINT`).

Create the schema by applying the migrations:

```bash
for f in backend/migrations/*.up.sql; do
  docker exec -i postgres_container psql -U budget -d budget -f - < "$f"
done
```

## 5. Run the backend

```bash
docker compose up -d --build
curl http://localhost:4000/health
# → {"status":"ok"}
```

## 6. Run the app

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.100:4000 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

For Android, the signing keystore must exist:

```bash
cp ~/.android/debug.keystore mobile/android/app/debug.keystore
```

Register the SHA-1 of that keystore in Firebase (Authentication → Settings).

## 7. Optional deployment

- **Without CI:** `docker compose up -d --build` on the server.
- **With GitHub Actions:** configure the secrets/variables from `docs/SETUP.md` §7 and
  `docs/NETWORK.md` (Portainer + GHCR). Images are published as
  `ghcr.io/<your-user>/<your-repo>-backend` and `-mcp`.

## 8. What this repo does NOT include

| File / value | How to get it |
|----------------|----------------|
| `backend/firebase-service-account.json` | Firebase → Service accounts |
| `google-services.json` / `GoogleService-Info.plist` | Firebase → Your apps |
| `mobile/android/app/debug.keystore` | `~/.android/debug.keystore` or `keytool -genkey` |
| `.env` | `cp .env.example .env` |
| Domain, IP, Portainer webhook | Your infrastructure |

## License

MIT. If this is useful to you, a ⭐ or a fork with improvements is welcome.
