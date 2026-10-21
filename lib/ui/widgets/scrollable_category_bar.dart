import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class ScrollableCategoryBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const ScrollableCategoryBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selectedCategory;

          return Material(
            color: isSelected ? AppColors.sunYellow : AppColors.deepSlate,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => onSelected(cat),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.borderDark,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          const BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ]
                      : [
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          )
                        ],
                ),
                alignment: Alignment.center,
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isSelected ? AppColors.pitchBlack : AppColors.pureWhite,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
