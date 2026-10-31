### UI/UX RULES FOR FLUTTER (FINANCE APP)

1. DESIGN SYSTEM:
   - Use Material Design 3 strictly (`useMaterial3: true`).
   - All colors must come from `Theme.of(context).colorScheme` (avoid hardcoded Color(0xFF...)).
   - Use native Flutter components: `Card`, `ListTile`, `ModalBottomSheet`, `NavigationBar`, `SegmentedButton`.

2. NAVIGATION AND FLOW UX:
   - Expense entry MUST open via a `showModalBottomSheet` from the main FAB.
   - The entry form must be minimalist: large Amount field (autofocus), category selector with an icon Grid (`CircleAvatar`), and a date defaulting to DateTime.now().

3. DATA VISUALIZATION:
   - Use the `fl_chart` package for all visual reports.
   - Every numeric amount must be formatted with a currency symbol and thousands separators.
   - Expenses should use reddish/warm tones and income green/cool tones, using the Theme variables.

4. SPACING AND TYPOGRAPHY:
   - Use only padding/margins from the 8px scale (8, 16, 24).
   - Typography based on `Theme.of(context).textTheme` (e.g., `headlineMedium` for main amounts, `bodyMedium` for details).

5. ICONOGRAPHY:
   - Use the `flutter_lucide` package exclusively for all icons (do NOT use Material `Icons.` or `CupertinoIcons.`).
   - Category icons: inside a `CircleAvatar` with a background at 12% opacity of the category color, 24dp size.
   - Action icons: 20dp size, color according to context (`text_primary` or `primary`).
   - Empty states: always show an SVG illustration from `assets/illustrations/`, max height 180dp.
