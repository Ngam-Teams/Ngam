import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../utils/glass_toast.dart';
import '../explore/qr_scanner_screen.dart';

// =============================================================================
// MyQueueTicketScreen — Skrin Tiket & Status Giliran Walk-In Langsung (Customer)
// =============================================================================

class MyQueueTicketScreen extends StatefulWidget {
  final Map<String, dynamic>? initialTicket;

  const MyQueueTicketScreen({super.key, this.initialTicket});

  @override
  State<MyQueueTicketScreen> createState() => _MyQueueTicketScreenState();
}

class _MyQueueTicketScreenState extends State<MyQueueTicketScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _activeTicket;
  int _peopleAhead = 1;
  Timer? _refreshTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.initialTicket != null) {
      _activeTicket = Map<String, dynamic>.from(widget.initialTicket!);
      _isLoading = false;
    } else {
      _loadCustomerTicket();
    }

    // Auto check every 10s
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _activeTicket != null) {
        _loadCustomerTicket(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomerTicket({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final phone = user?.userPhone;

      final client = Supabase.instance.client;

      // Try fetching active ticket by phone or user_id for today
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

      dynamic response;
      if (phone != null && phone.isNotEmpty) {
        response = await client
            .from('queue_tickets')
            .select('*, businesses(business_name, business_phone, business_address)')
            .eq('phone_number', phone)
            .inFilter('status', ['waiting', 'calling', 'serving'])
            .gte('created_at', startOfDay)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      if (response != null && mounted) {
        setState(() {
          _activeTicket = Map<String, dynamic>.from(response);
          _calculatePeopleAhead();
          _isLoading = false;
        });
        _setupRealtimeSubscription(_activeTicket!['id'] as String);
        return;
      }

      // Fallback demo ticket if user doesn't have an active walk-in yet
      if (_activeTicket == null && mounted) {
        _activeTicket = {
          'id': 'demo-ticket-001',
          'ticket_number': 'A002',
          'business_id': 'biz-001',
          'business_name': 'Empire Barber & Co. (Bangi Sentral)',
          'business_phone': '+60 12-345 6789',
          'business_address': 'No. 22-A, Jalan Medan Pusat 2D, Bandar Baru Bangi',
          'customer_name': user?.userName ?? 'Pelanggan Setia',
          'service_name': 'Classic Gentleman Haircut & Hot Towel',
          'price': 35.00,
          'status': 'calling', // 'waiting' | 'calling' | 'serving' | 'completed'
          'station_or_chair': 'Kerusi 2',
          'assigned_staff_name': 'Barber Hafiz',
          'estimated_wait_minutes': 5,
          'created_at': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
          'called_at': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
        };
        _peopleAhead = 1;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculatePeopleAhead() {
    final status = _activeTicket?['status'] as String?;
    if (status == 'calling' || status == 'serving') {
      _peopleAhead = 0;
    } else {
      _peopleAhead = 1;
    }
  }

  void _setupRealtimeSubscription(String ticketId) {
    _realtimeSub?.cancel();
    try {
      _realtimeSub = Supabase.instance.client
          .from('queue_tickets')
          .stream(primaryKey: ['id'])
          .eq('id', ticketId)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              setState(() {
                _activeTicket = Map<String, dynamic>.from(data.first);
                _calculatePeopleAhead();
              });
            }
          });
    } catch (_) {}
  }

  Future<void> _cancelTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161624),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batal Giliran?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Adakah anda pasti ingin membatalkan giliran ini? Anda perlu mengambil nombor baru jika ingin beratur semula.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (_activeTicket != null) {
      final ticketId = _activeTicket!['id'] as String;
      try {
        await Supabase.instance.client
            .from('queue_tickets')
            .update({'status': 'cancelled'})
            .eq('id', ticketId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _activeTicket?['status'] = 'cancelled';
        });
        showGlassToast(context, 'Giliran anda telah dibatalkan');
      }
    }
  }

  void _callShop(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) showGlassToast(context, 'Tidak dapat mendail nombor kedai', isError: true);
    }
  }

  void _whatsappShop(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) showGlassToast(context, 'Tidak dapat membuka WhatsApp', isError: true);
    }
  }

  Future<void> _scanQueueQr() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (scanned == null || scanned.isEmpty || !mounted) return;

    String bizId = scanned.trim();
    if (bizId.startsWith('NGAM_QUEUE:')) {
      bizId = bizId.replaceFirst('NGAM_QUEUE:', '').trim();
    } else {
      final uri = Uri.tryParse(bizId);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        bizId = uri.pathSegments.last;
      }
    }

    _showJoinQueueSheet(bizId);
  }

  void _showJoinQueueSheet(String bizId) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final nameCtrl = TextEditingController(text: user?.userName ?? '');
    final phoneCtrl = TextEditingController(text: user?.userPhone ?? '');
    String selectedService = 'Gunting Rambut & Grooming';
    final services = [
      'Gunting Rambut & Grooming',
      'Cuci, Rawatan & Styling',
      'Konsultasi Perkhidmatan',
      'Servis Pantas / Touch-up',
    ];

    String shopName = 'Kedai Pilihan';
    try {
      final res = await Supabase.instance.client
          .from('businesses')
          .select('business_name')
          .eq('id', bizId)
          .maybeSingle();
      if (res != null && res['business_name'] != null) {
        shopName = res['business_name'] as String;
      }
    } catch (_) {}

    if (!mounted) return;

    final scaffoldCtx = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF42A5F5), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sertai Giliran Walk-In',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              shopName,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Customer Name
                  const Text('Nama Pelanggan', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E1E34),
                      hintText: 'Masukkan nama anda',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Phone Number
                  const Text('Nombor Telefon (WhatsApp)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E1E34),
                      hintText: 'e.g. 012-3456789',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Service selection
                  const Text('Pilih Perkhidmatan', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services.map((s) {
                      final isSel = s == selectedService;
                      return ChoiceChip(
                        label: Text(s),
                        selected: isSel,
                        selectedColor: const Color(0xFF42A5F5),
                        backgroundColor: const Color(0xFF1E1E34),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedService = s);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        if (name.isEmpty) {
                          showGlassToast(modalCtx, 'Sila masukkan nama anda', isError: true);
                          return;
                        }

                        Navigator.pop(modalCtx);

                        final randNum = 100 + (DateTime.now().millisecond % 899);
                        final ticketNum = 'A$randNum';

                        Map<String, dynamic> newTicket = {
                          'id': 'tk-${DateTime.now().millisecondsSinceEpoch}',
                          'business_id': bizId,
                          'ticket_number': ticketNum,
                          'customer_name': name,
                          'phone_number': phone,
                          'service_name': selectedService,
                          'status': 'waiting',
                          'estimated_wait_minutes': 15,
                          'business_name': shopName,
                          'created_at': DateTime.now().toIso8601String(),
                        };

                        try {
                          final res = await Supabase.instance.client
                              .from('queue_tickets')
                              .insert({
                                'business_id': bizId,
                                'ticket_number': ticketNum,
                                'customer_name': name,
                                'phone_number': phone,
                                'service_name': selectedService,
                                'status': 'waiting',
                                'estimated_wait_minutes': 15,
                              })
                              .select()
                              .maybeSingle();
                          if (res != null) {
                            newTicket = Map<String, dynamic>.from(res);
                            newTicket['business_name'] = shopName;
                          }
                        } catch (_) {}

                        if (mounted) {
                          setState(() {
                            _activeTicket = newTicket;
                            _peopleAhead = 1;
                            _isLoading = false;
                          });
                          _setupRealtimeSubscription(newTicket['id'] as String);
                          if (!scaffoldCtx.mounted) return;
                          showGlassToast(scaffoldCtx, 'Berjaya sertai giliran! Nombor anda: $ticketNum');
                        }
                      },
                      child: const Text('Sahkan & Ambil Tiket Giliran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'Tiket Giliran Walk-In',
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF42A5F5)),
            onPressed: _scanQueueQr,
            tooltip: 'Imbas QR Giliran',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF42A5F5)),
            onPressed: () => _loadCustomerTicket(),
            tooltip: 'Segarkan Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeTicket == null || _activeTicket!['status'] == 'cancelled'
              ? _buildEmptyState(isDark)
              : _buildTicketContent(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedTicket01,
                color: Color(0xFF42A5F5),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tiada Giliran Aktif',
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Anda belum mengambil tiket giliran walk-in di mana-mana kedai hari ini. Imbas kod QR di kedai untuk sertai giliran tanpa beratur fizikal!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _scanQueueQr,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text('Imbas Kod QR Kedai untuk Ambil Giliran', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text('Cari Barbershop / Kedai Berdekatan', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketContent(bool isDark) {
    final ticket = _activeTicket!;
    final ticketNum = ticket['ticket_number'] as String? ?? 'A001';
    final shopName = ticket['business_name'] ?? (ticket['businesses'] as Map?)?['business_name'] ?? 'Empire Barber & Co.';
    final shopPhone = ticket['business_phone'] ?? (ticket['businesses'] as Map?)?['business_phone'] ?? '+60 12-345 6789';
    final shopAddress = ticket['business_address'] ?? (ticket['businesses'] as Map?)?['business_address'] ?? 'Bandar Baru Bangi';
    final serviceName = ticket['service_name'] as String? ?? 'Gunting Rambut Walk-In';
    final station = ticket['station_or_chair'] as String?;
    final staffName = ticket['assigned_staff_name'] as String?;
    final status = ticket['status'] as String? ?? 'waiting';
    final waitMin = ticket['estimated_wait_minutes'] ?? 15;

    final isCalling = status == 'calling';
    final isServing = status == 'serving';
    final isCompleted = status == 'completed';

    Color bannerColor;
    String bannerTitle;
    String bannerSubtitle;
    IconData bannerIcon;

    if (isCalling) {
      bannerColor = const Color(0xFFF59E0B);
      bannerTitle = 'GILIRAN ANDA TELAH DIPANGGIL!';
      bannerSubtitle = station != null ? 'Sila ke $station sekarang!' : 'Sila ke kaunter sekarang!';
      bannerIcon = Icons.notifications_active_rounded;
    } else if (isServing) {
      bannerColor = const Color(0xFF10B981);
      bannerTitle = 'SEDANG DISERVIS';
      bannerSubtitle = 'Servis sedang dijalankan di ${station ?? 'stesen servis'}';
      bannerIcon = Icons.content_cut_rounded;
    } else if (isCompleted) {
      bannerColor = const Color(0xFF6B7280);
      bannerTitle = 'SERVIS SELESAI';
      bannerSubtitle = 'Terima kasih kerana melanggan bersama kami!';
      bannerIcon = Icons.check_circle_rounded;
    } else {
      bannerColor = const Color(0xFF3B82F6);
      bannerTitle = 'MENUNGGU GILIRAN';
      bannerSubtitle = 'Anggaran giliran anda dalam ~$waitMin minit';
      bannerIcon = Icons.hourglass_top_rounded;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // 1. Live Animated Status Banner
          ScaleTransition(
            scale: isCalling ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [bannerColor, bannerColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: bannerColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(bannerIcon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bannerTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bannerSubtitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Main Boarding-Pass Style Ticket Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141424) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isCalling
                    ? const Color(0xFFF59E0B)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                width: isCalling ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Ticket Header: Shop Info
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF42A5F5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shopName,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shopAddress,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Perforated Divider
                _buildPerforatedDivider(isDark),

                // Ticket Number & Live Queue Rank
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      Text(
                        'NOMBOR GILIRAN ANDA',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ticketNum,
                        style: GoogleFonts.outfit(
                          color: bannerColor,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Queue Position Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E34) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _peopleAhead == 0 ? Icons.check_circle_rounded : Icons.people_outline_rounded,
                              size: 16,
                              color: _peopleAhead == 0 ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _peopleAhead == 0
                                  ? 'Giliran anda sekarang!'
                                  : 'Lagi $_peopleAhead orang di hadapan anda',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Service & Assignment Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F0F1B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Servis', serviceName, isDark),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          'Stesen Bertugas',
                          station ?? 'Akan Ditugaskan',
                          isDark,
                          highlight: station != null,
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          'Barber Bertugas',
                          staffName ?? 'Krew Pertama Tersedia',
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // QR Code for counter scanning
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: 'NGAM_QUEUE:${ticket['id']}:$ticketNum',
                    version: QrVersions.auto,
                    size: 140,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tunjukkan kod QR ini semasa dipanggil',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Quick Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _callShop(shopPhone),
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text('Hubungi Kedai', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _whatsappShop(shopPhone),
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedMessage01, color: Color(0xFF25D366), size: 18),
                  label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          if (!isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _cancelTicket,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Batal Giliran Ini', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight
                ? const Color(0xFF10B981)
                : (isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildPerforatedDivider(bool isDark) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = constraints.constrainWidth();
              const dashWidth = 6.0;
              const dashHeight = 1.0;
              final dashCount = (boxWidth / (2 * dashWidth)).floor();
              return Flex(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                direction: Axis.horizontal,
                children: List.generate(dashCount, (_) {
                  return SizedBox(
                    width: dashWidth,
                    height: dashHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        Container(
          width: 16,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
