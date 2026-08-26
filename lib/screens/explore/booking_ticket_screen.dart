import 'dart:async'; // 🟢 Needed for Timer
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/l10n/generated/app_localizations.dart';
import 'bookings_view.dart';

class BookingTicketScreen extends StatefulWidget {
  final String shopId; // 🟢 Add this
  final String shopName;
  final String category;
  final String shopImage;
  final String providerName;
  final String date;
  final String time;
  final String totalPrice;
  final String bookingId;
  final bool isCancelled;

  const BookingTicketScreen({
    super.key,
    required this.shopId, // 🟢 Add this
    required this.shopName,
    required this.category,
    required this.shopImage,
    required this.providerName,
    required this.date,
    required this.time,
    required this.totalPrice,
    required this.bookingId,
    this.isCancelled = false,

  });

  @override
  State<BookingTicketScreen> createState() => _BookingTicketScreenState();
}

class _BookingTicketScreenState extends State<BookingTicketScreen> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _isPast = false;
  late DateTime _targetDateTime;

  @override
  void initState() {
    super.initState();

    // 🟢 ONLY run the timer if the booking is NOT cancelled!
    if (!widget.isCancelled) {
      _targetDateTime = _parseBookingDateTime(widget.date, widget.time);
      _updateTimeLeft();

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTimeLeft();
      });
    }
  }

  @override
  void dispose() {
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

  Future<void> _contactOwner() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+60123456789');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      debugPrint("Could not launch $phoneUri");
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
      ),
      // 🟢 CHANGED: We now use a Column to separate the Scrollable Ticket from the Sticky Bottom Buttons
      body: Column(
        children: [
          // --- SCROLLABLE TICKET AREA ---
          Expanded(
            child: SingleChildScrollView(
              // 🟢 FIX: Added bottom: 40 padding so it doesn't get stuck behind buttons
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 40),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  if (widget.isCancelled)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5))
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.redAccent, size: 22),
                          const SizedBox(width: 12),
                          Flexible(child: Text("This booking was cancelled", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : Colors.red.shade700))),
                        ],
                      ),
                    )
                  else
                    Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: _isPast
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _isPast ? Colors.green.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.5)
                        )
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                            icon: _isPast ? HugeIcons.strokeRoundedTickDouble01 : HugeIcons.strokeRoundedTime02,
                            color: _isPast ? Colors.green : Colors.blue,
                            size: 22
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _isPast
                                ? l10n.ticketCountdownPast
                                : l10n.ticketCountdownStartsIn(_formatDuration(_timeLeft)),
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _isPast
                                    ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                                    : (isDark ? Colors.blueAccent : Colors.blue.shade700)
                            ),
                          ),
                        )
                      ],
                    ),
                  ),

                  // 🟢 REARRANGED CLEAN TICKET CARD
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
                                child: Image.network(
                                  widget.shopImage,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
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
                              _buildDetailRow(l10n.ticketProvider, widget.providerName, isDark),
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

                        // 🟢 Only show QR if NOT cancelled!
                        if (!widget.isCancelled)

                        // 🟢 Only show QR if NOT cancelled!
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
                                data: widget.bookingId,
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
              bottom: true, // 🟢 Helps prevent iOS swipe bar overlap
              child: Row(
                children: [
                  Expanded(
                    flex: 1, // 🟢 Force 1 flex
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
                      child: const Icon(Icons.phone_outlined, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1, // 🟢 Force 1 flex
                    child: ElevatedButton(
                      onPressed: () {}, // Add map logic
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
                      child: const Icon(Icons.directions_rounded, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 🟢 ONLY show the big "Book Again" button if it was cancelled
                  if (widget.isCancelled) ...[
                    const SizedBox(width: 8),
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
                  ]
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
}