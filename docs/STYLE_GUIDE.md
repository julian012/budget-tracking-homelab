# Style Guide — Budget Tracker (Flutter)

> **Last updated**: 2026-08-18
> Authoritative guide to the app's UI patterns, components and visual conventions.

---

## Design Tokens

Defined in `mobile/design-tokens.json` and applied in `mobile/lib/theme/budget_theme.dart`.

### Color Palette (Material Design 3)

| Token | Value | Usage |
|-------|-------|-------|
| `primary` | `#0F52BA` (sapphire blue) | FAB, active navigation, accents, selected SegmentedButton |
| `income` | `#00A86B` (emerald green) | Positive balances, "Transacciones" card, ↓ trend |
| `expense` | `#E53935` (red) | Expenses, alerts, ↑ trend, DELETE button |
| `surface` | `#F8F9FA` | Global app background (`scaffoldBackgroundColor`) |
| `cardSurface` | `#FFFFFF` | Card and input backgrounds |
| `textSecondary` | `#73777F` (gray) | Dates, subtitles, secondary labels |

> **Rule**: NEVER use hardcoded `Color(0xFF...)`. Always `Theme.of(context).colorScheme` or `BudgetColors.income/expense`.

> **Dynamic colors from the API** (categories/cards bring hex as a string): **always** parse with `parseHexColor()` from `utils/color_utils.dart` — never reimplement parsing locally (there were 7 duplicated copies; consolidated in #53). It is robust to malformed hex (returns `fallback` instead of crashing) and composes with `adaptCategoryColor()` for dark mode. The default fallback is `Colors.grey`; pass `fallback:` explicitly when the design calls for another color (e.g. `WalletCard` uses `Colors.grey.shade800`).

> **Spacing rule**: every layout `EdgeInsets`/`SizedBox` must be a multiple of the scale (`spacing8/16/24`). No loose `5`, `6`, `12`, `14` (normalized in #53).

### Typography (TextTheme)

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| `headlineLarge` | 32px | Bold | Large amounts (Dashboard total, Reports KPIs) |
| `headlineMedium` | 28px | Bold | Screen titles (implicit) |
| `titleLarge` | 20px | SemiBold (w600) | Section titles ("Tendencia mensual", "Mayores gastos") |
| `titleMedium` | 16px | Medium (w500) | Values inside cards, card names |
| `bodyLarge` | 16px | Regular (w400) | Main form text |
| `bodyMedium` | 14px | Regular | Labels, secondary text (gray) |
| `bodySmall` | 12px | Regular | Dates, list subtitles, footnote (gray) |
| `labelLarge` | 14px | Medium (w500) | Category names in lists |

### Spacing

| Name | Value | Usage |
|------|-------|-------|
| `spacing8` | 8px | Minimum separation (chips, icons) |
| `spacing16` | 16px | Card padding, separation between sections |
| `spacing24` | 24px | General screen padding (SingleChildScrollView) |
| `cardPadding` | 16px | Internal `Card` padding |

### Border Radius

| Name | Value | Usage |
|------|-------|-------|
| `borderRadiusSmall` | 8px | Chips, tags |
| `borderRadiusMedium` | 16px | Cards, inputs, WalletCard |
| `borderRadiusLarge` | 28px | Top of `ModalBottomSheet` |
| `borderRadiusPill` | 100px | Buttons (`FilledButton`, `OutlinedButton`) |

---

## Atomic Components

### Buttons

```dart
// Primary action
FilledButton(onPressed: ..., child: Text('Guardar'))
// → height: 48px, full-width, pill (borderRadiusPill)

// Secondary action
OutlinedButton(onPressed: ..., child: Text('Cancelar'))
// → height: 48px, full-width, pill

// Destructive action (delete)
TextButton(
  onPressed: ...,
  child: Text('ELIMINAR', style: TextStyle(color: colorScheme.expense)),
)
// → inside action sheets, no fixed height
```

> **Buttons in `Row` / `ListTile.trailing`:** the theme forces `minimumSize: Size(double.infinity, 48)` on `FilledButton`/`OutlinedButton`. If the button is not inside a width-constrained container (a `Column`, a `SizedBox`), the layout breaks and **the whole screen is left unpainted** (#81). In those cases use the compact style (40px, width per content):
>
> ```dart
> FilledButton(style: BudgetTheme.compactFilledButton, onPressed: ..., child: Text('Completar'))
> ```
>
> Tests covering these widgets must mount `MaterialApp(theme: BudgetTheme.light/dark)`; with Flutter's default theme the bug does not reproduce.

### Cards

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(BudgetTheme.cardPadding), // 16px
    child: ...
  ),
)
// → elevation: 1, borderRadius: 16px, white background, margin: 0
```

### FilterChip

```dart
FilterChip(
  label: Text('7 días', style: const TextStyle(fontSize: 12)),
  selected: selected,
  onSelected: (_) { ... },
  selectedColor: colorScheme.primary.withAlpha(40),   // 40/255 = ~16% opacity
  checkmarkColor: colorScheme.primary,
)
```

**Layout:** `SingleChildScrollView(scrollDirection: Axis.horizontal) > Row > FilterChip[] + ActionChip`

### Chip (status badges)

```dart
Chip(
  visualDensity: VisualDensity.compact,
  label: Text('Compartido', style: TextStyle(fontSize: 10)),
  backgroundColor: colorScheme.primary.withAlpha(40),
  side: BorderSide.none,
  padding: EdgeInsets.zero,
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
)
```

**Usage:** indicate status in list rows (e.g. "Compartido" on expenses, "Debe"/"Cobrado" on shares). Always compact (`visualDensity: compact`, 10–12 px font, no border) and with a semantic color: `primary` for generic/informational, `income` for a collected balance, `expense` for an outstanding debt.

### SegmentedButton

```dart
SegmentedButton<String>(
  showSelectedIcon: false,   // ALWAYS false (no checkmark)
  segments: const [
    ButtonSegment(value: 'all', label: Text('Todos', style: TextStyle(fontSize: 11))),
    ButtonSegment(value: 'fixed', label: Text('Fijos', style: TextStyle(fontSize: 11))),
  ],
  selected: {selectedValue},
  onSelectionChanged: (v) => setState(() => selectedValue = v.first),
  style: ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(36, 28))),
)
```

**Usage:** type filter (All/Fixed/Var.), period selector (3M/Month/7d), view selector (By Category/By Method).

---

## Composite Components

### ModalBottomSheet (Forms)

**Pattern used by the 5 FormSheets** (`ExpenseFormSheet`, `CategoryFormSheet`, `CardFormSheet`, `PresetFormSheet`, `ProfileEditSheet`) — a plain `SingleChildScrollView`, no `DraggableScrollableSheet`:

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,                    // ALWAYS
  useSafeArea: true,                            // ALWAYS
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(ctx).viewInsets.bottom,  // keyboard
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(...),
    ),
  ),
)
```

**Applied in:** `ExpenseFormSheet`, `CategoryFormSheet`, `CardFormSheet`, `PresetFormSheet`, `ProfileEditSheet`.

**Exception — Reports drill-down:** the per-category transactions bottom sheet in `ReportsScreen` does use `DraggableScrollableSheet` (it is not a form, it is variable-height content):

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.7,
    builder: (ctx, scrollController) => ListView(
      controller: scrollController,
      children: [...],
    ),
  ),
)
```

### InsightCard (Reports KPIs)

```dart
_InsightCard(
  theme: theme,
  label: 'Total',
  value: _formatCurrency(total),  // formatted string
  prev: prevTotal,                // previous period value (comparison)
  color: colorScheme.primary,     // number color
  subtitle: _buildPaymentBreakdown(),  // optional: small gray breakdown
)
```

**Layout:** `Row > [Expanded(Card) + SizedBox(12) + Expanded(Card)]`
- Large bold number in color
- Optional gray subtitle in `bodySmall` (11px)
- Trend line: `trending_up/down` icon + percentage + "vs período anterior"

### WalletCard (Wallet Card)

```dart
WalletCard(
  card: card,                             // name, franchise, color, cutOffDay, paymentDay
  onTap: () => _showCardActions(card),    // → Modify / Delete
)
```

**Internal layout:**
- `AspectRatio: 1.58` (bank card ratio)
- `Decoration`: gradient of the base color (`color → color withOpacity(0.6)`)
- `BorderRadius.circular(16)`
- Franchise logo: bottom-left, about 1/4 of the height, `FaIcon`
- Card name: `titleMedium`
- Cut-off/payment days: `bodySmall`, gray

**Carousel:** `SizedBox(height: 170) > ListView.builder(scrollDirection: horizontal, itemExtent: 240, padding: left 24)`

### CategoryCard / CategoryGrid

**Individual category (in lists):**
```dart
ListTile(
  dense: true,
  contentPadding: EdgeInsets.zero,
  leading: categoryIconWidget(icon, size: 18, color: catColor),
  title: Text(name, style: theme.textTheme.labelLarge),
  subtitle: Text('total · N transacciones', style: theme.textTheme.bodySmall),
  trailing: Container(width: 12, height: 12, decoration: BoxDecoration(shape: circle, color: catColor)),
)
```

**Grid (in profile):**
```dart
GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 3.0,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
  ),
)
```
- Background at 10% opacity of the category color (`catColor.withAlpha(26)`)
- No border (`border: Border.all(color: Colors.transparent)`)
- Emoji + name + total in a single compact line

### Action Sheets (Modify/Delete)

```dart
showModalBottomSheet(
  context: context,
  builder: (ctx) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(LucideIcons.pencil),
          title: Text('Modificar'),
          onTap: () { Navigator.pop(ctx); _edit(); },
        ),
        ListTile(
          leading: Icon(LucideIcons.trash2, color: colorScheme.expense),
          title: Text('Eliminar', style: TextStyle(color: colorScheme.expense)),
          onTap: () { Navigator.pop(ctx); _delete(); },
        ),
      ],
    ),
  ),
)
```

### FAB Quick Add (Speed Dial)

The expandable FAB is a `Column` (`end`-aligned) that, besides the main action, shows —from top to bottom— the **chip tray** and the main actions:

```
FAB (+)
├── _buildFabTray([...])   ← horizontal SingleChildScrollView (reverse, width = screen - 32)
│     └── _FabChip × N      emoji + name (Tooltip), Material surface elevation 2
├── _MiniFab(Foto)          icon + label to its left
├── _MiniFab(Audio)
└── _MiniFab(Formulario)
```

- The user's **Quick Presets**; if there are none, it falls back to the most recent categories (same `_FabChip`). `_loadFabItems()` **refetches on open** (no stale cache, #122).
- The chip uses `BudgetTheme.borderRadiusMedium`, `padding` 16×14, `minWidth: 96` and `categoryIconWidget(icon, size: 22, color)` + `Text` with `maxWidth: 120` and ellipsis → comfortable touch area with context (previously: 40px circular mini-FAB, emoji only).
- The tray scrolls so nothing is clipped when there are many presets.
- Tapping a preset chip opens a pre-filled `ExpenseFormSheet(preset: ...)`.

```dart
FloatingActionButton(
  onPressed: () { _fabOpen = !_fabOpen; if (_fabOpen) _loadFabItems(); },
  child: Icon(_fabOpen ? LucideIcons.x : LucideIcons.plus),
)
```

> **Controllers in bottom sheets:** a sheet's `TextEditingController` must live in the sheet's `State` and be disposed in `dispose()`. Do **not** use `showModalBottomSheet(...).whenComplete(ctrl.dispose)`: that Future completes on `Navigator.pop`, with the sheet still animating and the keyboard closing, and the `TextField` rebuilds with a disposed controller (red `_dependents.isEmpty` screen, #87).

---

## Screen Patterns

### DashboardTab (HomeScreen)

```
SingleChildScrollView
├── _buildFilters          ← horizontal FilterChip (7d/15d/Month/Previous/Custom)
├── _buildSummary          ← Card: large total + previous period comparison
├── _buildCategories       ← PieChart toggle (By Category / By Method)
├── _buildRecentExpenses   ← ListView: last N expenses with category icon + emoji + date
└── FAB Quick Add          ← Create expense quickly
```

**Empty:** Text "Empieza registrando tu primer gasto" in gray `bodyMedium`, centered.

### ReportsScreen

```
SingleChildScrollView
├── SegmentedButton          ← Period (3M/Month/7d) right-aligned
├── Row: InsightCard × 2    ← Total + Transactions (with Cash/Cards breakdown)
├── "Tendencia mensual"     ← BarChart with average line (orange, dashed)
│                            horizontal grid ~4 lines (`trendGridInterval`, no verticals) and
│                            payment legend `PaymentLegend` (Wrap, one entry per method)
├── "Distribución por categoría" ← consolidated donut PieChart: Top 5 + "Others"
│                                (max 6 items; "Others" with dynamic gray based on theme)
├── "Uso de Tarjetas"       ← horizontal carousel (conditional: only if cards + expenses with card)
├── "Mayores gastos" + type ← SegmentedButton (All/Fixed/Var.) — server-side filter
│                            via GET /api/stats?type=fixed|variable (period + type)
└── Drill-down: tap a category → bottom sheet with the period's transactions
```

**Empty:** "Sin datos" in centered `bodyMedium` when `_monthlyData` is null/empty.

**"Others" donut:** dynamic gray based on theme — `Colors.grey.shade700` in light mode, `Colors.grey.shade300` in dark mode. Never a hardcoded static gray.

### ExpenseFormSheet (autofill + learning pattern)

```
When selecting a category (or opening with the first one selected):
  if default_amount > 0 → _amountCtrl.text = formatAmountInput(default)

When saving a NEW expense with amount ≠ the category's default_amount:
  AlertDialog "¿Actualizar valor por defecto?"
    ├─ "Solo esta vez" → saves the expense normally
    └─ "Actualizar"    → saves the expense + PUT /api/categories/{id} in the background
  (if the dialog is dismissed → normal save)
```

**"Valor por defecto (Opcional)" field** in `CategoryFormSheet`: numeric `TextField` with `ThousandsFormatter`, hint `Ej. 8500`; empty → `0`. Initialized with `default_amount` when editing.

### ExpensesScreen

```
ExpandedListView
├── SearchBar (300ms debounce)
├── horizontal FilterChip (All/This month/Last month)
├── Grouping by relative date (Today/Yesterday/This week/dd MMM)
├── Infinite scroll (20 per page)
└── "back to top" FAB (offset > 300px)
```

**Tap on expense:** Action Sheet (Modify / Delete with red confirmation).

**Discard pending expense (offline):** `LucideIcons.trash_2` icon in `colorScheme.expense` with tooltip "Descartar" (`PendingDiscardButton`); confirms with the same bottom sheet as delete (title, notice "No se enviará al servidor…", red `DESCARTAR` button + `CANCELAR` `TextButton`).

### ProfileScreen

```
SingleChildScrollView
├── Avatar (emoji + display_name + email) + "Editar Perfil"
├── "Plantillas Rápidas" → carousel (emoji + name + amount) + "+" IconButton (PresetFormSheet)
├── "Métodos de Pago" → WalletCard horizontal carousel + "+"
├── "Gastos Variables" → CategoryGrid (2 cols, aspectRatio 3.0) + "+" FAB (defaultType: variable)
└── "Gastos Fijos" → CategoryGrid + "+" FAB (defaultType: fixed)
```

**Empty:** "Sin plantillas" / "Sin tarjetas" / "Sin categorías" message in gray `bodyMedium`.

---

## Currency Format

```dart
String _formatCurrency(double amount) => NumberFormat.currency(
  locale: 'es_CO',
  symbol: '\$',
  decimalDigits: 0,
).format(amount);
// → "$ 1.500" (Colombian peso, thousands separated by dots, no decimals)
```

**Short format (charts):**
```dart
String _formatCurrencyShort(double amount) {
  if (amount >= 1000000) return '\$ ${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return '\$ ${(amount / 1000).toStringAsFixed(0)}K';
  return '\$ ${amount.toInt()}';
}
```

---

## Iconography

| Library | Usage |
|---------|-------|
| `flutter_lucide` (`LucideIcons`) | General UI icons (plus, trash2, trending_up, calendar, etc.) |
| `font_awesome_flutter` (`FaIcon`) | Franchise logos (Visa, Mastercard, Amex, Diners) |
| Emoji (String) | Categories (😋, 🚌, 🎬, etc.) and profile avatar |

**Shared helper:** `icon_helper.dart`
- `categoryIconWidget(icon, size, color)` → renders an emoji or a `LucideIcons` icon
- `franchiseIconWidget(franchise)` → `FaIcon` with each franchise's corporate color

---

## State Management

| Mechanism | Usage |
|-----------|-------|
| `Provider` (`ChangeNotifierProvider`) | `ServerConfig`, `AuthService`, `ProfileController` |
| `ValueNotifier<int>` | Refresh tabs on create/edit/delete (Home → Expenses) |
| `AutomaticKeepAliveClientMixin` | Preserve tab state when switching between tabs |
| `StatefulWidget.setState` | Local state of each screen (filters, loaded data) |
| `NavigatorObserver` (`RouteAware`) | Track the active screen to refresh data |

---

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Screens | `*Screen` (StatefulWidget) | `ReportsScreen`, `ExpensesScreen` |
| Reusable widgets | `*Widget` or a descriptive noun | `WalletCard`, `CategoryGrid` |
| Sheets (forms) | `*FormSheet` | `ExpenseFormSheet`, `CategoryFormSheet` |
| Controllers | `*Controller` (ChangeNotifier) | `ProfileController` |
| Services | `*Service` | `ApiService`, `AuthService` |
| Utilities | lower_snake_case | `currency_formatter.dart`, `icon_helper.dart` |
| Private methods | `_` prefix | `_loadData()`, `_buildFilters()` |
