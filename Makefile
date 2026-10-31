UNAME := $(shell uname)

API_LEVEL  := 36
AVD_NAME   := pixel_6

ifeq ($(UNAME),Darwin)
  ANDROID_SDK ?= $(HOME)/Library/Android/sdk
  JAVA_HOME   ?= /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
else
  ANDROID_SDK ?= /opt/android-sdk
  JAVA_HOME   ?= /usr/lib/jvm/java-17-openjdk-amd64
endif

# App ID de Firebase (Project settings → Your apps → App ID).
# También podés exportarlo en el entorno antes de correr `make distribute`.
FIREBASE_APP_ID ?=
DIST_GROUP      ?= testers
VERSION         := $(shell grep '^version:' mobile/pubspec.yaml | sed 's/version: //' | tr -d ' ')
TEST_DATABASE_URL ?= postgres://budget:change-me@localhost:5432/budget_test
POSTGRES_CONTAINER ?= postgres_container
POSTGRES_USER      ?= budget

.PHONY: setup check emulator build-backend build-apk build-apk-debug distribute distribute-debug build-all test test-backend test-mobile test-mobile db-test-setup clean help version bump-patch bump-minor bump-major

# ═══════════════════════════════════════════════════════════
#  Setup
# ═══════════════════════════════════════════════════════════

setup:
	@echo "=== Setup — $(UNAME) ==="
ifeq ($(UNAME),Darwin)
	@echo "[1/6] Homebrew packages..."
	brew install openjdk@17 flutter || true
	@echo "[2/6] Android SDK packages..."
	mkdir -p $(ANDROID_SDK)
	yes | $(ANDROID_SDK)/cmdline-tools/latest/bin/sdkmanager --sdk_root=$(ANDROID_SDK) \
		"platforms;android-$(API_LEVEL)" \
		"build-tools;$(API_LEVEL).0.0" \
		"platform-tools" \
		"emulator" \
		"system-images;android-$(API_LEVEL);google_apis;arm64-v8a" || true
	@echo "[3/6] Accepting Android SDK licenses..."
	yes | $(ANDROID_SDK)/cmdline-tools/latest/bin/sdkmanager --sdk_root=$(ANDROID_SDK) --licenses || true
	@echo "[4/6] Creating AVD (emulator)..."
	@(\
		avdmanager=$(ANDROID_SDK)/cmdline-tools/latest/bin/avdmanager; \
		avd_name=$(AVD_NAME); \
		if "$$avdmanager" list avd | grep -q "$$avd_name"; then \
			echo "AVD $$avd_name ya existe"; \
		else \
			"$$avdmanager" create avd -n "$$avd_name" \
				-k "system-images;android-$(API_LEVEL);google_apis;arm64-v8a" \
				-d pixel_6 --force; \
		fi \
	) || true
	@echo "[5/6] Firebase CLI..."
	npm install -g firebase-tools || true
	@echo "[6/6] flutterfire_cli..."
	dart pub global activate flutterfire_cli || true
	@echo "[7/7] govulncheck (Go vulnerabilities)..."
	go install golang.org/x/vuln/cmd/govulncheck@latest || true
	@echo "[8/8] osv-scanner (vulnerabilidades Flutter)..."
	@if command -v osv-scanner >/dev/null 2>&1; then echo "osv-scanner ya instalado"; else \
		OS=$$(uname | tr '[:upper:]' '[:lower:]'); ARCH=$$(uname -m); \
		case "$$ARCH" in x86_64|amd64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; *) ARCH=amd64;; esac; \
		VER=$$(curl -sL https://api.github.com/repos/google/osv-scanner/releases/latest | grep -oE '"tag_name":[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\(.*\)"/\1/'); \
		mkdir -p $(HOME)/go-workspace/bin; \
		curl -sL "https://github.com/google/osv-scanner/releases/download/$${VER}/osv-scanner_$${OS}_$${ARCH}" -o $(HOME)/go-workspace/bin/osv-scanner; \
		chmod +x $(HOME)/go-workspace/bin/osv-scanner; \
		echo "osv-scanner instalado en $(HOME)/go-workspace/bin/osv-scanner"; \
	fi
	@echo ""
	@echo "Agrega esto a tu ~/.zshrc:"
	@echo "  export ANDROID_HOME=$(ANDROID_SDK)"
	@echo "  export JAVA_HOME=$(JAVA_HOME)"
	@echo "  export PATH=\"\$$PATH:\$$ANDROID_HOME/platform-tools:\$$ANDROID_HOME/cmdline-tools/latest/bin\""
else
	@echo "[1/6] Dependencias del sistema..."
	sudo apt update -qq && sudo apt install -y openjdk-17-jdk-headless wget unzip xz-utils
	@echo "[2/6] Flutter SDK..."
	@if [ ! -d /opt/flutter ]; then \
		wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.8-stable.tar.xz -O /tmp/flutter.tar.xz; \
		sudo tar -xf /tmp/flutter.tar.xz -C /opt; \
		rm /tmp/flutter.tar.xz; \
		sudo chmod -R 755 /opt/flutter; \
		echo "Flutter instalado en /opt/flutter"; \
	else \
		echo "Flutter ya instalado en /opt/flutter"; \
	fi
	@echo "[3/6] Android SDK..."
	@if [ ! -d $(ANDROID_SDK) ]; then \
		wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip; \
		sudo unzip -q /tmp/cmdline-tools.zip -d /tmp/android-cmdline; \
		sudo mkdir -p $(ANDROID_SDK)/cmdline-tools; \
		sudo mv /tmp/android-cmdline/cmdline-tools $(ANDROID_SDK)/cmdline-tools/latest; \
		rm /tmp/cmdline-tools.zip; \
		sudo chmod -R 755 $(ANDROID_SDK); \
		echo "Android SDK instalado en $(ANDROID_SDK)"; \
	else \
		echo "Android SDK ya instalado en $(ANDROID_SDK)"; \
	fi
	@echo "[4/6] Android SDK packages..."
	yes | $(ANDROID_SDK)/cmdline-tools/latest/bin/sdkmanager --sdk_root=$(ANDROID_SDK) \
		"platforms;android-$(API_LEVEL)" \
		"build-tools;$(API_LEVEL).0.0" \
		"platform-tools" || true
	@echo "[5/6] Firebase CLI..."
	npm install -g firebase-tools || true
	@echo "[6/6] flutterfire_cli..."
	dart pub global activate flutterfire_cli || true
	@echo "[7/7] govulncheck (Go vulnerabilities)..."
	go install golang.org/x/vuln/cmd/govulncheck@latest || true
	@echo "[8/8] osv-scanner (vulnerabilidades Flutter)..."
	@if command -v osv-scanner >/dev/null 2>&1; then echo "osv-scanner ya instalado"; else \
		OS=$$(uname | tr '[:upper:]' '[:lower:]'); ARCH=$$(uname -m); \
		case "$$ARCH" in x86_64|amd64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; *) ARCH=amd64;; esac; \
		VER=$$(curl -sL https://api.github.com/repos/google/osv-scanner/releases/latest | grep -oE '"tag_name":[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\(.*\)"/\1/'); \
		mkdir -p $(HOME)/go-workspace/bin; \
		curl -sL "https://github.com/google/osv-scanner/releases/download/$${VER}/osv-scanner_$${OS}_$${ARCH}" -o $(HOME)/go-workspace/bin/osv-scanner; \
		chmod +x $(HOME)/go-workspace/bin/osv-scanner; \
		echo "osv-scanner instalado en $(HOME)/go-workspace/bin/osv-scanner"; \
	fi
	@echo ""
	@echo "Agrega esto a tu ~/.bashrc:"
	@echo "  export ANDROID_HOME=$(ANDROID_SDK)"
	@echo "  export JAVA_HOME=$(JAVA_HOME)"
	@echo "  export PATH=\"\$$PATH:/opt/flutter/bin:\$$ANDROID_HOME/platform-tools:\$$ANDROID_HOME/cmdline-tools/latest/bin\""
endif

# ═══════════════════════════════════════════════════════════
#  Check
# ═══════════════════════════════════════════════════════════

check:
	@echo "=== Verificando toolchain ($$(uname)) ==="
	@echo -n "Flutter:  "; flutter --version 2>/dev/null | head -1 || echo "NO INSTALADO"
	@echo -n "Java:     "; java -version 2>&1 || echo "NO INSTALADO"
	@echo -n "Android:  "; ls "$(ANDROID_SDK)/platforms" 2>/dev/null | head -1 || echo "NO INSTALADO"
	@echo -n "Firebase: "; firebase --version 2>/dev/null || echo "NO INSTALADO"
	@echo -n "Docker:   "; docker --version 2>/dev/null || echo "NO INSTALADO"
	@echo -n "govulncheck: "; command -v govulncheck >/dev/null 2>&1 && govulncheck -version 2>/dev/null | head -1 || echo "NO INSTALADO (go install golang.org/x/vuln/cmd/govulncheck@latest)"
	@echo -n "osv-scanner: "; command -v osv-scanner >/dev/null 2>&1 && osv-scanner --version 2>/dev/null | head -1 || echo "NO INSTALADO (make setup descarga el binario)"

# ═══════════════════════════════════════════════════════════
#  Emulator (macOS only)
# ═══════════════════════════════════════════════════════════

emulator:
ifeq ($(UNAME),Darwin)
	$(ANDROID_SDK)/emulator/emulator -avd $(AVD_NAME) -no-snapshot &
	@echo "Emulador $(AVD_NAME) iniciado"
else
	@echo "Emulador no soportado en servidor sin GUI"
endif

# ═══════════════════════════════════════════════════════════
#  Build — Backend
# ═══════════════════════════════════════════════════════════

build-backend:
	docker compose build backend

run-backend:
	docker compose up -d backend

# ═══════════════════════════════════════════════════════════
#  Version
# ═══════════════════════════════════════════════════════════

version:
	@echo $(VERSION)

bump-patch:
	@OLD=$$(grep '^version:' mobile/pubspec.yaml | sed 's/version: //' | tr -d ' '); \
	MAJOR=$$(echo $$OLD | cut -d. -f1); \
	MINOR=$$(echo $$OLD | cut -d. -f2); \
	PATCH=$$(echo $$OLD | cut -d. -f3 | cut -d+ -f1); \
	BUILD=$$(echo $$OLD | cut -d+ -f2); \
	NEWPATCH=$$((PATCH + 1)); \
	NEWBUILD=$$((BUILD + 1)); \
	sed -i "s/^version: .*/version: $$MAJOR.$$MINOR.$$NEWPATCH+$$NEWBUILD/" mobile/pubspec.yaml; \
	echo "$$OLD → $$MAJOR.$$MINOR.$$NEWPATCH+$$NEWBUILD"

bump-minor:
	@OLD=$$(grep '^version:' mobile/pubspec.yaml | sed 's/version: //' | tr -d ' '); \
	MAJOR=$$(echo $$OLD | cut -d. -f1); \
	MINOR=$$(echo $$OLD | cut -d. -f2); \
	BUILD=$$(echo $$OLD | cut -d+ -f2); \
	NEWMINOR=$$((MINOR + 1)); \
	NEWBUILD=$$((BUILD + 1)); \
	sed -i "s/^version: .*/version: $$MAJOR.$$NEWMINOR.0+$$NEWBUILD/" mobile/pubspec.yaml; \
	echo "$$OLD → $$MAJOR.$$NEWMINOR.0+$$NEWBUILD"

bump-major:
	@OLD=$$(grep '^version:' mobile/pubspec.yaml | sed 's/version: //' | tr -d ' '); \
	MAJOR=$$(echo $$OLD | cut -d. -f1); \
	BUILD=$$(echo $$OLD | cut -d+ -f2); \
	NEWMAJOR=$$((MAJOR + 1)); \
	NEWBUILD=$$((BUILD + 1)); \
	sed -i "s/^version: .*/version: $$NEWMAJOR.0.0+$$NEWBUILD/" mobile/pubspec.yaml; \
	echo "$$OLD → $$NEWMAJOR.0.0+$$NEWBUILD"

# ═══════════════════════════════════════════════════════════
#  Build — Mobile APK
# ═══════════════════════════════════════════════════════════

build-apk:
	cd mobile && ANDROID_HOME=$(ANDROID_SDK) JAVA_HOME=$(JAVA_HOME) PATH=/opt/flutter/bin:$$PATH \
		flutter build apk --release
	@mkdir -p dist
	@cp mobile/build/app/outputs/flutter-apk/app-release.apk dist/budget-tracker-v$(VERSION).apk
	@echo ""
	@echo "APK generado: dist/budget-tracker-v$(VERSION).apk   ($$(du -sh dist/budget-tracker-v$(VERSION).apk | cut -f1))"

build-apk-debug:
	cd mobile && ANDROID_HOME=$(ANDROID_SDK) JAVA_HOME=$(JAVA_HOME) PATH=/opt/flutter/bin:$$PATH \
		flutter build apk --debug
	@mkdir -p dist
	@cp mobile/build/app/outputs/flutter-apk/app-debug.apk dist/budget-tracker-v$(VERSION)-debug.apk
	@echo ""
	@echo "APK debug generado: dist/budget-tracker-v$(VERSION)-debug.apk   ($$(du -sh dist/budget-tracker-v$(VERSION)-debug.apk | cut -f1))"

build-android-install:
	cd mobile && ANDROID_HOME=$(ANDROID_SDK) JAVA_HOME=$(JAVA_HOME) PATH=/opt/flutter/bin:$$PATH flutter install

# ═══════════════════════════════════════════════════════════
#  Distribute — Firebase App Distribution
# ═══════════════════════════════════════════════════════════

distribute:
	@test -n "$(FIREBASE_APP_ID)" || { echo "Falta FIREBASE_APP_ID (Firebase → Project settings → Your apps → App ID)"; exit 1; }
	$(MAKE) bump-patch
	$(MAKE) build-apk
	@VER=$$(grep '^version:' mobile/pubspec.yaml | sed 's/version: //' | tr -d ' '); \
	echo "Subiendo APK a Firebase App Distribution..."; \
	firebase appdistribution:distribute dist/budget-tracker-v$${VER}.apk \
		--app $(FIREBASE_APP_ID) \
		--groups $(DIST_GROUP) \
		--release-notes "v$${VER} · $$(date -I) · $$(git rev-parse --short HEAD)"

distribute-debug:
	@test -n "$(FIREBASE_APP_ID)" || { echo "Falta FIREBASE_APP_ID (Firebase → Project settings → Your apps → App ID)"; exit 1; }
	$(MAKE) bump-patch
	$(MAKE) build-apk-debug
	@VER=$$(grep '^version:' mobile/pubspec.yaml | sed 's/version: //' | tr -d ' '); \
	echo "Subiendo APK debug a Firebase App Distribution..."; \
	firebase appdistribution:distribute dist/budget-tracker-v$${VER}-debug.apk \
		--app $(FIREBASE_APP_ID) \
		--groups $(DIST_GROUP) \
		--release-notes "v$${VER}-debug · $$(date -I) · $$(git rev-parse --short HEAD)"

# ═══════════════════════════════════════════════════════════
#  Build All
# ═══════════════════════════════════════════════════════════

build-all: build-backend build-apk

deploy: build-backend distribute

# ═══════════════════════════════════════════════════════════
#  Tests
# ═══════════════════════════════════════════════════════════

test-backend:
	cd backend && TEST_DATABASE_URL=$(TEST_DATABASE_URL) $(HOME)/go/bin/go test -p 1 ./...

test-mobile:
	cd mobile && PATH=/opt/flutter/bin:$$PATH flutter test

test: test-backend test-mobile

# ═══════════════════════════════════════════════════════════
#  Test DB
# ═══════════════════════════════════════════════════════════

db-test-setup:
	@docker exec $(POSTGRES_CONTAINER) psql -U $(POSTGRES_USER) -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='budget_test'" | grep -q 1 \
		&& echo "budget_test ya existe" \
		|| docker exec $(POSTGRES_CONTAINER) createdb -U $(POSTGRES_USER) budget_test
	@for f in $$(ls backend/migrations/*.up.sql | sort); do \
		echo "Aplicando $$f"; \
		docker exec -i $(POSTGRES_CONTAINER) psql -U $(POSTGRES_USER) -d budget_test -q < "$$f"; \
	done
	@echo "✓ Base de datos de test lista (budget_test)"

# ═══════════════════════════════════════════════════════════
#  Backup
# ═══════════════════════════════════════════════════════════

backup:
	bash scripts/backup-db.sh

# ═══════════════════════════════════════════════════════════
#  Clean
# ═══════════════════════════════════════════════════════════

clean:
	rm -rf dist
	@if [ -d mobile ]; then cd mobile && flutter clean; fi
	docker compose down 2>/dev/null || true

# ═══════════════════════════════════════════════════════════
#  Help
# ═══════════════════════════════════════════════════════════

help:
	@echo ""
	@echo "  Budget Tracker — Makefile ($$(uname))"
	@echo "  ────────────────────────────────────────"
	@echo ""
	@echo "  Setup:"
	@echo "    make setup          Instalar toolchain (Java, Flutter, Android SDK, Emulador, Firebase CLI)"
	@echo "    make check          Verificar que todo esté instalado"
	@echo "    make emulator       Iniciar emulador Android (solo macOS)"
	@echo ""
	@echo "  Build:"
	@echo "    make build-backend  Compilar backend Go (Docker)"
	@echo "    make build-apk      Compilar APK release (sin features de debug)"
	@echo "    make build-apk-debug Compilar APK debug (con panel de config e indicador)"
	@echo "    make distribute     Build APK release + subir a Firebase App Distribution"
	@echo "    make distribute-debug Build APK debug + subir a Firebase App Distribution"
	@echo "    make build-all      Backend + APK"
	@echo "    make deploy         Backend + APK + distribucion"
	@echo ""
	@echo "  Version:"
	@echo "    make version        Mostrar version actual"
	@echo "    make bump-patch     Subir version parche (1.0.0 → 1.0.1)"
	@echo "    make bump-minor     Subir version menor (1.0.0 → 1.1.0)"
	@echo "    make bump-major     Subir version mayor (1.0.0 → 2.0.0)"
	@echo ""
	@echo "  Run:"
	@echo "    make run-backend    Iniciar backend con Docker Compose"
	@echo "    make build-android-install  Compilar APK e instalar en dispositivo/emulador conectado"
	@echo ""
	@echo "  Test:"
	@echo "    make test           Tests backend + mobile"
	@echo "    make test-backend   Tests del backend Go (usa budget_test)"
	@echo "    make test-mobile    Tests del Flutter"
	@echo "    make db-test-setup  Crear/aplicar migraciones a la BD de test (budget_test)"
	@echo ""
	@echo "  Backup:"
	@echo "    make backup         Backup manual de PostgreSQL"
	@echo ""
	@echo "  Clean:"
	@echo "    make clean          Limpiar artefactos de build"
	@echo ""
