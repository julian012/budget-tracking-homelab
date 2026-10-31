import 'package:flutter/material.dart';

class FilterChipsBar extends StatelessWidget {
  final List<({String value, String label})> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final Widget? trailing;

  const FilterChipsBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...options.map((option) {
                final isSelected = selected == option.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(option.label, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (_) => onChanged(option.value),
                    selectedColor: colorScheme.primary.withAlpha(40),
                    checkmarkColor: colorScheme.primary,
                  ),
                );
              }),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
