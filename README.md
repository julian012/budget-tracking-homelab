# AI Budget Tracking

Monorepo for personal expense tracking powered by artificial intelligence.

> **Want your own instance?** This repo is a self-hosted template: it ships no
> credentials or domains. Follow `docs/SELF_HOSTING.md` to fork it and connect it
> to your own Firebase/Homelab. MIT license.

> **Note:** the mobile app UI is currently Spanish-only. Documentation, CI, and infrastructure files are in English.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  MOBILE (Flutter + Firebase)                            │
│  Phone app to log and view expenses                     │
│  Firebase Auth → obtains JWT                            │
│  Sends requests to the backend with the token           │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTPS (tunnel / reverse proxy)
                      ▼
┌─────────────────────────────────────────────────────────┐
│  BACKEND (Go + Docker)                                  │
│  REST API on port 4000                                  │
│  Validates Firebase JWT → stores in PostgreSQL          │
│  Files (photos, audio) → stores in MinIO                │
│  Processes invoices/voice with AI (OpenCode Go)         │
└──────────┬──────────────────────┬───────────────────────┘
           │                      │
           ▼                      ▼
┌──────────────────┐   ┌──────────────────────────────────┐
│  PostgreSQL 17   │   │  MCP SERVER (Python)             │
│  Tables:         │   │  Connects to PostgreSQL          │
│  users           │   │  Tools for OpenClaw:             │
│  categories      │   │  - get_expenses_by_category      │
│  expenses        │   │  - get_expenses_summary          │
└──────────────────┘   │  - get_expense_chart (charts)    │
                        │  - get_monthly_trends            │
┌──────────────────┐   │  - get_weekly_spending           │
│  MinIO           │   └──────────────┬───────────────────┘
│  Buckets:        │                  │
│  receipts        │                  ▼
│  audio           │   ┌──────────────────────────────────┐
└──────────────────┘   │  OpenClaw (Telegram/WhatsApp)    │
                        │ "How much did I spend on lunches?"│
                        │  → Calls MCP tools               │
                        │  → Replies with data + chart     │
                        └──────────────────────────────────┘
```

## Project structure

```
budget-tracking-homelab/
├── backend/              # REST API in Go
│   ├── cmd/server/       # Entrypoint
│   ├── internal/
│   │   ├── handler/      # HTTP handlers (CRUD, uploads)
│   │   ├── service/      # Business logic + AI
│   │   ├── repository/   # PostgreSQL queries (pgx)
│   │   ├── storage/      # MinIO client
│   │   ├── middleware/   # Firebase JWT auth, CORS
│   │   ├── config/       # Environment variables
│   │   └── models/       # Shared types
│   ├── migrations/       # SQL (up/down)
│   └── Dockerfile
├── mcp-server/           # MCP Server for OpenClaw
│   ├── server.py         # FastMCP, 5 tools
│   ├── db.py             # PostgreSQL queries
│   └── charts.py         # matplotlib (bar, pie, line)
├── mobile/               # Flutter app
│   ├── lib/
│   │   ├── main.dart          # Entry point + Firebase init + AuthGate + RouteObserver
│   │   ├── screens/           # Screens
│   │   │   ├── login_screen.dart    # Login/signup + server panel (debug)
│   │   │   ├── home_screen.dart     # Shell with bottom nav + Quick Add FAB + Dashboard
│   │   │   ├── expenses_screen.dart # Expense list (search, filters, pagination, action sheets)
│   │   │   ├── reports_screen.dart  # Insights: KPIs, trend, donut, drill-down by category
│   │   │   └── profile_screen.dart  # Profile dashboard: avatar, card carousel, category grids
│   │   ├── widgets/           # Reusable widgets
│   │   │   ├── category_form_sheet.dart  # Category form (hybrid emoji, fixed/variable, defaultType)
│   │   │   ├── expense_form_sheet.dart   # Expense form (create/edit, payment method, emoji outside the input)
│   │   │   ├── card_form_sheet.dart      # Card form (brand, color, closing/payment, limit)
│   │   │   ├── profile_edit_sheet.dart   # Profile form (name + emoji avatar)
│   │   │   ├── wallet_card.dart          # Wallet card (AspectRatio 1.58, gradient, 1/4 logo)
│   │   │   └── category_card.dart        # CategoryCard + CategoryGrid + EmptySection
│   │   ├── services/
│   │   │   ├── auth_service.dart       # Firebase Auth wrapper
│   │   │   ├── api_service.dart        # Backend HTTP client (expenses, categories, cards, profile CRUD)
│   │   │   ├── profile_controller.dart # ChangeNotifier avatar/displayName (reactive bottom nav)
│   │   │   └── server_config.dart      # Persisted server URL (SharedPreferences)
│   │   ├── theme/
│   │   │   └── budget_theme.dart    # Material 3 + design tokens
│   │   └── utils/
│   │       ├── currency_formatter.dart  # Currency formatting + ThousandsFormatter
│   │       ├── icon_helper.dart         # Shared emoji/Lucide rendering
│   │       ├── default_categories.dart  # Default category seed (cold start)
│   │       ├── stats_sort.dart          # Descending order of groupings (dashboard)
│   │       ├── pie_slices.dart          # Top 5 consolidation + "Other" (reports donut)
│   │       ├── default_amount.dart      # Default value logic (parse/format/update)
│   │       ├── split_expenses.dart      # Split expense calculation (main + sub-expenses)
│   │       └── expense_grouping.dart    # Groups expenses by transaction_group_id in lists
│   ├── test/             # Tests (flutter test)
│   └── android/          # Android config (google-services.json, build.gradle)
├── .opencode/            # OpenCode config
│   ├── skills/           # Skills (run-tests, build-apk, db-migration, etc.)
│   └── prompts/          # System prompts per agent
├── Makefile              # Centralized commands (setup, build, distribute, test)
├── dist/                 # Generated APKs (budget-tracker.apk)
├── docker-compose.yml    # Backend on port 4000
└── docs/SETUP.md         # Firebase/Google Cloud guide
```

## State management (Mobile)

- **Provider** (`provider` + `ChangeNotifierProvider`)
  - `ServerConfig` (ChangeNotifier): server URL + connection indicator, persisted in `shared_preferences`
  - `AuthService`: Firebase auth state via `authStateChanges()`
  - Consumed with `context.read()` (events) and `context.watch()` (rebuilds)
- `ValueNotifier<int>` shared between tabs to refresh data when creating/editing expenses and categories

## Main dependencies (Mobile)

| Package | Purpose |
|---------|---------|
| `firebase_core` / `firebase_auth` | Initialization + authentication (email/Google) |
| `google_sign_in` | Google login |
| `provider` | State management |
| `http` | HTTP client for the backend |
| `shared_preferences` | Config persistence (server URL, indicator) |
| `intl` | Currency and date formatting in Spanish |
| `fl_chart` | Charts (bar, pie/donut) in Dashboard and Reports |
| `flutter_lucide` | Iconography |
| `font_awesome_flutter` | Brand logos (Visa, Mastercard, Amex, Diners) on cards |
| `flutter_localizations` | Localization (Spanish) for DatePickers |

## User flows (Mobile)

### 1. Authentication
```
App → AuthGate → (no session) LoginScreen → (session) HomeScreen
LoginScreen: email/password or Google → AuthService → Firebase Auth → AuthGate redirects
```

### 2. Dashboard (Home)
```
HomeScreen → DashboardTab → GET /api/stats + /api/expenses
Filters: 7 days | 15 days | This month | Previous month | 📅 Custom
Summary: total + comparison vs previous period (↑/↓ %)
"Owed to you" card: when there are pending shared debts, tapping opens the Shared tab
Categories: toggle bars ↔ pie/donut (colors from the DB)
Latest expenses: 5 most recent
```

### 3. Log an expense
```
FAB (+) → expands: horizontal tray of chips (emoji + name) with the user's Presets (or, if none, the latest categories) + Photo | Audio | Form
Quick Add → bottom sheet with Amount only → saves with category + today's date
Tap a preset chip → opens ExpenseFormSheet with amount, category, payment method and description preloaded (today's date); the user just confirms and saves
Form → ExpenseFormSheet: amount (automatic thousands), payment method (Cash or card), category carousel, date
When selecting a category with default_amount > 0 → the amount autofills (e.g. $ 8,500)
When saving a NEW expense with an amount different from the default → dialog "Just this once" / "Update" (PUT of the category in the background)
Description (optional): visible only if the category has requires_description = true; if false the field is hidden
Split expense: "+ Add sub-expense" button → breaks the total amount into a main expense + N sub-expenses, each with its own category; all share transaction_group_id (UUID generated on the client) and are sent as multiple POST /api/expenses. In Dashboard/Expenses they are shown visually grouped
Shared expense: "Shared" toggle to split the expense among local people; a single POST /api/expenses is sent with `shares`. It is mutually exclusive with category split
Create category → CategoryFormSheet: name, hybrid emoji selector (10 predefined + custom), type (Fixed/Variable), "Include description in expenses" toggle, "Default value (Optional)" field, color
POST /api/expenses (with card_id if paid by card) → refreshes Dashboard + Expenses + Reports
Expenses paid by card show the brand logo + color to the left of the amount
```

### 4. Expense list
```
ExpensesScreen → GET /api/expenses
Search with debounce, filters (All/This month/Previous month), grouping by relative date (Today/Yesterday/This week/dd MMM)
Pagination 20 at a time (infinite scroll) + "back to top" FAB (offset > 300px)
Tap an expense → Action Sheet: Edit (opens ExpenseFormSheet) / Delete (confirmation)
AutomaticKeepAliveClientMixin keeps state when switching tabs
```

### 5. Reports (insights)
```
ReportsScreen → GET /api/stats (default: last 3 months)
KPIs with comparison vs previous period
Monthly trend (bar chart) + budget line (average)
Consolidated donut by category: Top 5 + "Other" (max 6, no overflow; "Other" with dynamic gray based on theme)
Largest expenses → filter All | Fixed | Variable via GET /api/stats?type=fixed|variable (period + type)
Tap a category → drill-down (bottom sheet with the period's transactions)
```

### 6. Profile (Dashboard)
```
ProfileScreen → avatar (emoji/initial/👤) + display_name + email + "Edit Profile" button
The avatar is reflected in the BottomNavigationBar (Profile tab) via ProfileController (reactive)
Quick Presets → carousel (emoji, name, amount) + "+" button (PresetFormSheet)
Payment Methods → horizontal carousel (WalletCard: gradient, 1/4 logo, onTap → Edit/Delete)
Variable Expenses / Fixed Expenses → category grids (CategoryGrid) with a + button per section
Create/Edit category → CategoryFormSheet with defaultType (Variable/Fixed) pre-selected
Create/Edit card → CardFormSheet (brand, color, closing/payment, limit)
Create/Edit preset → PresetFormSheet (name, emoji, amount, category, optional payment method, description)
Delete → bottom-sheet style confirmation (red DELETE button)
```

### 7. Cards module
```
Payment Methods (in Profile) → WalletCard carousel
CardFormSheet → name, brand (visa/mastercard/amex/diners/other), color (palette), closing day (1-31), payment day (1-31), optional limit (thousands)
Tap a card → Action Sheet: Edit / Delete (confirmation)
Full CRUD: POST / GET / PUT / DELETE /api/cards
```

## How the 3 parts work together

### 1. Expense logging flow

```
User opens the app → Login with Google (Firebase Auth)
    ↓
Firebase returns a JWT → the app stores it
    ↓
User adds an expense (form / receipt photo / audio)
    ↓
App sends POST /api/expenses with the JWT in the Authorization header
    ↓
Backend validates the JWT against Firebase → gets user_id
    ↓
If it is a photo: stores in MinIO → sends to AI (vision) → extracts amount, concept, category
If it is audio: stores in MinIO → sends to AI (voice) → transcribes → extracts data
If it is a form: stores directly
    ↓
Backend saves to PostgreSQL (expenses table)
    ↓
App updates the Dashboard with stats
```

### 2. Chat query flow (OpenClaw + MCP)

```
User writes in Telegram/WhatsApp:
  "how much did I spend on lunches this week?"
    ↓
OpenClaw receives the message → the agent decides to use an MCP tool
    ↓
Calls: get_expenses_by_category("lunches", "this_week")
    ↓
MCP Server (Python) → queries PostgreSQL → returns JSON with expenses + total
    ↓
OpenClaw replies in the chat:
  "You spent $85,300 on lunches this week. [bar chart]"
```

### 3. Build + deploy flow

```
git push to main
  ├─ Changes in backend/ → GitHub Actions → build+push image to GHCR → Portainer webhook → pull + redeploy backend
  └─ Changes in mobile/  → GitHub Actions → build APK
                              ├─ release → artifact in the run
                              └─ debug   → Firebase App Distribution (testers get a notification)
```

The `Deploy backend + APK` workflow (`deploy.yml`) triggers only the layers that changed (`dorny/paths-filter`). The backend is deployed via the image ``ghcr.io/<your-user>/<your-repo>-backend`` (CI builds+pushes it; Portainer pulls it). The APK is signed with the stable keystore from the `ANDROID_DEBUG_KEYSTORE_B64` secret (stable Google Sign-In). See `docs/NETWORK.md` for the full flow.

## Commands

### General (Makefile)

```bash
make check             # Verify installed toolchain
make build-backend     # Build backend (Docker)
make build-apk         # Build Flutter APK → dist/budget-tracker.apk
make distribute        # Build APK + upload to Firebase App Distribution
make test              # Backend and mobile tests
make deploy            # Backend + APK + distribution
```

### Backend (Go)

```bash
cd backend && go test ./...           # Go tests
cd backend && go run ./cmd/server     # Local dev (port 4000)
```

### MCP Server (Python)

```bash
cd mcp-server && python3 -m pytest . -v  # Python tests
```

### Mobile (Flutter)

```bash
cd mobile && flutter run             # Dev with hot-reload
cd mobile && flutter test            # Tests
```

### Emulator (macOS only)

```bash
make emulator                         # Start the pixel_6 emulator
```

### Build APK

```bash
make build-apk                        # Build release APK (without debug features)
make build-apk-debug                  # Build debug APK (server panel + indicator)
make distribute                       # automatic bump + build + Firebase App Distribution
make distribute-debug                 # automatic bump + build debug APK + Firebase
make version                          # Show current version (pubspec.yaml)
make bump-patch                       # Bump patch: 1.0.0 → 1.0.1
make bump-minor                       # Bump minor: 1.0.0 → 1.1.0
make bump-major                       # Bump major: 1.0.0 → 2.0.0
```

> **Note on versioning:** `make distribute` and `make distribute-debug` automatically run `bump-patch` before building. This increments the `versionCode` (`+N`) in `pubspec.yaml`, which is required for Firebase App Distribution to generate a **new release** (if the build number does not change, Firebase reuses the previous release and testers do not get the update). The `+N` must always increase on every publication; semver (`1.0.0`) only goes up with significant changes.
>
> **In CI** (`deploy.yml`), the APK versionCode is computed as `pubspec_versionCode + run_number` (e.g. `24 + 6 = 30`), always greater than the local one and monotonic — so builds update over the installed one instead of reinstalling (avoids losing the session due to a signature/versionCode change).
>
> **MVP milestone:** the first stable version is pinned at `1.0.0` (build `+6`). From here on, `make bump-patch` will increment the `+N` (build number) while keeping semver `1.0.0` until there are significant features (`bump-minor` → `1.1.0`) or breaking changes in a public release (`bump-major` → `2.0.0`).

## API endpoints

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| `GET` | `/health` | No | Health check |
| `GET` | `/api/expenses` | JWT | List expenses (filters: date, category) |
| `POST` | `/api/expenses` | JWT | Create an expense manually |
| `GET` | `/api/expenses/:id` | JWT | Expense details |
| `PUT` | `/api/expenses/:id` | JWT | Edit an expense |
| `DELETE` | `/api/expenses/:id` | JWT | Delete an expense |
| `POST` | `/api/expenses/receipt` | JWT | Upload receipt photo + AI |
| `POST` | `/api/expenses/voice` | JWT | Upload audio + AI |
| `GET` | `/api/categories` | JWT | List categories (includes `default_amount`, `type`) |
| `POST` | `/api/categories` | JWT | Create a category (name, emoji, color, type, `default_amount`) |
| `PUT` | `/api/categories/{id}` | JWT | Edit a category (name, emoji, color, type, `default_amount`) |
| `DELETE` | `/api/categories/{id}` | JWT | Delete a category |
| `GET` | `/api/users/profile` | JWT | Get the user profile (display_name, avatar) |
| `PUT` | `/api/users/profile` | JWT | Update the user profile |
| `GET` | `/api/cards` | JWT | List cards |
| `POST` | `/api/cards` | JWT | Create a card |
| `PUT` | `/api/cards/{id}` | JWT | Edit a card |
| `DELETE` | `/api/cards/{id}` | JWT | Delete a card |
| `GET` | `/api/presets` | JWT | List expense presets |
| `POST` | `/api/presets` | JWT | Create a preset (name, emoji, amount, category, optional card, description) |
| `PUT` | `/api/presets/{id}` | JWT | Edit a preset |
| `DELETE` | `/api/presets/{id}` | JWT | Delete a preset |
| `GET` | `/api/people` | JWT | List local people (optionally includes archived with `?include_archived=true`) |
| `POST` | `/api/people` | JWT | Create a local person (name, color, icon) |
| `PUT` | `/api/people/{id}` | JWT | Edit a local person |
| `POST` | `/api/people/{id}/archive` | JWT | Archive a person (hidden from new expenses) |
| `POST` | `/api/people/{id}/unarchive` | JWT | Unarchive a person |
| `GET` | `/api/people/{id}/shares` | JWT | Debts of a person (`?status=pending|settled|all`) |
| `GET` | `/api/people/{id}/payments` | JWT | Recorded payments of a person |
| `POST` | `/api/people/{id}/payments` | JWT | Record a received payment; it is distributed FIFO to the oldest debts |
| `DELETE` | `/api/payments/{id}` | JWT | Delete a payment and revert its FIFO allocation |
| `GET` | `/api/shared/summary` | JWT | Shared debt summary: total pending + list by person |
| `GET` | `/api/stats` | JWT | Dashboard (totals by category/method/month, filters `start_date`/`end_date`/`type=fixed\|variable`) |

## MCP tools

| Tool | Parameters | Description |
|------|-----------|-------------|
| `get_expenses_by_category` | `category_name`, `period` | Expenses by category in a period |
| `get_expenses_summary` | `period_start`, `period_end` | Summary by category |
| `get_expense_chart` | `period`, `chart_type` | PNG chart (bar/pie/line) |
| `get_monthly_trends` | `months` | Monthly trend for the last N months |
| `get_weekly_spending` | — | Daily breakdown of the week |

## Stack

| Layer | Technology |
|------|-----------|
| Backend | Go 1.26+ (toolchain 1.26.9), chi, pgx v5, minio-go v7 |
| MCP | Python 3.10+, FastMCP, psycopg2, matplotlib |
| Mobile | Flutter 3.44.8 (pinned in CI), Dart, Provider, http, intl, fl_chart, flutter_lucide |
| Auth | Firebase Authentication (Google + Email) |
| DB | PostgreSQL 17 (categories with a `type` field: 0=Variable, 1=Fixed; `requires_description`; `default_amount`) |
| Files | MinIO (S3-compatible) |
| AI | OpenCode Go API (DeepSeek V4 Pro) |
| Deploy | Docker + Portainer GitOps (backend) / Firebase App Distribution (mobile) |
| Tunnel | Cloudflare Tunnel (optional) → `api.example.com` |
| Backup | `scripts/backup-db.sh` — daily pg_dump (cron 2:00 AM), 7-day rotation |

## Documentation

| File | Content |
|---------|-----------|
| `AGENTS.md` | Repo conventions, commands, structure |
| `docs/SETUP.md` | Firebase / Google Cloud configuration |
| `docs/NETWORK.md` | Network, tunnel/reverse proxy and deployment |
| `docs/db-schema.md` | PostgreSQL table schema |
| `docs/TESTING.md` | Test user and checks |
| `docs/STYLE_GUIDE.md` | UI patterns, components, design tokens, Flutter conventions |
| `docs/BACKUP.md` | Daily backup strategy + restore |
| `docs/SELF_HOSTING.md` | Step-by-step guide to fork and self-host |
| `LICENSE` | MIT |
| `user-flows.md` | Implemented and pending user flows |
| `mobile/design-tokens.json` | Design tokens (colors, typography, spacing) |

## Daily backup

The PostgreSQL backup runs automatically every day at 2:00 AM via cron:

```bash
# Manual
bash scripts/backup-db.sh

# Restore
docker exec -i postgres_container psql -U budget -d budget < backup-2026-08-06.sql
```

See `docs/BACKUP.md` for detailed restore and configuration instructions.
