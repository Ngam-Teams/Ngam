import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../l10n/generated/app_localizations.dart';
import 'custom_bottom_nav.dart';

// ============================================================
// Ngam App — Menu Bawah (Customer)
// Home, Bookings, Inbox, Profile
// ============================================================

class BottomNavCustomer extends StatelessWidget {
  static final ValueNotifier<bool> isVisible = ValueNotifier<bool>(true);

  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavCustomer({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomBottomNav(
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        NavItem(
          icon: HugeIcons.strokeRoundedHome11,
          title: l10n?.navHome ?? 'Home',
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedMaps,
          title: l10n?.navDiscover ?? 'Discover',
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedPlayCircle02,
          title: l10n?.navFeed ?? 'Feed',
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedMessage02,
          title: l10n?.navInbox ?? 'Inbox',
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedUser,
          title: l10n?.navProfile ?? 'Profile',
        ),
      ],
    );
  }
}
