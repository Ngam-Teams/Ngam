import 'dart:async'; //  Needed for Timer
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ngam/l10n/generated/app_localizations.dart';
import '../../utils/glass_toast.dart';
import 'bookings_view.dart';

class BookingTicketScreen extends StatefulWidget {
  final String shopId; //  Add this
  final String shopName;
  final String category;
  final String shopImage;
  final String providerName;
  final String date;
  final String time;
  final String totalPrice;
  final String bookingId;
  final bool isCancelled;
  final String status;
  final String? bookingDbId;

  const BookingTicketScreen({
    super.key,
    required this.shopId, //  Add this
    required this.shopName,
    required this.category,
    required this.shopImage,
    required this.providerName,
    required this.date,
    required this.time,
    required this.totalPrice,
    required this.bookingId,
    this.isCancelled = false,
    this.status = 'confirmed',
    this.bookingDbId,
  });

  @override
  State<BookingTicketScreen> createState() => _BookingTicketScreenState();
}

class _BookingTicketScreenState extends State<BookingTicketScreen> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isPast = false;
  late DateTime _targetDateTime;
  late String _currentStatus;
  StreamSubscription<List<Map<String, dynamic>>>? _statusSubscription;
  String? _shopPhoneNumber;

  @override
  void initState() {
    super.initState();

    _currentStatus = widget.isCancelled ? 'cancelled' : widget.status;
    _fetchShopPhone();

    //  Realtime Supabase status sync with merchant
    _initRealtimeBookingStatusSync();

    //  ONLY run the timer if the booking is NOT cancelled!
    if (!widget.isCancelled && _currentStatus != 'cancelled') {
      _targetDateTime = _parseBookingDateTime(widget.date, widget.time);
      _updateTimeLeft();

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTimeLeft();
      });
    }
  }

  String? _resolvedBookingDbId;

  Future<void> _initRealtimeBookingStatusSync() async {
    _resolvedBookingDbId = widget.bookingDbId;
    if ((_resolvedBookingDbId == null || _resolvedBookingDbId!.isEmpty) &&
        widget.bookingId.isNotEmpty) {
      try {
        final found = await Supabase.instance.client
            .from('bookings')
            .select('id, status')
            .eq('booking_metadata->>booking_id', widget.bookingId)
            .maybeSingle();
        if (found != null && mounted) {
          _resolvedBookingDbId = found['id']?.toString();
          final dbStatus = found['status'] as String?;
          if (dbStatus != null && dbStatus != _currentStatus) {
            setState(() => _currentStatus = dbStatus);
          }
        }
      } catch (_) {}
    }

    if (!mounted || _resolvedBookingDbId == null || _resolvedBookingDbId!.isEmpty) return;

    _statusSubscription = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', _resolvedBookingDbId!)
        .listen((rows) {
      if (rows.isNotEmpty && mounted) {
        final dbStatus = rows.first['status'] as String?;
        if (dbStatus != null && dbStatus != _currentStatus) {
          setState(() {
            _currentStatus = dbStatus;
          });
        }
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  DateTime _parseBookingDateTime(String dateStr, String timeStr) {
    final now = DateTime.now();
    try {
      // 1. Extract the Day
      final dayMatch = RegExp(r'\d+').firstMatch(dateStr);
      int day = dayMatch != null ? int.parse(dayMatch.group(0)!) : now.day;

      // 2. Extract the Month
      int month = now.month;
      final lowerDate = dateStr.toLowerCase();
      const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
      for (int i = 0; i < months.length; i++) {
        if (lowerDate.contains(months[i])) {
          month = i + 1;
          break;
        }
      }

      // 3. Handle Year Rollover (If booking in Nov/Dec for Jan/Feb of next year)
      int year = now.year;
      if (month < now.month - 1) {
        year += 1;
      }

      // 4. Safely Extract the Time (Ignoring spaces, AM/PM, etc.)
      final cleanTimeStr = timeStr.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      bool isPM = cleanTimeStr.contains('pm');
      bool isAM = cleanTimeStr.contains('am');

      // Strip away letters, leaving only the numbers and the colon
      final timeParts = cleanTimeStr.replaceAll(RegExp(r'[a-z]'), '').split(':');
      int hour = int.parse(timeParts[0]);
      int minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

      // Convert to 24-hour time
      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);

    } catch (e) {
      debugPrint("Date Parsing Error: $e");
      // If it fails, fallback to exactly now so you don't get a fake 2-hour countdown
      return now;
    }
  }

  void _updateTimeLeft() {
    if (!mounted) return;
    final now = DateTime.now();

    if (_targetDateTime.isBefore(now)) {
      setState(() {
        _timeLeft = Duration.zero;
        _isPast = true;
      });
      _timer?.cancel();
    } else {
      setState(() {
        _timeLeft = _targetDateTime.difference(now);
        _isPast = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String days = duration.inDays > 0 ? "${duration.inDays}d " : "";
    String hours = twoDigits(duration.inHours.remainder(24));
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$days$hours:$minutes:$seconds";
  }

  Future<void> _fetchShopPhone() async {
    try {
      if (widget.shopId.isNotEmpty) {
        final res = await Supabase.instance.client
            .from('businesses')
            .select('business_phone')
            .eq('id', widget.shopId)
            .maybeSingle();
        if (res != null && res['business_phone'] != null && mounted) {
          setState(() {
            _shopPhoneNumber = res['business_phone']?.toString();
          });
          return;
        }
      }
      final byName = await Supabase.instance.client
          .from('businesses')
          .select('business_phone')
          .ilike('business_name', widget.shopName)
          .maybeSingle();
      if (byName != null && byName['business_phone'] != null && mounted) {
        setState(() {
          _shopPhoneNumber = byName['business_phone']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching shop phone: $e');
    }
  }

  Future<void> _openWhatsAppToShop() async {
    final rawPhone = _shopPhoneNumber ?? '+60123456789';
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '6$cleanPhone';
    } else if (!cleanPhone.startsWith('60') && cleanPhone.length >= 9) {
      cleanPhone = '60$cleanPhone';
    }

    final message = '''
Hai ${widget.shopName}! 👋
Saya ada tempahan melalui aplikasi *Ngam*:
📋 *No. Tempahan:* ${widget.bookingId}
✂️ *Perkhidmatan:* ${widget.category}
👤 *Pakar/Staf:* ${widget.providerName}
📅 *Tarikh:* ${widget.date}
⏰ *Masa:* ${widget.time}
💰 *Jumlah:* RM ${widget.totalPrice}

Boleh saya sahkan slot tempahan saya? Terima kasih!
''';

    final waUrl = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  Future<void> _contactOwner() async {
    final rawPhone = _shopPhoneNumber ?? '+60123456789';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E242B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hubungi ${widget.shopName}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih saluran komunikasi langsung:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedWhatsapp,
                    color: Color(0xFF25D366),
                    size: 24,
                  ),
                ),
                title: Text(
                  'WhatsApp Peniaga',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: const Text('Hantar butiran tempahan terus ke WhatsApp kedai'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  _openWhatsAppToShop();
                },
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCall02,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Panggilan Telefon',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(rawPhone),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  Navigator.pop(context);
                  final Uri phoneUri = Uri(scheme: 'tel', path: rawPhone.replaceAll(RegExp(r'\s+'), ''));
                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDirections() async {
    final query = Uri.encodeComponent(widget.shopName);
    final mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      if (await canLaunchUrl(mapUrl)) {
        await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
    }
  }

  void _showCancellationModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedReason = 'Tersalah pilih tarikh / masa';
    final customReasonCtrl = TextEditingController();
    bool isSubmitting = false;

    final reasons = [
      'Tersalah pilih tarikh / masa',
      'Kecemasan peribadi / Tidak dapat hadir',
      'Peniaga / Staf meminta batal',
      'Perkhidmatan tidak lagi diperlukan',
      'Lain-lain sebab',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E242B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Batal Tempahan Slot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sila nyatakan sebab pembatalan slot ini. Baki bayaran akan dikreditkan kembali ke Ngam Wallet anda secara automatik.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 16),
              ...reasons.map((r) => RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: r,
                groupValue: selectedReason,
                title: Text(r, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                activeColor: Colors.redAccent,
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedReason = val);
                },
              )),
              if (selectedReason == 'Lain-lain sebab') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: customReasonCtrl,
                  decoration: InputDecoration(
                    hintText: 'Nyatakan sebab pembatalan...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    setModalState(() => isSubmitting = true);
                    final finalReason = selectedReason == 'Lain-lain sebab' && customReasonCtrl.text.trim().isNotEmpty
                        ? customReasonCtrl.text.trim()
                        : selectedReason;

                    await _executeCancellation(finalReason);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Sahkan Pembatalan & Pulang Wang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeCancellation(String reason) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final targetId = _resolvedBookingDbId ?? widget.bookingDbId;
      double price = double.tryParse(widget.totalPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

      Map<String, dynamic> existingMeta = {};
      try {
        final row = (targetId != null && targetId.isNotEmpty)
            ? await Supabase.instance.client
                .from('bookings')
                .select('booking_metadata')
                .eq('id', targetId)
                .maybeSingle()
            : await Supabase.instance.client
                .from('bookings')
                .select('booking_metadata')
                .eq('booking_metadata->>booking_id', widget.bookingId)
                .maybeSingle();
        if (row != null && row['booking_metadata'] is Map) {
          existingMeta = Map<String, dynamic>.from(row['booking_metadata'] as Map);
        }
      } catch (_) {}

      final updatedMeta = {
        ...existingMeta,
        'booking_id': existingMeta['booking_id'] ?? widget.bookingId,
        'shop_name': existingMeta['shop_name'] ?? widget.shopName,
        'provider_name': existingMeta['provider_name'] ?? widget.providerName,
        'total_price': existingMeta['total_price'] ?? widget.totalPrice,
        'cancellation_reason': reason,
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancelled_by': user?.id,
      };

      if (targetId != null && targetId.isNotEmpty) {
        await Supabase.instance.client.from('bookings').update({
          'status': 'cancelled',
          'booking_metadata': updatedMeta,
        }).eq('id', targetId);
      } else {
        await Supabase.instance.client.from('bookings').update({
          'status': 'cancelled',
          'booking_metadata': updatedMeta,
        }).eq('booking_metadata->>booking_id', widget.bookingId);
      }

      if (price > 0 && user != null) {
        try {
          await Supabase.instance.client.from('wallet_transactions').insert({
            'user_id': user.id,
            'type': 'refund',
            'amount': price,
            'reference_id': widget.bookingId,
            'description': 'Bayaran balik tempahan: ${widget.shopName} (${widget.category})'
          });

          final userData = await Supabase.instance.client
              .from('users')
              .select('wallet_balance')
              .eq('id', user.id)
              .maybeSingle();
          final currentBal = (userData?['wallet_balance'] as num?)?.toDouble() ?? 0.0;
          await Supabase.instance.client.from('users').update({
            'wallet_balance': currentBal + price
          }).eq('id', user.id);
        } catch (we) {
          debugPrint('Wallet refund notice: $we');
        }
      }

      if (mounted) {
        setState(() {
          _currentStatus = 'cancelled';
        });
        showGlassToast(
          context,
          price > 0
              ? 'Tempahan dibatalkan. RM ${price.toStringAsFixed(2)} telah dikembalikan ke Wallet anda.'
              : 'Tempahan telah berjaya dibatalkan.',
          type: GlassToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal membatalkan tempahan: $e', isError: true);
      }
    }
  }

  void _showDisputeModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedDisputeType = 'no_show';
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    final disputeTypes = [
      {'key': 'no_show', 'label': 'Peniaga / Staf Tidak Muncul (No-show)'},
      {'key': 'shop_closed', 'label': 'Kedai Tutup / Tidak Beroperasi'},
      {'key': 'poor_service', 'label': 'Servis Sangat Lemah / Cuai'},
      {'key': 'overcharged', 'label': 'Caj Tambahan Tanpa Persetujuan'},
      {'key': 'other', 'label': 'Lain-lain Isu Servis'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E242B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.amber.shade700, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporkan Isu / Pertikaian',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Dana bayaran akan dibekukan serta-merta',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade700, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Pihak pengurusan Ngam akan menyiasat laporan anda. Sila nyatakan masalah yang berlaku secara telus:',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedDisputeType,
                dropdownColor: isDark ? const Color(0xFF252D37) : Colors.white,
                decoration: InputDecoration(
                  labelText: 'Kategori Masalah',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: disputeTypes.map((dt) {
                  return DropdownMenuItem<String>(
                    value: dt['key'],
                    child: Text(dt['label']!, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedDisputeType = val);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Penerangan Masalah',
                  hintText: 'Contoh: Saya sudah hadir di kedai tetapi tiada staf dan pintu kedai terkunci...',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (notesCtrl.text.trim().isEmpty) {
                      showGlassToast(context, 'Sila masukkan penerangan masalah terlebih dahulu', isError: true);
                      return;
                    }
                    setModalState(() => isSubmitting = true);
                    await _executeDispute(selectedDisputeType, notesCtrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Hantar Aduan & Bekukan Bayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeDispute(String disputeType, String reason) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final targetId = widget.bookingDbId;
      double price = double.tryParse(widget.totalPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

      bool rpcSuccess = false;
      if (targetId != null && targetId.isNotEmpty) {
        try {
          final res = await Supabase.instance.client.rpc('submit_booking_dispute', params: {
            'p_booking_id': targetId,
            'p_dispute_type': disputeType,
            'p_dispute_reason': reason,
            'p_refund_amount': price,
          });
          if (res != null && res['success'] == true) {
            rpcSuccess = true;
          }
        } catch (rpcErr) {
          debugPrint('RPC notice: $rpcErr');
        }
      }

      if (!rpcSuccess) {
        if (targetId != null && targetId.isNotEmpty) {
          await Supabase.instance.client.from('bookings').update({
            'status': 'disputed',
            'booking_metadata': {
              'is_disputed': true,
              'dispute_type': disputeType,
              'dispute_reason': reason,
              'dispute_date': DateTime.now().toIso8601String(),
            }
          }).eq('id', targetId);
        } else {
          await Supabase.instance.client.from('bookings').update({
            'status': 'disputed',
            'booking_metadata': {
              'is_disputed': true,
              'dispute_type': disputeType,
              'dispute_reason': reason,
              'dispute_date': DateTime.now().toIso8601String(),
            }
          }).eq('booking_metadata->>booking_id', widget.bookingId);
        }

        try {
          await Supabase.instance.client.from('booking_disputes').insert({
            'booking_id': targetId ?? widget.bookingId,
            'business_id': widget.shopId,
            'customer_id': user?.id,
            'customer_name': widget.providerName,
            'service_name': widget.category,
            'dispute_type': disputeType,
            'dispute_reason': reason,
            'refund_amount': price,
            'status': 'open',
          });
        } catch (insertErr) {
          debugPrint('booking_disputes insert notice: $insertErr');
        }
      }

      if (mounted) {
        setState(() {
          _currentStatus = 'disputed';
        });
        showGlassToast(
          context,
          'Aduan pertikaian telah dihantar. Bayaran dibekukan sehingga semakan selesai.',
          type: GlassToastType.warning,
          color: Colors.amber.shade700,
        );
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'Gagal menghantar pertikaian: $e', isError: true);
      }
    }
  }

  String get _providerLabel {
    final cat = widget.category.toLowerCase();
    if (cat.contains('food') || cat.contains('restaurant') || cat.contains('cafe') || cat.contains('makan') || cat.contains('fnb') || cat.contains('dining')) {
      return "Zon / Meja";
    }
    if (cat.contains('auto') || cat.contains('workshop') || cat.contains('bengkel') || cat.contains('wash') || cat.contains('tyre')) {
      return "Stesen / Servis";
    }
    if (cat.contains('health') || cat.contains('clinic') || cat.contains('klinik') || cat.contains('dental') || cat.contains('farmasi')) {
      return "Doktor / Pakar";
    }
    if (cat.contains('court') || cat.contains('sport') || cat.contains('badminton') || cat.contains('futsal') || cat.contains('kemudahan')) {
      return "Gelanggang / Bilik";
    }
    if (cat.contains('salon') || cat.contains('spa') || cat.contains('beauty') || cat.contains('facial') || cat.contains('massage') || cat.contains('urut')) {
      return "Terapis / Bilik";
    }
    if (cat.contains('retail') || cat.contains('runcit') || cat.contains('butik') || cat.contains('boutique') || cat.contains('fashion')) {
      return "Sesi / Butik";
    }
    return AppLocalizations.of(context)?.ticketProvider ?? "Pakar / Staf";
  }

  Future<void> _shareTicketToWhatsApp() async {
    final cat = widget.category.toLowerCase();
    String itemType = "Pakar/Staf";
    if (cat.contains('food') || cat.contains('restaurant') || cat.contains('cafe') || cat.contains('makan') || cat.contains('fnb') || cat.contains('dining')) {
      itemType = "Zon/Meja";
    } else if (cat.contains('auto') || cat.contains('workshop') || cat.contains('bengkel') || cat.contains('wash') || cat.contains('tyre')) {
      itemType = "Stesen/Servis";
    } else if (cat.contains('health') || cat.contains('clinic') || cat.contains('dental') || cat.contains('farmasi')) {
      itemType = "Doktor/Pakar";
    } else if (cat.contains('court') || cat.contains('sport') || cat.contains('badminton') || cat.contains('futsal')) {
      itemType = "Gelanggang/Bilik";
    } else if (cat.contains('salon') || cat.contains('spa') || cat.contains('beauty') || cat.contains('facial') || cat.contains('massage') || cat.contains('urut')) {
      itemType = "Terapis/Bilik";
    } else if (cat.contains('retail') || cat.contains('runcit') || cat.contains('butik') || cat.contains('boutique') || cat.contains('fashion')) {
      itemType = "Sesi/Butik";
    }

    final String displayPrice = widget.totalPrice.startsWith('RM') ? widget.totalPrice : 'RM ${widget.totalPrice}';

    final text = '''
*NGAM — RESIT TEMPAHAN DIGITAL*
--------------------------------
*No. Tempahan:* ${widget.bookingId}
*Kedai:* ${widget.shopName}
*Kategori:* ${widget.category}
*$itemType:* ${widget.providerName}
*Tarikh:* ${widget.date}
*Masa:* ${widget.time}
*Jumlah:* $displayPrice
*Status:* ${_currentStatus.toUpperCase()}

Disahkan melalui aplikasi *Ngam*.
''';
    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String qrData = "ID:${widget.bookingId}|SHOP:${widget.shopName}|PROV:${widget.providerName}|DATE:${widget.date}|TIME:${widget.time}";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13171B) : const Color(0xFFE5ECF1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            color: isDark ? Colors.white : Colors.black,
            size: 24.0,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.ticketOrderTitle,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Kongsi Resit',
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedShare01,
              color: isDark ? Colors.white : Colors.black,
              size: 22.0,
            ),
            onPressed: _shareTicketToWhatsApp,
          ),
          PopupMenuButton<String>(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedMoreHorizontal,
              color: isDark ? Colors.white : Colors.black,
              size: 22.0,
            ),
            color: isDark ? const Color(0xFF1E242B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'cancel') {
                _showCancellationModal();
              } else if (value == 'dispute') {
                _showDisputeModal();
              } else if (value == 'share') {
                _shareTicketToWhatsApp();
              }
            },
            itemBuilder: (context) => [
              if (_currentStatus != 'cancelled' && _currentStatus != 'completed' && _currentStatus != 'disputed')
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.redAccent, size: 18),
                      SizedBox(width: 10),
                      Text('Batal Tempahan', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (_currentStatus != 'cancelled' && _currentStatus != 'disputed')
                const PopupMenuItem(
                  value: 'dispute',
                  child: Row(
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.orangeAccent, size: 18),
                      SizedBox(width: 10),
                      Text('Laporkan Isu / Pertikaian', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedShare01, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Kongsi Slip Tempahan', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      //  CHANGED: We now use a Column to separate the Scrollable Ticket from the Sticky Bottom Buttons
      body: Column(
        children: [
          // --- SCROLLABLE TICKET AREA ---
          Expanded(
            child: SingleChildScrollView(
              //  FIX: Added bottom: 40 padding so it doesn't get stuck behind buttons
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 40),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  if (_currentStatus == 'cancelled')
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Tempahan Dibatalkan • Slot tidak lagi aktif",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : Colors.red.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_currentStatus == 'disputed')
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.amber.shade400, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Dalam Pertikaian • Dana ditahan selamat oleh Ngam",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    //  LIVE STATUS STEP TRACKER CARD
                    _buildLiveStatusTrackerCard(context, isDark),
                    const SizedBox(height: 10),

                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: _isPast
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isPast ? Colors.green.withValues(alpha: 0.4) : Colors.blue.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: _isPast ? HugeIcons.strokeRoundedTickDouble01 : HugeIcons.strokeRoundedTime02,
                            color: _isPast ? Colors.green : Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isPast
                                  ? l10n.ticketCountdownPast
                                  : l10n.ticketCountdownStartsIn(_formatDuration(_timeLeft)),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isPast
                                    ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                                    : (isDark ? Colors.blueAccent : Colors.blue.shade700),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  //  REARRANGED CLEAN TICKET CARD
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E242B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // Top Section: Shop Info
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: widget.shopImage.trim().isNotEmpty
                                    ? Image.network(
                                        widget.shopImage,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 56,
                                          height: 56,
                                          color: Colors.blueAccent.withValues(alpha: 0.15),
                                          alignment: Alignment.center,
                                          child: Text(
                                            widget.shopName.isNotEmpty ? widget.shopName[0].toUpperCase() : 'N',
                                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blueAccent),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.blueAccent.withValues(alpha: 0.15),
                                        alignment: Alignment.center,
                                        child: Text(
                                          widget.shopName.isNotEmpty ? widget.shopName[0].toUpperCase() : 'N',
                                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blueAccent),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.shopName,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      widget.category,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Dashed Divider 1
                        _buildDashedDivider(isDark),

                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _buildDetailRow(_providerLabel, widget.providerName, isDark),
                              const SizedBox(height: 12),
                              _buildDetailRow(l10n.ticketDate, widget.date, isDark),
                              const SizedBox(height: 12),
                              _buildDetailRow(l10n.ticketTime, widget.time, isDark),
                              const SizedBox(height: 12),
                              _buildDetailRow(l10n.ticketBookingId, widget.bookingId, isDark),
                              const SizedBox(height: 12),
                              _buildDetailRow(l10n.ticketTotalPaid, widget.totalPrice, isDark, isBold: true),
                            ],
                          ),
                        ),

                        // Dashed Divider 2
                        _buildDashedDivider(isDark),

                        //  Only show QR if NOT cancelled!
                        if (!widget.isCancelled)

                        //  Only show QR if NOT cancelled!
                        if (!widget.isCancelled)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 160.0,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black87),
                                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black87),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 24), // Gives the card some breathing room at the bottom if cancelled!
                      ],
                    ),
                  ),
                  if (_currentStatus != 'cancelled' && _currentStatus != 'disputed') ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_currentStatus != 'completed') ...[
                          TextButton(
                            onPressed: _showCancellationModal,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              "Batal Tempahan",
                              style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text("•", style: TextStyle(color: isDark ? Colors.white30 : Colors.black26)),
                          ),
                        ],
                        TextButton.icon(
                          onPressed: _showDisputeModal,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.orangeAccent, size: 14),
                          label: const Text(
                            "Buka Pertikaian",
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // --- STICKY BOTTOM ACTIONS (1:1:2 Layout) ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13171B) : const Color(0xFFE5ECF1),
                boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.black12, blurRadius: 10, offset: const Offset(0, -4))]
            ),
            child: SafeArea(
              top: false,
              bottom: true, //  Helps prevent iOS swipe bar overlap
              child: Row(
                children: [
                  Expanded(
                    flex: 1, //  Force 1 flex
                    child: ElevatedButton(
                      onPressed: _contactOwner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade300),
                        ),
                      ),
                      child: const HugeIcon(icon: HugeIcons.strokeRoundedCall02, size: 22, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1, //  Force 1 flex
                    child: ElevatedButton(
                      onPressed: _openDirections,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: isDark ? Colors.transparent : Colors.grey.shade300),
                        ),
                      ),
                      child: const HugeIcon(icon: HugeIcons.strokeRoundedDirections01, size: 22, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 8),

                  if (widget.isCancelled) ...[
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          // Push them right back into the checkout flow for this shop!
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookingsView(
                                shopId: widget.shopId,
                                shopName: widget.shopName,
                                category: widget.category,
                                shopImage: widget.shopImage,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text("Book Again", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ] else if (_currentStatus == 'completed') ...[
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/review',
                            arguments: {
                              'shop_id': widget.shopId,
                              'shop_name': widget.shopName,
                              'service_name': widget.category,
                              'booking_id': widget.bookingId,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedStar, size: 20, color: Colors.amber),
                            SizedBox(width: 6),
                            Text("Beri Ulasan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _openWhatsAppToShop,
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedWhatsapp,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          "WhatsApp Peniaga",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, bool isDark, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: isBold
                ? (isDark ? Colors.greenAccent : Colors.blue)
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildDashedDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            height: 20, width: 10,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13171B) : const Color(0xFFE5ECF1),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: List.generate(
                      (constraints.constrainWidth() / 8).floor(),
                          (index) => SizedBox(
                        width: 4, height: 1.5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            height: 20, width: 10,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13171B) : const Color(0xFFE5ECF1),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusTrackerCard(BuildContext context, bool isDark) {
    Color statusColor;
    dynamic statusIcon;
    String statusTitle;
    String statusSubtitle;
    int currentStepIndex;

    switch (_currentStatus.toLowerCase()) {
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = HugeIcons.strokeRoundedTime02;
        statusTitle = 'Menunggu Pengesahan Peniaga';
        statusSubtitle = 'Peniaga sedang menyemak slot tempahan anda';
        currentStepIndex = 0;
        break;
      case 'preparing':
      case 'in_progress':
        statusColor = const Color(0xFF8B5CF6);
        statusIcon = HugeIcons.strokeRoundedHourglass;
        statusTitle = 'Sedang Disediakan';
        statusSubtitle = 'Peniaga sedang menyiapkan pesanan / slot anda';
        currentStepIndex = 1;
        break;
      case 'ready':
        statusColor = const Color(0xFF10B981);
        statusIcon = HugeIcons.strokeRoundedShoppingBag01;
        statusTitle = 'Sedia Untuk Diambil / Tiba';
        statusSubtitle = 'Sila ke premis perniagaan sekarang!';
        currentStepIndex = 2;
        break;
      case 'completed':
        statusColor = const Color(0xFF10B981);
        statusIcon = HugeIcons.strokeRoundedTickDouble01;
        statusTitle = 'Tempahan Selesai';
        statusSubtitle = 'Terima kasih atas kunjungan anda';
        currentStepIndex = 2;
        break;
      case 'confirmed':
      default:
        statusColor = const Color(0xFF3B82F6);
        statusIcon = HugeIcons.strokeRoundedCheckmarkCircle02;
        statusTitle = 'Tempahan Telah Disahkan';
        statusSubtitle = 'Peniaga telah mengesahkan slot tempahan anda';
        currentStepIndex = 1;
        break;
    }

    final steps = ['Diterima', 'Disahkan', 'Sedia'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: statusIcon,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final lineIndex = index ~/ 2;
                final isPassed = lineIndex < currentStepIndex;
                return Expanded(
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? statusColor
                          : (isDark ? Colors.white12 : Colors.grey[300]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }

              final stepIndex = index ~/ 2;
              final isDone = stepIndex < currentStepIndex || (_currentStatus == 'completed' && stepIndex <= 2);
              final isCurrent = stepIndex == currentStepIndex && _currentStatus != 'completed';

              return Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDone || isCurrent
                          ? statusColor
                          : (isDark ? Colors.white10 : Colors.grey[200]),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? statusColor.withValues(alpha: 0.4)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: isDone
                          ? const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 12, color: Colors.white)
                          : isCurrent
                              ? Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : Text(
                                  '${stepIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white38 : Colors.grey[500],
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[stepIndex],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.grey[500]),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}