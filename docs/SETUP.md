# Setup Guide — Firebase and Google Cloud

This guide explains how to connect your own instance. **There are no credentials
in the repo**: every value comes from your own Firebase/Google Cloud project and
is stored in `.env` or in GitHub secrets.

## 1. Create the Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com) → **Add project**.
2. Note down these values (you'll use them throughout the guide):

| Value | Where to find it | Variable |
|------|-------------|----------|
| Project ID | Project settings → General | — |
| Web API Key | Project settings → General → Web API Key | `FIREBASE_WEB_API_KEY` |
| Web App ID | Project settings → Your apps → Web app | `FIREBASE_WEB_APP_ID` |
| Android App ID | Project settings → Your apps → Android | `FIREBASE_APP_ID` |
| Project number | Project settings → General | — |

3. Enable **Authentication** → Sign-in method: **Email/Password** and **Google**.

## 2. Backend: Service Account

1. Project settings → **Service accounts** → **Generate new private key**.
2. Save the JSON as `backend/firebase-service-account.json` (it's in `.gitignore`;
   **never** commit it).
3. The backend mounts it at `/app/firebase-service-account.json` (see `docker-compose.yml`).

## 3. Register the mobile apps

### Android

1. **Add app** → Android.
2. Package name: the one you use in `mobile/android/app/build.gradle.kts`
   (default `com.example.budgettool`). If you change it, use the same one in Firebase.
3. Download `google-services.json` and place it at `mobile/android/app/google-services.json`
   (gitignored).
4. Register the SHA-1 of the keystore that signs the app (Authentication → Settings →
   SHA certificate fingerprints). Without it, Google Sign-In fails.
   ```bash
   keytool -list -v -keystore mobile/android/app/debug.keystore -alias androiddebugkey -storepass android
   ```
   CI uses `ANDROID_DEBUG_KEYSTORE_B64`; register the SHA-1 of **that** keystore.

### iOS

1. **Add app** → iOS.
2. Bundle ID: the same one as in Xcode (`mobile/ios/Runner.xcodeproj`; by default
   `com.example.budgettool`).
3. Download `GoogleService-Info.plist` and place it at
   `mobile/ios/Runner/GoogleService-Info.plist` (gitignored), then **drag it into Xcode**
   (the *Runner* folder, with *Copy items if needed* and the *Runner* target checked).
4. Fill in `mobile/ios/Runner/Info.plist`:
   - `CFBundleURLTypes` → `CFBundleURLSchemes`: `com.googleusercontent.apps.<REVERSED_CLIENT_ID>`
   - `GIDClientID`: the `CLIENT_ID` from the `.plist`.
5. Google Sign-In on Android needs the **WEB-type client ID**:
   ```bash
   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
   ```
   The `web-client-id` comes from `google-services.json` (`oauth_client`, `client_type: 3`).

#### Installing on your own iPhone for free (free Apple ID)

Requirements: a Mac with **Xcode** (App Store, free). CocoaPods is not required:
this project's iOS plugins integrate through Swift Package Manager. If you add a
plugin without SPM support, Flutter will warn you and you'll have to create the `Podfile`.

1. Open Xcode once and accept the license. Then:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
2. Xcode → *Settings → Accounts* → add your Apple ID (this creates the *Personal Team*).
3. `open mobile/ios/Runner.xcworkspace` → *Runner* target → *Signing & Capabilities*
   → *Automatically manage signing* and pick your *Personal Team*. If the bundle ID is
   already taken, use your own and **register it in Firebase as well**.
4. iPhone: *Settings → Privacy & Security → Developer Mode* (turn it on and
   restart). Connect it over USB and tap *Trust this computer*.
5. First time only: *Settings → General → VPN & Device Management* → trust your
   Apple ID.
6. Install in **Release** with the repo script:
   ```bash
   IOS_TEAM_ID=XXXXXXXXXX scripts/install-ios.sh          # a single iPhone
   IOS_TEAM_ID=XXXXXXXXXX scripts/install-ios.sh <UDID>   # several (`flutter devices`)
   ```
   `IOS_TEAM_ID` is obtained with:
   ```bash
   defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier | grep teamID
   ```

**Renew every 7 days:** rerun the same script (the bundle ID is unchanged and your
data is preserved). Free account limitations: the app expires after 7 days, at most
3 development apps per device, and no TestFlight/App Store/Firebase App
Distribution for iOS.

## 4. Development toolchain

### macOS (Apple Silicon)

```bash
make setup
```

Installs Java 17, Flutter, Android SDK, the emulator, Firebase CLI, and FlutterFire CLI.
Add to `~/.zshrc`:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
```

### Ubuntu (headless server)

```bash
make setup
```

Add to `~/.bashrc`:

```bash
export ANDROID_HOME="/opt/android-sdk"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export PATH="$PATH:/opt/flutter/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
```

## 5. Environment variables

Copy the example and fill in your values:

```bash
cp .env.example .env
```

`.env` is gitignored. The minimum for local development:

```bash
FIREBASE_WEB_API_KEY=your-web-api-key
FIREBASE_APP_ID=1:000000000000:android:xxxxxxxxxxxxxxxx
DATABASE_URL=postgres://budget:change-me@localhost:5432/budget
MINIO_ENDPOINT=localhost:9900
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=change-me
```

For local development without Docker:

```bash
set -a && source .env && set +a
cd backend && go run ./cmd/server
```

## 6. Build

```bash
make help          # Show all commands
make check         # Verify the toolchain
make build-backend # Backend (Docker)
make build-apk     # Release APK → dist/
make build-all     # Backend + APK
make test          # Backend + mobile
```

## 7. CI / distribution (optional)

The workflows use repo **secrets** and **variables** (Settings → Secrets and
variables → Actions):

| Name | Type | Use |
|--------|------|-----|
| `PORTAINER_WEBHOOK` | secret | Portainer webhook to redeploy the backend |
| `GOOGLE_SERVICES_JSON` | secret | `google-services.json` in base64 |
| `FIREBASE_TOKEN` | secret | `firebase login:ci` token for App Distribution |
| `ANDROID_DEBUG_KEYSTORE_B64` | secret | Debug keystore in base64 (stable signing) |
| `REGISTRY_USER` | secret | GitHub username for GHCR |
| `REGISTRY_PASSWORD` | secret | PAT with the `write:packages` scope |
| `FIREBASE_APP_ID` | **variable** | Android App ID for App Distribution |
| `DEPLOY_ENABLED` | **variable** | `true` to enable backend deployment |
| `APK_BUILD_ENABLED` | **variable** | `true` to enable the APK build/distribution |

The deploy workflow publishes `ghcr.io/<your-user>/<your-repo>-backend` and
`-mcp`. Portainer only does a `pull`; CI builds and publishes the image.

> The deploy and APK jobs are **disabled by default** so that a fork doesn't fail
> on its first push. Enable them with `DEPLOY_ENABLED=true` and
> `APK_BUILD_ENABLED=true` once you have the secrets configured.

If you'd rather not use GitHub Actions, you can build and deploy with Docker Compose
(see `docs/SELF_HOSTING.md`).

## 8. Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `401` on every request | `FIREBASE_WEB_API_KEY` empty and `ALLOW_DEV_AUTH=false` |
| Google Sign-In fails on Android | The keystore SHA-1 is missing from Firebase |
| Google Sign-In returns without signing in (iOS) | Missing `CFBundleURLTypes` in `Info.plist` |
| `missing google-services.json` | You didn't copy the file from your project |
| The backend won't start | Missing `.env` or `backend/firebase-service-account.json` |
