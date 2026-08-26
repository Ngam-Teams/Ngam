import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'bookings_view.dart'; // 🟢 Make sure this points to your Bookings checkout screen!
import '../../widgets/glass_toast.dart';
import '../auth/login_screen.dart'; // Make sure this matches your Auth Screen file name!

class ShopDetailScreen extends StatelessWidget {
  final Map<String, dynamic> shop;

  const ShopDetailScreen({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String shopName = shop["name"] ?? "Unknown Shop";
    final String category = shop["category"]?.toString().toUpperCase() ?? "SERVICE";
    final String rating = shop["rating"]?.toString() ?? "0.0";
    final String reviews = shop["reviews"]?.toString() ?? "0";
    final String imgUrl = shop["image"] ?? "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400";
    final List<dynamic>? serviceList = shop["services"];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13171B) : const Color(0xFFE5ECF1),
      body: Stack(
        children: [
          // --- 1. HERO BACKGROUND IMAGE ---
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(imgUrl, fit: BoxFit.cover),
                // Gradient fade to blend image into the background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        isDark ? const Color(0xFF13171B) : const Color(0xFFE5ECF1),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 2. MAIN SCROLLABLE CONTENT ---
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: _buildGlassIconButton(Icons.arrow_back_ios_new_rounded, context, isDark),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: _buildGlassIconButton(Icons.favorite_border_rounded, context, isDark),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).size.height * 0.15,
                      left: 20, right: 20, bottom: 120, // Space for bottom button
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🟢 MAIN INFO GLASS CARD
                        _buildGlassCard(
                          isDark: isDark,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(category, style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(rating, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
                                      Text(" ($reviews)", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(shopName, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  HugeIcon(icon: HugeIcons.strokeRoundedLocation01, color: isDark ? Colors.white54 : Colors.black54, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text("123 Main Street, City Center", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  HugeIcon(icon: HugeIcons.strokeRoundedTime02, color: isDark ? Colors.white54 : Colors.black54, size: 18),
                                  const SizedBox(width: 8),
                                  Text("Open Now • Closes at 10:00 PM", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Text("About", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(
                          "Experience premium grooming and wellness services in a relaxing environment. Our professionals are dedicated to making you look and feel your absolute best.",
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 15, height: 1.5),
                        ),

                        const SizedBox(height: 24),
                        Text("Services Available", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        // 🟢 SERVICES TAGS
                        if (serviceList != null)
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: serviceList.map((service) => _buildGlassCard(
                              isDark: isDark,
                              radius: 12,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Text(service.toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                            )).toList(),
                          )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 3. STICKY BOTTOM BUTTON ---
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    isDark ? const Color(0xFF13171B) : const Color(0xFFE5ECF1),
                    (isDark ? const Color(0xFF13171B) : const Color(0xFFE5ECF1)).withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  // 🟢 THE AUTH GUARD LOGIC
                  if (Supabase.instance.client.auth.currentUser != null) {
                    // ✅ USER IS LOGGED IN: Proceed to checkout!
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingsView(
                          shopId: shop["id"].toString(),
                          shopName: shopName,
                          category: category,
                          shopImage: imgUrl,
                        ),
                      ),
                    );
                  } else {
                    // ❌ USER IS GUEST: Block them and send to Auth Screen
                    showGlassToast(
                        context,
                        "Please sign in or register to make a reservation.",
                        isError: true
                    );

                    Navigator.pushNamed(context, '/login');
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Center(
                    child: Text("Book Now", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildGlassIconButton(IconData icon, BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
              border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.5), width: 1.5),
            ),
            child: Icon(icon, color: isDark ? Colors.white : Colors.black87, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required bool isDark, required Widget child, EdgeInsetsGeometry? padding, double radius = 24}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.6), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: child,
        ),
      ),
    );
  }
}