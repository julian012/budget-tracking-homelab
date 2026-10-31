---
name: flutter-consistency-check
description: Consistency checklist for Flutter/Dart changes — theme colors, ModalBottomSheet pattern, controller disposal, error feedback. Use before finishing any change to mobile/lib/.
---

## When to use

Before finishing any change in `mobile/lib/`, or when resolving a `layer:mobile` issue about visual or state consistency.

## Checklist

### Theming
- [ ] No hardcoded `Color(0xFF...)` or `Colors.red`/`Colors.green` — always `Theme.of(context).colorScheme` (`.income`/`.expense` for positive/negative, see `docs/STYLE_GUIDE.md`).
- [ ] Hex color parsing reuses `utils/color_utils.dart` — do not reimplement a local `_hexColor`/`_parseColor` in the widget.
- [ ] Icons exclusively from `flutter_lucide` (`LucideIcons`) or `FaIcon` for franchises — never `Icons.`/`CupertinoIcons.`.
- [ ] Spacing on the 8px scale (8/16/24) — avoid odd values like `5`, `6`, `14`.

### ModalBottomSheet
- [ ] `isScrollControlled: true` and `useSafeArea: true` on **every** `showModalBottomSheet` (see pattern in `docs/STYLE_GUIDE.md`).
- [ ] Forms (`*FormSheet`) use a simple `SingleChildScrollView`; variable-height content (e.g., drill-downs) uses `DraggableScrollableSheet`.

### State and memory
- [ ] Every `TextEditingController`/`ScrollController`/`AnimationController` created outside a `State` field is explicitly disposed when it closes (bottom sheets, dynamic dialogs).
- [ ] Each `StatefulWidget` with its own controllers implements `dispose()`.
- [ ] `setState`/use of `context` after an `await` checks `mounted`/`context.mounted`.

### Network errors
- [ ] Every catch of an API call shows feedback to the user (`SnackBar` with a "Retry" action), never failing silently and leaving an empty list (see `user-flows.md` — Error states).

### Tests
- [ ] Every new widget/screen/util has its `_test.dart` (`AGENTS.md` convention).

## Reference

Checklist derived from the code audit of 2026-08-25 (issues #48-#53). It exists as an identical duplicate in `.opencode/skills/flutter-consistency-check/SKILL.md` and `.claude/skills/flutter-consistency-check/SKILL.md` (previously symlinked from `skills/`, see #64) — if you edit it, replicate the change in both copies.
