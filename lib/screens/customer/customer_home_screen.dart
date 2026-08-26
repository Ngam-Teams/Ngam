import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../widgets/bottom_nav_customer.dart';
import '../rezrv/explore_view.dart';
import '../rezrv/my_rezrv_view.dart';
import '../shared/chat_screen.dart';
import '../shared/profile_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 0: HOME (Explore / Peta REZRV)
          const ExploreView(),
          
          // 1: BOOKINGS (My REZRV)
          const MyRezrvView(),
          
          // 2: INBOX (Chat)
          const ChatScreen(),
          
          // 3: PROFILE
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavCustomer(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
