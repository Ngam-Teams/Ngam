import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../utils/app_theme.dart';

// ============================================================
// Ngam App — Widget Chip Kategori
// Kotak tag kategori warna-warni yang boleh guna banyak kali
// ============================================================

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showIcon;

  const CategoryChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.showIcon = true,
  });

  /// Get category-specific color
  Color _getCategoryColor() {
    switch (label) {
      case 'Food':
        return const Color(0xFFFF6B35);
      case 'Shopping':
        return const Color(0xFF4ECDC4);
      case 'Print':
        return const Color(0xFF45B7D1);
      case 'Heavy':
        return const Color(0xFFFF8C94);
      case 'Parcel':
        return const Color(0xFFA78BFA);
      case 'Cleaning':
        return const Color(0xFF4FACFE);
      case 'Pet Care':
        return const Color(0xFFFFB347);
      case 'Errands':
        return const Color(0xFF5D9CEC);
      case 'Automotive':
        return const Color(0xFFFC6E51);
      case 'Others':
        return const Color(0xFFCCD1D9);
      case 'All':
        return AppTheme.primary;
      default:
        return Colors.grey;
    }
  }

  /// Get category icon
  List<List<dynamic>> _getCategoryIcon() {
    switch (label) {
      case 'Food':
        return HugeIcons.strokeRoundedHamburger01;
      case 'Shopping':
        return HugeIcons.strokeRoundedShoppingBag01;
      case 'Print':
        return HugeIcons.strokeRoundedPrinter;
      case 'Heavy':
        return HugeIcons.strokeRoundedPackage;
      case 'Parcel':
        return HugeIcons.strokeRoundedDeliveryBox01;
      case 'Cleaning':
        return HugeIcons.strokeRoundedClean;
      case 'Pet Care':
        return HugeIcons.strokeRoundedFavourite;
      case 'Errands':
        return HugeIcons.strokeRoundedUser;
      case 'Automotive':
        return HugeIcons.strokeRoundedCar01;
      case 'Others':
      case 'All':
        return HugeIcons.strokeRoundedSparkles;
      default:
        return HugeIcons.strokeRoundedNote;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Theme.of(context).chipTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              HugeIcon(
                icon: _getCategoryIcon(),
                size: 14,
                color: isSelected
                    ? color
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? color
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
