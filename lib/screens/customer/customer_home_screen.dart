import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _initializedPages[0] ? CustomerHomeFeedView(onSwitchTab: _onTabTapped) : const SizedBox.shrink(),
      _initializedPages[1] ? const ExploreView() : const SizedBox.shrink(),
      _currentIndex == 2 ? CustomerFeedScreen(onSwitchTab: _onTabTapped, isTabActive: true) : const SizedBox.shrink(),
      _initializedPages[3] ? const ChatScreen() : const SizedBox.shrink(),
      _initializedPages[4] ? const ProfileScreen() : const SizedBox.shrink(),
    ];

    return LayoutBuilder(
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
                // Ambient Aurora Glow behind the glass sidebar for authentic refraction
                if (isDark) ...[
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
                SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      CustomerDesktopSidebar(
                        selectedIndex: _currentIndex,
                        onNavTap: _onTabTapped,
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: pages,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Layout (<800px): Floating BottomNavCustomer
        return Scaffold(
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
    );
  }
}
