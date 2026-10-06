import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/auth_provider.dart';

class MyStampCardsScreen extends StatefulWidget {
  const MyStampCardsScreen({super.key});

  @override
  State<MyStampCardsScreen> createState() => _MyStampCardsScreenState();
}

class _MyStampCardsScreenState extends State<MyStampCardsScreen> {
  // Demo cards loaded for customer
  final List<Map<String, dynamic>> _myCards = [
    {
      'shopName': 'Barber King Studio',
      'programTitle': 'Kad Cop Gunting Rambut VIP',
      'totalStamps': 5,
      'currentStamps': 4, // 4/5 stamps!
      'rewardTitle': 'Percuma 1x Gunting Rambut & Cuci',
      'lastStamped': DateTime.now().subtract(const Duration(days: 3)),
      'accentColor': const Color(0xFF6366F1),
    },
    {
      'shopName': 'The Daily Grind Cafe & Bistro',
      'programTitle': 'Cop Kopi & Pastri',
      'totalStamps': 8,
      'currentStamps': 8, // Ready to redeem!
      'rewardTitle': 'Percuma 1x Kopi Pilihan & Croissant',
      'lastStamped': DateTime.now().subtract(const Duration(hours: 12)),
      'accentColor': const Color(0xFF10B981),
    },
    {
      'shopName': 'AutoSpa Carwash & Detailing',
      'programTitle': 'Kad Cop Cuci Kereta Premium',
      'totalStamps': 5,
      'currentStamps': 2,
      'rewardTitle': 'Percuma 1x Cuci Salji & Wax',
      'lastStamped': DateTime.now().subtract(const Duration(days: 14)),
      'accentColor': const Color(0xFFF59E0B),
    },
  ];

  void _showCustomerQrSheet(String phone, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF141424),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.white24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Tunjuk Kepada Juruwang',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Juruwang akan imbas QR ini atau masukkan no telefon untuk beri cop',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: phone.isNotEmpty ? phone : 'NGAM-USER-001',
                  size: 160,
                  version: QrVersions.auto,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                phone.isNotEmpty ? phone : '012-3456789',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF42A5F5),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                name.isNotEmpty ? name : 'Pelanggan Ngam',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthProvider>(context).user;
    final phone = user?.userPhone ?? '012-3456789';
    final name = user?.userName ?? 'Pelanggan Setia';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kad Cop Digital Saya',
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded, color: Color(0xFF42A5F5), size: 26),
            tooltip: 'Tunjuk QR Saya',
            onPressed: () => _showCustomerQrSheet(phone, name),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top ID Card Banner
            _buildPassIdBanner(phone, name),
            const SizedBox(height: 20),

            Text(
              'Kad Cop Aktif (${_myCards.length})',
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            ..._myCards.map((card) => _buildStampCardItem(card, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildPassIdBanner(String phone, String name) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E1B4B)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF67E8F9), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'NGAM LOYALTY PASS',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF67E8F9),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  phone,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showCustomerQrSheet(phone, name),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.black, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStampCardItem(Map<String, dynamic> card, bool isDark) {
    final int total = card['totalStamps'] as int;
    final int current = card['currentStamps'] as int;
    final bool isReady = current >= total;
    final Color accent = card['accentColor'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141424) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isReady ? const Color(0xFF10B981) : (isDark ? Colors.white12 : Colors.black12),
          width: isReady ? 2 : 1,
        ),
        boxShadow: isReady
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card['shopName'] as String,
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      card['programTitle'] as String,
                      style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (isReady)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Text(
                    '🎉 SEDIA DITEBUS',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                )
              else
                Text(
                  '$current / $total Cop',
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Stamp circles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(total, (index) {
              final isStamped = index < current;
              final isRewardSlot = index == total - 1;

              return Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isStamped
                      ? (isRewardSlot ? const Color(0xFFF59E0B) : accent)
                      : (isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF1F5F9)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isStamped ? Colors.white : (isDark ? Colors.white24 : Colors.black12),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: isStamped
                      ? Icon(
                          isRewardSlot ? Icons.card_giftcard_rounded : Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Reward description bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isReady
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  color: isReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isReady
                      ? 'Tahniah! Anda boleh tebus: ${card["rewardTitle"]}'
                      : 'Ganjaran: ${card["rewardTitle"]}',
                    style: TextStyle(
                      color: isReady ? const Color(0xFF10B981) : (isDark ? Colors.white70 : Colors.black87),
                      fontSize: 12,
                      fontWeight: isReady ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
