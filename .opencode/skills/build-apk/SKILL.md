---
name: build-apk
description: Build the Android APK locally and distribute via Firebase App Distribution
---

## Build and distribute APK

Build the Flutter APK locally and upload to Firebase App Distribution.

### Build only

```bash
make build-apk
```

Generates `dist/budget-tracker.apk`.

### Build + distribute

```bash
make distribute
```

Builds the APK and uploads to Firebase App Distribution group `testers`.

With release notes:

```bash
make distribute RELEASE_NOTES="New login screen with Firebase Auth"
```

### Build everything

```bash
make deploy
```

Builds backend (Docker) + APK + distributes.

## What it does

1. `flutter build apk --release` — builds locally (~2-5 min)
2. Copies the APK to `dist/budget-tracker.apk`
3. `firebase appdistribution:distribute` — uploads to Firebase
4. Testers get a notification to install

## Prerequisites

- `make setup` completed (Flutter, Java 17, Android SDK)
- `FIREBASE_TOKEN` configured (`firebase login:ci` or `firebase login`)
- Correct `FIREBASE_APP_ID` in the Makefile (from google-services.json)
- `google-services.json` in `mobile/android/app/`
