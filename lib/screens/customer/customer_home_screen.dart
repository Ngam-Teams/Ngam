import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../widgets/bottom_nav_customer.dart';
import '../../widgets/customer_desktop_sidebar.dart';
import 'customer_home_feed_view.dart';
import 'customer_feed_screen.dart';
import '../explore/explore_view.dart';
import '../shared/chat_screen.dart';
import '../shared/profile_screen.dart';
import '../../services/app_update_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  
  // Array untuk menyimpan status pemuatan setiap tab (5 tabs)
  final List<bool> _initializedPages = [true, false, false, false, false];

  @override
  void initState() {
    super.initState();
    // Buang splash screen lepas frame pertama di-render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          AppUpdateService.checkOnStartup(context);
        }
      });
    });
  }

  void _onTabTapped(int index) {
    BottomNavCustomer.isVisible.value = true;
    setState(() {
      _currentIndex = index;
      _initializedPages[index] = true;
    });
  }

  /// Memastikan laman selain peta mempunyai anjakan (offset) mengikut kelebaran sidebar desktop
  Widget _buildDesktopPaddedPage(int index, Widget page) {
    return ValueListenableBuilder<bool>(
      valueListenable: CustomerDesktopSidebar.isExpandedNotifier,
      builder: (context, isExpanded, _) {
        final double sidebarWidth = isExpanded ? 276.0 : 88.0;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.only(left: sidebarWidth),
          child: page,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _initializedPages[0] ? CustomerHomeFeedView(onSwitchTab: _onTabTapped) : const SizedBox.shrink(),
      _initializedPages[1] ? const ExploreView() : const SizedBox.shrink(),
      _currentIndex == 2 ? CustomerFeedScreen(onSwitchTab: _onTabTapped, isTabActive: true) : const SizedBox.shrink(),
      _initializedPages[3] ? const ChatScreen() : const SizedBox.shrink(),
      _initializedPages[4] ? const ProfileScreen() : const SizedBox.shrink(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8F9FA);
    final iconBrightness = isDark ? Brightness.light : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: navBg,
        systemNavigationBarIconBrightness: iconBrightness,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        // Desktop / Landscape Layout (≥800px): Collapsible Modern Glass Sidebar
        if (isDesktop) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8F9FA),
            resizeToAvoidBottomInset: false,
            body: Stack(
              children: [
                // 1. Full-screen Content Pages
                Positioned.fill(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      // Tab 0: Laman Utama (Home Feed)
                      _buildDesktopPaddedPage(0, pages[0]),
                      // Tab 1: Terokai Peta (ExploreView) — FULL BLEED EDGE-TO-EDGE UNDER FLOATING SIDEBAR!
                      pages[1],
                      // Tab 2: Ngam Feed (Reels) — FULL BLEED EDGE-TO-EDGE UNDER FLOATING SIDEBAR!
                      pages[2],
                      // Tab 3: Mesej (Chat)
                      _buildDesktopPaddedPage(3, pages[3]),
                      // Tab 4: Profil Saya (Profile)
                      _buildDesktopPaddedPage(4, pages[4]),
                    ],
                  ),
                ),

                // Ambient Aurora Glow behind the glass sidebar for authentic refraction (only when NOT on map or feed)
                if (isDark && _currentIndex != 1 && _currentIndex != 2) ...[
                  Positioned(
                    top: -60,
                    left: -60,
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF2196F3).withValues(alpha: 0.22),
                            const Color(0xFF2196F3).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: -30,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6366F1).withValues(alpha: 0.18),
                            const Color(0xFF6366F1).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // 2. Floating Glassmorphic Sidebar (Floats right on top of the edge-to-edge map!)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: SafeArea(
                    bottom: false,
                    child: CustomerDesktopSidebar(
                      selectedIndex: _currentIndex,
                      onNavTap: _onTabTapped,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Layout (<800px): Floating BottomNavCustomer
        return Scaffold(
          backgroundColor: navBg,
          extendBody: true,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: BottomNavCustomer.isVisible,
                builder: (context, isVisible, child) {
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    left: 0,
                    right: 0,
                    bottom: isVisible ? 0 : -120,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isVisible ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !isVisible,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 540),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: BottomNavCustomer(
                  currentIndex: _currentIndex,
                  onTap: _onTabTapped,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
}
