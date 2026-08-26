import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../widgets/bottom_nav_customer.dart';
import '../explore/explore_view.dart';
import '../explore/my_rezrv_view.dart';
import '../shared/chat_screen.dart';
import '../shared/profile_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;
  
  // Array untuk menyimpan status pemuatan setiap tab
  final List<bool> _initializedPages = [true, false, false, false];

  @override
  void initState() {
    super.initState();
    // Buang splash screen lepas frame pertama di-render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _initializedPages[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _initializedPages[0] ? const ExploreView() : const SizedBox.shrink(),
      _initializedPages[1] ? const MyRezrvView() : const SizedBox.shrink(),
      _initializedPages[2] ? const ChatScreen() : const SizedBox.shrink(),
      _initializedPages[3] ? const ProfileScreen() : const SizedBox.shrink(),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavCustomer(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
}
