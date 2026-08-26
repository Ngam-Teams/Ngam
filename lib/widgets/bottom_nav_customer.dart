import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'custom_bottom_nav.dart';

// ============================================================
// Ngam App — Menu Bawah (Customer)
// Home, Bookings, Inbox, Profile
// ============================================================

class BottomNavCustomer extends StatelessWidget {
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
          title: 'Home',
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedTicket01,
          title: 'Bookings',
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedMessage02,
          title: 'Inbox',
        ),
        NavItem(
          icon: HugeIcons.strokeRoundedUser,
          title: 'Profile',
        ),
      ],
    );
  }
}
