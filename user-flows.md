# Budget Tracker — User Flows

> **Living document** — Last updated: 2026-08-25
> **Current app version**: v2.0.0+ (see `make version`)

---

## Navigation Overview

```
App Launch → AuthGate
  ├─ FirebaseAuth.authStateChanges()
  ├─ No session → LoginScreen
  │   ├─ Email/Password Login
  │   ├─ Google Sign-In
  │   └─ Toggle: Sign Up ⇄ Sign In
  └─ Session → HomeScreen
       ├─ BottomNavigationBar (5 tabs):
       │   ├─ [0] Home      → DashboardTab
       │   ├─ [1] Expenses  → ExpensesScreen
       │   ├─ [2] Reports   → ReportsScreen
       │   ├─ [3] Shared    → SharedScreen
       │   └─ [4] Profile   → ProfileScreen
       ├─ FAB (+) → expands: chip tray (Quick Presets, or recent categories) | Photo | Audio | Form
       └─ Tap a Preset → pre-filled ExpenseFormSheet (amount/category/method/description)
```

---

## Implemented Flows

### 1. Authentication

#### 1.1 AuthGate (Root)
| Field | Detail |
|-------|--------|
| **Route / Widget** | `AuthGate` in `lib/main.dart` |
| **UX purpose** | Decide whether to show login or home based on the Firebase session + seed default categories on cold start |
| **Triggers** | `FirebaseAuth.authStateChanges()` |
| **Status** | ✅ Complete |

#### 1.2 LoginScreen
| Field | Detail |
|-------|--------|
| **Route / Widget** | `LoginScreen` in `lib/screens/login_screen.dart` |
| **UX purpose** | Authenticate via email/password or Google; toggle login/sign-up; server configuration panel (debug) |
| **Components** | `TextField` (email + password), `FilledButton` (submit), `OutlinedButton.icon` (Google), `TextButton` (toggle), `ExpansionTile` (server config panel) |
| **Layout** | `Scaffold → SafeArea → Center → SingleChildScrollView` |
| **Spacing** | `24px` outer padding, `16px` between fields |
| **Validation** | `FirebaseAuthException` → Spanish messages via `_mapAuthError()` |
| **Status** | ✅ Complete |

### 2. Dashboard (Home)

#### 2.1 DashboardTab
| Field | Detail |
|-------|--------|
| **Route / Widget** | `DashboardTab` in `lib/screens/home_screen.dart` |
| **UX purpose** | Financial summary: period total, date filters, breakdown by category/method, recent expenses |
| **Components** | `FilterChip` (7d/15d/This month/Last month/Custom), `PieChart` (toggle By Category/By Method), `Card` (total summary), `ListView` (recent expenses) |
| **Filters** | Horizontal `SingleChildScrollView` with `FilterChip` + `ActionChip` (Custom with `showDateRangePicker`) |
| **Breakdown** | `SegmentedButton` toggle between "By Category" and "By Method" (only visible when there are cards) |
| **"Te deben" card** | Appears when `GET /api/shared/summary` reports outstanding debts; tapping opens the Shared tab |
| **Empty** | "Empieza registrando tu primer gasto" in gray centered `bodyMedium` |
| **Refresh** | `RefreshIndicator` + `ValueNotifier<int>` shared with ExpensesScreen |
| **Status** | ✅ Complete |

### 3. Recording an Expense

#### 3.1 FAB Quick Add
| Field | Detail |
|-------|--------|
| **Widget** | FAB in HomeScreen |
| **UX purpose** | Expanding the FAB (+) shows a horizontal tray of **rectangular chips with emoji + name** for the user's **Quick Presets**; if there are none, it falls back to the most recent categories. Right below are the main actions: Photo / Audio / Form |
| **Components** | `FloatingActionButton` + `_buildFabTray()` (horizontal `SingleChildScrollView`, right-aligned) with `_FabChip` (emoji + name, Tooltip), populated by `_loadFabItems()` (`getPresets`, fallback `extractRecentCategories`) |
| **No stale cache (#122)** | `_loadFabItems()` refetches `GET /api/presets` on **every FAB open** (it previously short-circuited on `_presets.isNotEmpty`, so the first load stuck: only 1 preset was shown) |
| **Presets in the FAB** | Tapping a chip opens `ExpenseFormSheet(preset: ...)` with **all** fields pre-filled (amount, category, description and payment method when applicable) and today's date (#114) |
| **Mini form (#87)** | Choosing a category opens `_QuickAddSheet` (**amount** only, no description). "Guardar" creates the expense and closes with the SnackBar "Gasto guardado"; the button is disabled while saving (prevents duplicates). Empty amount → "Ingresa un monto válido"; if the server fails the sheet stays open with "No se pudo guardar el gasto" (or "Sin conexión…" for network errors). Saving used to end in the red `_dependents.isEmpty` screen because the amount controller was disposed on `pop` while the sheet was still animating |
| **Status** | ✅ Complete |

#### 3.2 ExpenseFormSheet
| Field | Detail |
|-------|--------|
| **Widget** | `ExpenseFormSheet` in `lib/widgets/expense_form_sheet.dart` |
| **UX purpose** | Full form: amount (automatic thousands separators), category (carousel), payment method (Cash/Card), date, description (conditional) |
| **Components** | `ModalBottomSheet` (isScrollControlled, radius 28px), horizontal category carousel, `SegmentedButton` (Variable/Fixed), `DatePicker` |
| **Amount autofill** | Selecting a category (or opening with the first one) whose `default_amount > 0` autofills the formatted amount (e.g. `$ 8.500`) |
| **Price learning** | Saving a NEW expense whose amount differs from the category default → `AlertDialog` "¿Actualizar valor por defecto?": **Solo esta vez** (normal save) / **Actualizar** (saves the expense + `PUT /api/categories/{id}` in the background). If dismissed, saves normally |
| **Description** | Visible only if `category.requires_description == true` |
| **Card on expense** | Franchise icon + color next to the amount if `card_id != null` |
| **Status** | ✅ Complete |

#### 3.3 CategoryFormSheet
| Field | Detail |
|-------|--------|
| **Widget** | `CategoryFormSheet` in `lib/widgets/category_form_sheet.dart` |
| **UX purpose** | Create/edit a category: name, emoji, type (Variable/Fixed), mandatory description, default value, color |
| **Default value (Optional)** | Numeric field (hint `Ej. 8500`, thousands formatter) after the description checkbox. Empty → `0` (no value). Initialized with the existing value when editing. Persisted via `POST/PUT /api/categories` |
| **Status** | ✅ Complete |

#### 3.4 Split expense
| Field | Detail |
|-------|--------|
| **Widget** | Inside `ExpenseFormSheet` — "+ Añadir sub-gasto" button (`LucideIcons.split`) |
| **UX purpose** | Split a total expense into a main amount + N sub-expenses, each with its own category (e.g. a supermarket bill with items from different categories) |
| **Logic** | `principal = total − Σ(sub-expenses)`; if `Σ(sub-expenses) > total` it is marked invalid and saving is blocked (`_splitInvalid`) |
| **Persistence** | Each part (main + subs) is sent as an independent `POST /api/expenses`; all share a `transaction_group_id` (UUID generated client-side with the `uuid` package) |
| **Utilities** | `utils/split_expenses.dart` (main/subtotal calculation, body assembly), `utils/expense_grouping.dart` (`groupConsecutiveExpenses` — visually groups consecutive items with the same `transaction_group_id` in `ExpensesScreen` and `DashboardTab`) |
| **Status** | ✅ Complete |

#### 3.5 Shared expense
| Field | Detail |
|-------|--------|
| **Widgets** | `SharedSplitSection` inside `ExpenseFormSheet`; `SharedScreen` and `PersonDetailScreen` in the Shared tab; `PersonFormSheet`; `PaymentFormSheet` |
| **UX purpose** | Split an expense among local people (roommate, family) and track how much they owe the user. The user pays the full expense and then records the payments received |
| **Form** | "Compartido" toggle in `ExpenseFormSheet`; list of people with editable shares; user's share = `total − Σ(participations)`; equal split by default. **Mutually exclusive** with category split |
| **Persistence** | `POST /api/expenses` with a `shares` array (person_id + amount). The backend creates a single expense and N rows in `expense_shares`. The `/api/people/*` and `/api/shared/summary` endpoints handle people and the summary |
| **Payments** | `POST /api/people/{id}/payments` with amount and date; the backend allocates FIFO to the oldest debts (`payment_allocations`). Supports partial payments. `DELETE /api/payments/{id}` reverses the allocation |
| **Edit rules** | Editing a shared expense recalculates only the outstanding amount; a share cannot be reduced below what has already been paid, and a person with payments cannot be removed |
| **Shared screen** | List of people with total debt; tap opens a detail view with debts (pending/collected/all) and payment history; FAB "+" creates a person; edit/archive/unarchive actions |
| **Expense badge** | Shared expenses show a "Compartido" chip in `ExpensesScreen` |
| **Reports / Dashboard** | Keep the gross expense amount; net cost is shown in the Shared tab and the "Te deben" card |
| **Status** | ✅ Complete |

#### 3.6 Offline mode (capture + complete pending)
| Field | Detail |
|-------|--------|
| **Service** | `OfflineQueueService` in `lib/services/offline_queue_service.dart` (`ChangeNotifier`, persisted in `SharedPreferences`) |
| **Detection** | `utils/connectivity_error.dart` (`isConnectivityError`) distinguishes timeout/`SocketException`/`http.ClientException`/`FirebaseAuthException` with code `network-request-failed` (expired token with no network: the SDK fails fast instead of hanging; #99) (no connection) from a real server error (4xx/5xx) |
| **Offline capture** | If `ExpenseFormSheet` cannot load categories for lack of connection (and is not completing a pending expense), it shows a reduced form: only **amount + date + description** (no category/card/split, because categories come from the server). It is saved locally with `local_id` (uuid) and makes no network attempt |
| **Complete pending** | When the connection returns, the banner button on Home (only visible with a connection, #99) opens `PendingExpensesSheet` → "Completar" reopens `ExpenseFormSheet(pendingToComplete: ...)` with amount/date/description pre-filled; there the user picks category/payment method and can use split. On a successful save it is removed from the queue |
| **Home banner** | `DashboardTab` shows a `Card` with "Tienes N gasto(s) pendiente(s) de completar" when `offlineQueue.pending` is not empty. **With a connection** (or if the load error is not network-related) it includes the "Completar" button that opens `PendingExpensesSheet`. **Without a connection** (`_loadData` failed due to connectivity, flag `_offline`) there is no button —completing requires categories/payment methods from the server—: the card lists the pending items read-only (`PendingExpenseTile`: amount · date · description) with the notice "Podrás completarlo(s) cuando vuelva la conexión". On retry and reconnection the button returns (#99) |
| **Tab gating** | The Expenses/Reports/Profile tabs are disabled (dimmed, no navigation) only while the app has never completed a successful data load **and** is also offline right now (`!hasEverLoadedData && !_serverConnected`) — so a new user with internet can still open those screens for the first time (that first successful load is exactly what sets `hasEverLoadedData` to `true`) |
| **Dashboard offline** | If `_loadData()` fails due to connectivity, `DashboardTab` shows the card "No hay conexión para cargar el resumen" + a retry button (instead of the misleading "No tienes gastos" empty state). Uses `isConnectivityError` in the catch |
| **Discard pending (#101)** | Each pending item has a trash icon ("Descartar") —in `PendingExpensesSheet` next to "Completar" and in the offline read-only list—. It asks for confirmation (bottom sheet: "¿Descartar este gasto pendiente?", red **DESCARTAR** / **CANCELAR** button) and, on confirm, removes it from the local queue (`removePending`). It makes no server call, so it works offline. Discarding the last one hides the banner |
| **Scope** | Only **creating** expenses works offline; editing/deleting and attaching receipts (which require backend AI) still need a connection |
| **Banner layout (#81)** | The banner's "Completar" button (and that of each row in `PendingExpensesSheet`) uses `BudgetTheme.compactFilledButton`. It used to inherit `minimumSize.width = infinity` from the theme inside a `Row`/`ListTile.trailing`, which broke the layout: with pending expenses saved, Home was blank on app launch (with or without a connection) and the banner was not visible. Queue data was never corrupted |
| **Token offline (#81)** | `AuthService.getToken()` has a 10 s timeout (same as `ApiService`). If the token expired and the Firebase SDK cannot refresh it offline, it throws `TimeoutException` (recognized by `isConnectivityError`) instead of hanging: Home leaves the loading state, shows "No hay conexión para cargar el resumen" and the pending banner, and the app stays usable when reopened offline |
| **Status** | ⚠️ Functional but with a known, unresolved rendering bug (#81) |

#### 3.7 Expense presets — #114
| Field | Detail |
|-------|--------|
| **Widget** | `PresetFormSheet` in `lib/widgets/preset_form_sheet.dart` |
| **UX purpose** | Save recurring expenses with predefined values (name, emoji, amount, category, optional payment method and description) so they can be loaded in one tap from the FAB |
| **Where to configure** | **"Plantillas Rápidas"** section in Profile (`ProfileScreen`): horizontal carousel (emoji + name + amount, tap → Modify/Delete) + a "+" button that opens `PresetFormSheet` |
| **Fields** | Name (required), emoji (10 predefined + custom), amount (thousands formatter, `> 0`), category (required), payment method (Cash or card; optional), description (optional) |
| **Persistence** | `POST/GET/PUT/DELETE /api/presets`. The backend validates that `category_id`/`card_id` belong to the user (anti-IDOR) |
| **Quick load** | From the Home FAB, tapping a preset chip (emoji + name) opens `ExpenseFormSheet` with amount, category, payment method and description pre-filled and today's date; autocomplete from the category's `default_amount` is skipped so it does not overwrite the preset amount. The user only confirms/adjusts the payment method and saves |
| **All visible (#122)** | The tray is a horizontal `SingleChildScrollView`: many presets scroll instead of being clipped. And `_loadFabItems()` refetches on open, so presets created/edited in Profile appear without restarting the app |
| **FK fallback** | If the referenced category or card is deleted, the preset keeps the reference as `NULL` (`ON DELETE SET NULL`) — deletion does not break |
| **Empty** | "Sin plantillas" in gray `bodyMedium` |
| **Status** | ✅ Complete |

### 4. Expense List

#### 4.1 ExpensesScreen
| Field | Detail |
|-------|--------|
| **Widget** | `ExpensesScreen` in `lib/screens/expenses_screen.dart` |
| **UX purpose** | Full chronological list with search, filters, pagination and per-expense actions |
| **Components** | `SearchBar` (300ms debounce), `FilterChip` (All/This month/Last month), grouping by relative date, infinite scroll (20 per page), "back to top" FAB |
| **Tap on expense** | Action Sheet (Modify / Delete with confirmation) |
| **Keep alive** | `AutomaticKeepAliveClientMixin` |
| **Status** | ✅ Complete |

### 5. Reports

#### 5.1 ReportsScreen
| Field | Detail |
|-------|--------|
| **Widget** | `ReportsScreen` in `lib/screens/reports_screen.dart` |
| **UX purpose** | KPIs, monthly trend, distribution donut, top categories with drill-down |
| **Components** | `SegmentedButton` (3M/Month/7d), `InsightCard` × 2 (Total + Transactions with Cash/Cards breakdown), `BarChart` (trend with average line), donut `PieChart` (Top 5 + "Others"), `ListTile` (top 8), `SegmentedButton` (All/Fixed/Var. only in Top Expenses) |
| **Monthly trend (#104)** | Payment method legend (`PaymentLegend`): **one entry per method** (deduplicated by label; it used to repeat per month) and with `Wrap`, which wraps instead of overflowing (previously: "RIGHT OVERFLOWED BY 151 PIXELS"). Horizontal grid with ~4 round-step divisions (`trendGridInterval`) and no vertical lines (previously a fixed 200,000 interval → ~40 lines) |
| **Comparison with the previous period (#104)** | `reportRange()` (`lib/utils/report_ranges.dart`) builds the period and the previous one, contiguous and of the same duration. All dates are `yyyy-MM-dd`: the backend silently ignores other formats. Previously, in the **3-month** filter the end of the previous period came out as `2026-06` (no day), was left unbounded, and the "previous" period included the current one → the cards always showed **+0%** |
| **Donut (Distribution by category)** | Consolidated to at most 6 items: Top 5 by amount + "Others" (sum of the rest) with a **dynamic gray** based on theme (light gray in dark mode, dark gray in light mode). No legend overflow |
| **Top expenses** | Fed by `GET /api/stats` with `type=fixed\|variable` (server-side filter by **period + type**); the `SegmentedButton` refetches on change |
| **Card usage** | Horizontal carousel only if there are `_cards` and expenses with `card_id != null` |
| **Drill-down** | Tap a category → ModalBottomSheet with the period's transactions |
| **Empty** | "Sin datos" centered when there is no `_monthlyData` |
| **Status** | ✅ Complete |

### 6. Shared

#### 6.1 SharedScreen
| Field | Detail |
|-------|--------|
| **Widget** | `SharedScreen` in `lib/screens/shared_screen.dart` |
| **UX purpose** | See all local people with outstanding debts and shared totals, and access the detail view |
| **Components** | "Te deben" summary card, people list, "+" FAB to create a person, debt chip per person |
| **Refresh** | `ValueNotifier<int>` shared with other screens |
| **Status** | ✅ Complete |

#### 6.2 PersonDetailScreen
| Field | Detail |
|-------|--------|
| **Widget** | `PersonDetailScreen` in `lib/screens/person_detail_screen.dart` |
| **UX purpose** | View a person's per-expense debts, filter pending/collected/all, record payments and delete them |
| **Components** | Avatar + total owed, "Registrar pago" button, filter `SegmentedButton`, shares list, payment history |
| **Payments** | `PaymentFormSheet` with max amount = total outstanding debt; FIFO allocation in the backend |
| **Status** | ✅ Complete |

### 7. Profile

#### 7.1 ProfileScreen
| Field | Detail |
|-------|--------|
| **Widget** | `ProfileScreen` in `lib/screens/profile_screen.dart` |
| **UX purpose** | Personal dashboard: reactive avatar/display_name, quick presets carousel, cards carousel, category grids by type |
| **Components** | Avatar (emoji/initial/👤), "Plantillas Rápidas" carousel (`_buildPresetCarousel`: emoji + name + amount), `WalletCard` carousel (170×240), `CategoryGrid` × 2 (Variable + Fixed, aspectRatio 3.0), "+" FAB per section |
| **ProfileController** | `ChangeNotifier` — the avatar is reflected in the BottomNavigationBar (Profile tab) |
| **Empty** | "Sin métodos de pago" / "Sin categorías" in gray `bodyMedium` |
| **Status** | ✅ Complete |

### 8. Cards Module

#### 8.1 WalletCard + CardFormSheet
| Field | Detail |
|-------|--------|
| **Widgets** | `WalletCard` in `lib/widgets/wallet_card.dart`, `CardFormSheet` in `lib/widgets/card_form_sheet.dart` |
| **UX purpose** | Manage credit/debit cards: create, edit, delete, and view them as a wallet |
| **Components** | `AspectRatio(1.58)`, gradient, franchise logo (`FaIcon`), `CardFormSheet` (franchise, color, cut-off, payment, limit) |
| **Tap on card** | Action Sheet (Modify / Delete with confirmation) |
| **CRUD** | `POST/GET/PUT/DELETE /api/cards` |
| **Status** | ✅ Complete |

---

## Screen States

### Empty states
| Screen | Condition | Message |
|--------|-----------|---------|
| DashboardTab | No expenses | "No tienes gastos registrados" / "para estas fechas" |
| ReportsScreen | No `_monthlyData` | "Sin datos" |
| ExpensesScreen | Empty list | "No hay gastos registrados" |
| ProfileScreen | No presets | "Sin plantillas" |
| ProfileScreen | No cards | "Sin métodos de pago" |
| ProfileScreen | No categories | "Sin categorías" |

### Loading states
- `AuthGate`: centered `CircularProgressIndicator`
- Data screens: centered `CircularProgressIndicator` while loading
- Forms: disabled button + `CircularProgressIndicator` (14px) inside the button

### Error states
- `LoginScreen`: red error message (`colorScheme.expense`) below the field
- Data screens: `SnackBar` with a message + "Reintentar" action
- Reports: non-null `_error` → red Text on the screen

---

## Applied Design System

| Resource | File |
|----------|------|
| Design tokens | `mobile/design-tokens.json` |
| Flutter theme | `mobile/lib/theme/budget_theme.dart` |
| Style Guide (UI patterns) | `docs/STYLE_GUIDE.md` |
| Icons | `flutter_lucide` (snake_case) + `font_awesome_flutter` (franchises) |
| Charts | `fl_chart` (PieChart, BarChart) |
| Currency | `es_CO` with `intl` → `$ X.XXX` with no decimals |

### Visual consistency checklist
- [x] Colors: only `Theme.of(context).colorScheme` (never `Color(0xFF...)`)
- [x] Icons: `LucideIcons` for UI, `FaIcon` for franchises, emoji String for categories
- [x] Spacing: exclusively `8px` / `16px` / `24px`
- [x] Typography: `headlineLarge` (amounts), `titleMedium` (sections), `bodySmall` (secondary)
- [x] Borders: `16px` on cards, `28px` on bottom sheets, `100px` on buttons
- [x] Empty states: gray centered `bodyMedium` message
- [x] Buttons: `48px` height, `FilledButton` primary, red `TextButton` DELETE
- [x] SegmentedButton: `showSelectedIcon: false` always
- [x] FilterChip: inside a horizontal `SingleChildScrollView`
