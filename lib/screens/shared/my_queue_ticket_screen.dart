import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../widgets/glass_nav_button.dart';
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
  final String? initialBusinessId;
  final Map<String, dynamic>? initialShop;
  final bool allowDirectJoin;

  const MyQueueTicketScreen({
    super.key,
    this.initialTicket,
    this.initialBusinessId,
    this.initialShop,
    this.allowDirectJoin = false,
  });

  @override
  State<MyQueueTicketScreen> createState() => _MyQueueTicketScreenState();
}

class _MyQueueTicketScreenState extends State<MyQueueTicketScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _activeTicket;
  Map<String, dynamic>? _targetShop;
  int _peopleAhead = 0;
  String? _currentServingNumber;
  int _shopLiveWaitingCount = 0;
  String? _shopLiveServingNumber;
  int _shopLiveEstWait = 0;
  bool _canDirectJoin = false;
  bool _didAutoPromptJoin = false;
  Timer? _refreshTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _canDirectJoin = widget.allowDirectJoin;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.initialShop != null) {
      _targetShop = Map<String, dynamic>.from(widget.initialShop!);
    }

    if (widget.initialTicket != null) {
      _activeTicket = Map<String, dynamic>.from(widget.initialTicket!);
      _isLoading = false;
      _syncQueuePosition();
      final bId = _activeTicket!['business_id']?.toString();
      if (bId != null && bId.isNotEmpty) {
        _setupRealtimeSubscription(bId);
      }
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

  Future<Map<String, dynamic>?> _resolveBusiness(
    String rawId, {
    Map<String, dynamic>? preloadedShop,
  }) async {
    final clean = rawId.trim();
    if (clean.isEmpty && preloadedShop != null) return preloadedShop;

    final cleanHandle = clean.replaceAll('@', '').trim().toLowerCase();
    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(clean);

    try {
      final client = Supabase.instance.client;
      Map<String, dynamic>? row;

      if (isUuid) {
        row = await client
            .from('businesses')
            .select()
            .eq('id', clean)
            .maybeSingle();
      }

      row ??= await client
          .from('businesses')
          .select()
          .eq('business_handle', cleanHandle)
          .maybeSingle();

      row ??= await client
          .from('businesses')
          .select()
          .ilike('business_name', cleanHandle)
          .maybeSingle();

      if (row == null && cleanHandle.contains('-')) {
        row = await client
            .from('businesses')
            .select()
            .ilike('business_name', cleanHandle.replaceAll('-', ' '))
            .maybeSingle();
      }

      if (row != null) {
        return Map<String, dynamic>.from(row);
      }
    } catch (_) {}

    return preloadedShop;
  }

  String _formatBusinessAddress(Map<String, dynamic>? bizMap, {String? fallback}) {
    if (bizMap == null) return fallback ?? '';
    final parts = <String>[];
    final line = bizMap['address_line']?.toString().trim() ?? '';
    final city = bizMap['business_city']?.toString().trim() ?? '';
    final state = bizMap['state']?.toString().trim() ?? '';
    if (line.isNotEmpty) parts.add(line);
    if (city.isNotEmpty && !line.toLowerCase().contains(city.toLowerCase())) {
      parts.add(city);
    }
    if (state.isNotEmpty && !line.toLowerCase().contains(state.toLowerCase())) {
      parts.add(state);
    }
    if (parts.isNotEmpty) return parts.join(', ');
    return fallback ?? '';
  }

  Future<void> _loadCustomerTicket({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      String? phone = user?.userPhone;

      // Resolve target shop if initialBusinessId was provided
      if (_targetShop == null &&
          widget.initialBusinessId != null &&
          widget.initialBusinessId!.trim().isNotEmpty) {
        _targetShop = await _resolveBusiness(
          widget.initialBusinessId!,
          preloadedShop: widget.initialShop,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final savedTicketId = prefs.getString('active_queue_ticket_id');
      final savedPhone = prefs.getString('active_queue_ticket_phone');
      if ((phone == null || phone.isEmpty) &&
          savedPhone != null &&
          savedPhone.isNotEmpty) {
        phone = savedPhone;
      }

      final client = Supabase.instance.client;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

      dynamic response;

      // 1. Check local saved ticket ID (Guest persistence even if Chrome closed!)
      if (savedTicketId != null &&
          savedTicketId.isNotEmpty &&
          !savedTicketId.startsWith('demo-') &&
          !savedTicketId.startsWith('tk-')) {
        try {
          response = await client
              .from('queue_tickets')
              .select(
                '*, businesses(id, business_name, business_handle, business_phone, address_line, business_city, state, business_logo_url)',
              )
              .eq('id', savedTicketId)
              .maybeSingle();

          if (response != null) {
            final st = response['status']?.toString().toLowerCase();
            if (st == 'completed' || st == 'cancelled' || st == 'no_show') {
              await prefs.remove('active_queue_ticket_id');
              response = null; // Ticket finished, allow new ticket
            }
          }
        } catch (_) {}
      }

      // 2. Check by phone number for today
      if (response == null && phone != null && phone.isNotEmpty) {
        try {
          response = await client
              .from('queue_tickets')
              .select(
                '*, businesses(id, business_name, business_handle, business_phone, address_line, business_city, state, business_logo_url)',
              )
              .eq('phone_number', phone)
              .inFilter('status', ['waiting', 'calling', 'serving'])
              .gte('created_at', startOfDay)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (response != null && response['id'] != null) {
            await prefs.setString(
              'active_queue_ticket_id',
              response['id'].toString(),
            );
          }
        } catch (_) {}
      }

      if (response != null && mounted) {
        final ticketMap = Map<String, dynamic>.from(response);
        setState(() {
          _activeTicket = ticketMap;
          _isLoading = false;
        });
        await _syncQueuePosition();
        final bId = ticketMap['business_id']?.toString();
        if (bId != null && bId.isNotEmpty) {
          _setupRealtimeSubscription(bId);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _activeTicket = null;
          _isLoading = false;
        });

        final targetId =
            _targetShop?['id']?.toString() ?? widget.initialBusinessId ?? '';
        if (targetId.isNotEmpty) {
          await _syncTargetShopQueue(targetId);
          _setupRealtimeSubscription(targetId);
        }

        // Only auto-open join queue sheet if customer scanned the counter QR code
        if (_canDirectJoin &&
            !_didAutoPromptJoin &&
            (widget.initialBusinessId != null || _targetShop != null)) {
          _didAutoPromptJoin = true;
          if (targetId.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showJoinQueueSheet(targetId, preloadedShop: _targetShop);
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncQueuePosition() async {
    final ticket = _activeTicket;
    if (ticket == null) return;

    final status = ticket['status']?.toString().toLowerCase() ?? 'waiting';
    if (status == 'calling' || status == 'serving' || status == 'completed') {
      if (mounted) {
        setState(() {
          _peopleAhead = 0;
          _currentServingNumber = ticket['ticket_number']?.toString();
        });
      }
      return;
    }

    final bizId = ticket['business_id']?.toString() ?? '';
    if (bizId.isEmpty) return;

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final rows = await Supabase.instance.client
          .from('queue_tickets')
          .select('id, ticket_number, status, created_at')
          .eq('business_id', bizId)
          .gte('created_at', startOfDay)
          .order('created_at', ascending: true);

      final list = (rows as List).cast<Map<String, dynamic>>();
      final myId = ticket['id']?.toString() ?? '';
      final myCreated = DateTime.tryParse(ticket['created_at']?.toString() ?? '');

      int ahead = 0;
      String? servingNum;

      for (final r in list) {
        final rId = r['id']?.toString() ?? '';
        final rStatus = r['status']?.toString().toLowerCase() ?? '';
        final rNum = r['ticket_number']?.toString();

        if (rStatus == 'calling' || rStatus == 'serving') {
          servingNum = rNum;
        }

        if (rId == myId) {
          continue;
        }

        if (rStatus == 'waiting' || rStatus == 'calling') {
          final rCreated = DateTime.tryParse(r['created_at']?.toString() ?? '');
          if (myCreated != null && rCreated != null) {
            if (rCreated.isBefore(myCreated)) {
              ahead++;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _peopleAhead = ahead;
          _currentServingNumber = servingNum;
        });
      }
    } catch (_) {}
  }

  Future<void> _syncTargetShopQueue(String bizId) async {
    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(bizId);
    if (!isUuid) return;

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final rows = await Supabase.instance.client
          .from('queue_tickets')
          .select('id, ticket_number, status, created_at')
          .eq('business_id', bizId)
          .gte('created_at', startOfDay)
          .order('created_at', ascending: true);

      final list = (rows as List).cast<Map<String, dynamic>>();
      int waiting = 0;
      String? serving;
      for (final r in list) {
        final st = r['status']?.toString().toLowerCase() ?? '';
        if (st == 'calling' || st == 'serving') {
          serving = r['ticket_number']?.toString();
        }
        if (st == 'waiting' || st == 'calling') {
          waiting++;
        }
      }

      if (mounted) {
        setState(() {
          _shopLiveWaitingCount = waiting;
          _shopLiveServingNumber = serving;
          _shopLiveEstWait = waiting * 15;
        });
      }
    } catch (_) {}
  }

  void _setupRealtimeSubscription(String businessId) {
    _realtimeSub?.cancel();
    try {
      _realtimeSub = Supabase.instance.client
          .from('queue_tickets')
          .stream(primaryKey: ['id'])
          .eq('business_id', businessId)
          .listen((data) {
            if (!mounted) return;
            if (_activeTicket == null) {
              _syncTargetShopQueue(businessId);
              return;
            }
            final myId = _activeTicket!['id']?.toString();
            final myRow = data.where((r) => r['id']?.toString() == myId).toList();
            if (myRow.isNotEmpty) {
              setState(() {
                final existingBiz = _activeTicket!['businesses'];
                final existingBizName = _activeTicket!['business_name'];
                _activeTicket = {
                  ...myRow.first,
                  if (existingBiz != null) 'businesses': existingBiz,
                  if (existingBizName != null) 'business_name': existingBizName,
                };
              });
            }
            _syncQueuePosition();
          });
    } catch (_) {}
  }

  Future<void> _cancelTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161624),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'queue.cancel_title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Adakah anda pasti ingin membatalkan giliran ini? Anda perlu mengambil nombor baru jika ingin beratur semula.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'common.back'.tr(),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'queue.confirm_cancel'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_queue_ticket_id');

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
      if (mounted) {
        showGlassToast(
          context,
          'Tidak dapat mendail nombor kedai',
          isError: true,
        );
      }
    }
  }

  void _whatsappShop(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    String clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.startsWith('0')) clean = '6$clean';
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showGlassToast(context, 'booking.whatsapp_error'.tr(), isError: true);
      }
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

    if (mounted) {
      setState(() => _canDirectJoin = true);
    }
    _showJoinQueueSheet(bizId);
  }

  Future<void> _showJoinQueueSheet(
    String rawBizId, {
    Map<String, dynamic>? preloadedShop,
  }) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('active_queue_ticket_phone') ?? '';
    final savedName = prefs.getString('active_queue_ticket_name') ?? '';

    final nameCtrl = TextEditingController(
      text: (user?.userName?.isNotEmpty == true) ? user!.userName : savedName,
    );
    final phoneCtrl = TextEditingController(
      text: (user?.userPhone?.isNotEmpty == true) ? user!.userPhone : savedPhone,
    );

    // 1. Resolve business record (by UUID, @handle, or name)
    final resolvedShop = await _resolveBusiness(
      rawBizId,
      preloadedShop: preloadedShop ?? _targetShop,
    );

    final String realBizId =
        resolvedShop?['id']?.toString() ?? rawBizId.replaceAll('@', '').trim();
    final String shopName =
        (resolvedShop?['business_name'] ??
                resolvedShop?['name'] ??
                'Kedai Pilihan')
            .toString();
    final String shopPhone =
        (resolvedShop?['business_phone'] ?? resolvedShop?['phone'] ?? '')
            .toString();
    final String shopAddress = _formatBusinessAddress(
      resolvedShop,
      fallback: resolvedShop?['address']?.toString() ?? '',
    );

    if (resolvedShop != null && mounted) {
      setState(() => _targetShop = resolvedShop);
    }

    // 2. Fetch shop's services from business_products & queue stats
    List<String> services = [
      'Gunting Rambut & Grooming',
      'Cuci, Rawatan & Styling',
      'Potong Janggut / Shave',
      'Servis Pantas / Walk-In',
    ];
    int activeWaitingCount = 0;
    int nextTicketSeq = 1;
    int baseWaitMins = 15;
    int totalChairs = 1;

    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(realBizId);

    if (isUuid) {
      final client = Supabase.instance.client;
      // Load shop's real services/products if available
      try {
        final prodRows = await client
            .from('business_products')
            .select('name, is_active')
            .eq('shop_id', realBizId)
            .order('created_at', ascending: true);
        final loadedNames = (prodRows as List)
            .where(
              (r) =>
                  r['is_active'] != false &&
                  (r['name']?.toString().trim().isNotEmpty ?? false),
            )
            .map((r) => r['name'].toString().trim())
            .toSet()
            .toList();
        if (loadedNames.isNotEmpty) {
          services = loadedNames;
        }
      } catch (_) {}

      // Load shop's total_chairs & estimated_wait_minutes
      try {
        final settingsRes = await client
            .from('business_settings')
            .select('total_chairs, operating_hours')
            .eq('business_id', realBizId)
            .maybeSingle();
        if (settingsRes != null) {
          totalChairs = (settingsRes['total_chairs'] as num?)?.toInt() ?? 1;
          if (totalChairs < 1) totalChairs = 1;
          final op = settingsRes['operating_hours'];
          if (op is Map && op['estimated_wait_minutes'] != null) {
            baseWaitMins = (op['estimated_wait_minutes'] as num?)?.toInt() ?? 15;
          }
        }
      } catch (_) {}

      // Load today's tickets for sequential numbering & live waiting count
      try {
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
        final todayTickets = await client
            .from('queue_tickets')
            .select('ticket_number, status')
            .eq('business_id', realBizId)
            .gte('created_at', startOfToday);

        final list = todayTickets as List;
        int maxNum = list.length;
        for (final r in list) {
          final st = r['status']?.toString().toLowerCase() ?? '';
          if (st == 'waiting' || st == 'calling') {
            activeWaitingCount++;
          }
          final tNum = (r['ticket_number']?.toString() ?? '').replaceAll(
            RegExp(r'[^0-9]'),
            '',
          );
          final parsed = int.tryParse(tNum);
          if (parsed != null && parsed < 100 && parsed > maxNum) {
            maxNum = parsed;
          }
        }
        nextTicketSeq = maxNum + 1;
      } catch (_) {}
    }

    String selectedService = services.first;
    final int estWaitTotal =
        ((activeWaitingCount ~/ totalChairs) + 1) * baseWaitMins;

    if (!mounted) return;
    final scaffoldCtx = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedTicket01,
                            color: Color(0xFF10B981),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'queue.join_walkin_title'.tr(),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                shopName,
                                style: const TextStyle(
                                  color: Color(0xFF42A5F5),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Live Queue Status Pill inside Modal
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: activeWaitingCount == 0
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFF42A5F5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: activeWaitingCount == 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.35)
                              : const Color(0xFF42A5F5).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            activeWaitingCount == 0
                                ? Icons.flash_on_rounded
                                : Icons.people_alt_rounded,
                            size: 16,
                            color: activeWaitingCount == 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFF42A5F5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeWaitingCount == 0
                                  ? 'queue.no_waiting_now'.tr()
                                  : 'queue.live_waiting_badge'.tr(
                                      args: [
                                        activeWaitingCount.toString(),
                                        estWaitTotal.toString(),
                                      ],
                                    ),
                              style: TextStyle(
                                color: activeWaitingCount == 0
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF90CAF9),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Customer Name
                    Text(
                      '${'queue.customer_name'.tr()} *',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E1E34),
                        hintText: 'queue.enter_name_hint'.tr(),
                        hintStyle: const TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Number
                    Text(
                      'queue.phone_number'.tr(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Service selection
                    Text(
                      'queue.select_service'.tr(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    const SizedBox(height: 22),

                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final phone = phoneCtrl.text.trim();
                                if (name.isEmpty) {
                                  showGlassToast(
                                    modalCtx,
                                    'queue.enter_name_error'.tr(),
                                    isError: true,
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final ticketNum =
                                    'A${nextTicketSeq.toString().padLeft(3, '0')}';

                                Map<String, dynamic> newTicket = {
                                  'id':
                                      'tk-${DateTime.now().millisecondsSinceEpoch}',
                                  'business_id': realBizId,
                                  'ticket_number': ticketNum,
                                  'customer_name': name,
                                  'phone_number': phone,
                                  'service_name': selectedService,
                                  'status': 'waiting',
                                  'estimated_wait_minutes': estWaitTotal,
                                  'business_name': shopName,
                                  'business_phone': shopPhone,
                                  'business_address': shopAddress,
                                  'created_at': DateTime.now().toIso8601String(),
                                };

                                if (isUuid) {
                                  try {
                                    final res = await Supabase.instance.client
                                        .from('queue_tickets')
                                        .insert({
                                          'business_id': realBizId,
                                          'ticket_number': ticketNum,
                                          'customer_name': name,
                                          if (phone.isNotEmpty)
                                            'phone_number': phone,
                                          'service_name': selectedService,
                                          'status': 'waiting',
                                          'estimated_wait_minutes': estWaitTotal,
                                        })
                                        .select(
                                          '*, businesses(id, business_name, business_handle, business_phone, address_line, business_city, state, business_logo_url)',
                                        )
                                        .maybeSingle();
                                    if (res != null) {
                                      newTicket = Map<String, dynamic>.from(res);
                                      newTicket['business_name'] = shopName;
                                      newTicket['business_phone'] = shopPhone;
                                      newTicket['business_address'] = shopAddress;
                                    }
                                  } catch (_) {}
                                }

                                if (modalCtx.mounted) {
                                  Navigator.pop(modalCtx);
                                }

                                if (mounted) {
                                  SharedPreferences.getInstance().then((p) {
                                    if (newTicket['id'] != null) {
                                      p.setString(
                                        'active_queue_ticket_id',
                                        newTicket['id'].toString(),
                                      );
                                    }
                                    p.setString('active_queue_ticket_name', name);
                                    if (phone.isNotEmpty) {
                                      p.setString(
                                        'active_queue_ticket_phone',
                                        phone,
                                      );
                                    }
                                  });
                                  setState(() {
                                    _activeTicket = newTicket;
                                    _peopleAhead = activeWaitingCount;
                                    _isLoading = false;
                                  });
                                  await _syncQueuePosition();
                                  if (isUuid) {
                                    _setupRealtimeSubscription(realBizId);
                                  }
                                  if (!scaffoldCtx.mounted) return;
                                  showGlassToast(
                                    scaffoldCtx,
                                    'queue.joined_success'.tr(args: [ticketNum]),
                                  );
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const HugeIcon(
                                icon: HugeIcons.strokeRoundedTicket01,
                                color: Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          'queue.confirm_take_ticket'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
      backgroundColor:
          isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 56),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _activeTicket == null ||
                          _activeTicket!['status'] == 'cancelled'
                      ? _buildEmptyState(isDark)
                      : _buildTicketContent(isDark),
            ),

            FloatingTopBar(
              isDark: isDark,
              title: 'profile.live_queue'.tr(),
              actions: [
                GlassNavPill(
                  isDark: isDark,
                  items: [
                    GlassNavPillItem(
                      icon: HugeIcons.strokeRoundedQrCode,
                      iconColor: const Color(0xFF42A5F5),
                      tooltip: 'queue.scan_qr_hint'.tr(),
                      onTap: _scanQueueQr,
                    ),
                    GlassNavPillItem(
                      icon: HugeIcons.strokeRoundedRefresh,
                      iconColor: const Color(0xFF42A5F5),
                      tooltip: 'queue.refresh_status'.tr(),
                      onTap: () => _loadCustomerTicket(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final targetShopName =
        (_targetShop?['business_name'] ?? _targetShop?['name'])?.toString();
    final targetShopId =
        (_targetShop?['id'] ?? widget.initialBusinessId)?.toString();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedTicket01,
                color: Color(0xFF10B981),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'queue.no_active_queue'.tr(),
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'queue.no_active_queue_desc'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (targetShopName != null &&
                targetShopName.isNotEmpty &&
                targetShopId != null &&
                targetShopId.isNotEmpty) ...[
              // Papan Status Giliran Semasa (Live Queue Status Board)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${'queue.live_board_title'.tr()} • $targetShopName',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'queue.now_serving_label'.tr(),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _shopLiveServingNumber ?? '-',
                                  style: GoogleFonts.outfit(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'queue.waiting_count_label'.tr(),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _shopLiveWaitingCount == 0
                                      ? '0'
                                      : 'queue.waiting_people_val'.tr(
                                          args: [
                                            _shopLiveWaitingCount.toString(),
                                            _shopLiveEstWait.toString(),
                                          ],
                                        ),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF10B981),
                                    fontSize: _shopLiveWaitingCount == 0
                                        ? 22
                                        : 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_canDirectJoin) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedQrCode,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'queue.scan_at_counter_notice'.tr(),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  fontSize: 11.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_canDirectJoin) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _showJoinQueueSheet(
                      targetShopId,
                      preloadedShop: _targetShop,
                    ),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedTicket01,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: Text(
                      'queue.take_ticket_for_shop'.tr(args: [targetShopName]),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _scanQueueQr,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedQrCode,
                  size: 20,
                  color: Colors.white,
                ),
                label: Text(
                  (targetShopName != null && !_canDirectJoin)
                      ? 'queue.arrived_scan_qr_btn'.tr()
                      : 'queue.scan_qr_hint'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedNavigation01,
                  size: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                label: Text(
                  'queue.find_nearby'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketContent(bool isDark) {
    final ticket = _activeTicket!;
    final bizMap = ticket['businesses'] is Map
        ? Map<String, dynamic>.from(ticket['businesses'] as Map)
        : null;
    final ticketNum = ticket['ticket_number'] as String? ?? 'A001';
    final shopName =
        (ticket['business_name'] ?? bizMap?['business_name'] ?? 'Kedai Ngam')
            .toString();
    final shopPhone =
        (ticket['business_phone'] ?? bizMap?['business_phone'] ?? '')
            .toString();
    final shopAddress = _formatBusinessAddress(
      bizMap,
      fallback: ticket['business_address']?.toString() ?? '',
    );
    final serviceName =
        ticket['service_name'] as String? ?? 'Gunting Rambut Walk-In';
    final station = ticket['station_or_chair'] as String?;
    final staffName = ticket['assigned_staff_name'] as String?;
    final status = ticket['status'] as String? ?? 'waiting';
    final waitMin = ticket['estimated_wait_minutes'] ??
        ((_peopleAhead + 1) * 15);

    final isCalling = status == 'calling';
    final isServing = status == 'serving';
    final isCompleted = status == 'completed';

    Color bannerColor;
    String bannerTitle;
    String bannerSubtitle;
    List<List<dynamic>> bannerIcon;

    if (isCalling) {
      bannerColor = const Color(0xFFF59E0B);
      bannerTitle = 'GILIRAN ANDA TELAH DIPANGGIL!';
      bannerSubtitle = station != null
          ? 'Sila ke $station sekarang!'
          : 'Sila ke kaunter sekarang!';
      bannerIcon = HugeIcons.strokeRoundedNotification03;
    } else if (isServing) {
      bannerColor = const Color(0xFF10B981);
      bannerTitle = 'SEDANG DISERVIS';
      bannerSubtitle =
          'Servis sedang dijalankan di ${station ?? 'stesen servis'}';
      bannerIcon = HugeIcons.strokeRoundedScissor;
    } else if (isCompleted) {
      bannerColor = const Color(0xFF6B7280);
      bannerTitle = 'SERVIS SELESAI';
      bannerSubtitle = 'Terima kasih kerana melanggan bersama kami!';
      bannerIcon = HugeIcons.strokeRoundedCheckmarkCircle02;
    } else {
      bannerColor = const Color(0xFF3B82F6);
      bannerTitle = 'MENUNGGU GILIRAN';
      bannerSubtitle = 'Anggaran giliran anda dalam ~$waitMin minit';
      bannerIcon = HugeIcons.strokeRoundedHourglass;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // 1. Live Animated Status Banner
          ScaleTransition(
            scale: isCalling
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
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
                    child: HugeIcon(
                      icon: bannerIcon,
                      color: Colors.white,
                      size: 28,
                    ),
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
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
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
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedStore01,
                          color: Color(0xFF42A5F5),
                          size: 24,
                        ),
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
                            if (shopAddress.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                shopAddress,
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      if (_currentServingNumber != null &&
                          _currentServingNumber != ticketNum) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${'queue.now_serving_label'.tr()}: $_currentServingNumber',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E34)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: _peopleAhead == 0
                                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                                  : HugeIcons.strokeRoundedUserGroup,
                              size: 16,
                              color: _peopleAhead == 0
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _peopleAhead == 0
                                  ? 'queue.people_ahead_zero'.tr()
                                  : 'queue.people_ahead_count'.tr(
                                      args: [_peopleAhead.toString()],
                                    ),
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
                      color: isDark
                          ? const Color(0xFF0F0F1B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
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
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'queue.guest_saved_note'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Quick Actions
          if (shopPhone.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _callShop(shopPhone),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCall,
                      size: 18,
                      color: Colors.blue,
                    ),
                    label: Text(
                      'queue.contact_store'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _whatsappShop(shopPhone),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedMessage01,
                      color: Color(0xFF25D366),
                      size: 18,
                    ),
                    label: Text(
                      'queue.whatsapp'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 16,
                  color: Colors.redAccent,
                ),
                label: Text(
                  'queue.cancel_ticket'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFF10B981)
                  : (isDark ? Colors.white : Colors.black87),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
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
