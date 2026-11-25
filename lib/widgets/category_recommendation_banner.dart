import 'package:flutter/material.dart';

import '../domain/suggest_food_category.dart';

/// Displays an offline, 1-tap category recommendation banner when the food name
/// strongly matches a different category than the currently selected one.
class CategoryRecommendationBanner extends StatelessWidget {
  const CategoryRecommendationBanner({
    super.key,
    required this.foodName,
    required this.selectedCategory,
    required this.enabled,
    required this.onApply,
  });

  final String foodName;
  final String selectedCategory;
  final bool enabled;
  final ValueChanged<String> onApply;

  @override
  Widget build(BuildContext context) {
    final suggested = suggestFoodCategory(foodName);
    final warning = categoryMismatchWarning(foodName, selectedCategory);
    if (suggested == null || warning == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warning,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: enabled ? () => onApply(suggested) : null,
              child: Text('Use $suggested'),
            ),
          ),
        ],
      ),
    );
  }
}
