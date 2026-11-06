import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'custom_bottom_nav.dart';

// ============================================================
// Ngam App — Menu Bawah (Customer)
// Home, Discover, Feed, Inbox, Profile
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
    return CustomBottomNav(
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        NavItem(
          icon: HugeIcons.strokeRoundedHome11,
          title: 'nav.home'.tr(),
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedMaps,
          title: 'nav.discover'.tr(),
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedPlayCircle02,
          title: 'nav.feed'.tr(),
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedMessage02,
          title: 'nav.chat'.tr(),
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedUser,
          title: 'nav.profile'.tr(),
        ),
      ],
    );
  }
}
