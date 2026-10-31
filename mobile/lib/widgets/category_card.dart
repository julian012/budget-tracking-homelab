import 'package:flutter/material.dart';
import '../utils/color_utils.dart';
import '../utils/icon_helper.dart';

class CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback onTap;

  const CategoryCard({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = adaptCategoryColor(
      parseHexColor(category['color']?.toString()),
      context,
    );
    final name = category['name'] as String? ?? '';
    return Card(
      color: color.withValues(alpha: 0.10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            categoryIconWidget(category['icon']?.toString(), size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              name,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryGrid extends StatelessWidget {
  final List<dynamic> categories;
  final Widget Function(Map<String, dynamic>) cardBuilder;

  const CategoryGrid({super.key, required this.categories, required this.cardBuilder});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3.0,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) => cardBuilder(categories[i] as Map<String, dynamic>),
    );
  }
}

class EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptySection({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
