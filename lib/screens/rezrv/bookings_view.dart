import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🟢 REQUIRED for TextInputFormatter
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'; // 🟢 REQUIRED for LiquidGlassSettings
import '../../models/rezrv_data.dart';
import 'booking_ticket_screen.dart';
import '../../models/user_data.dart';
import 'package:ngam/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_data.dart';
import '../../services/rezrv_notification_service.dart'; // 🟢 ADD THIS LINE
import '../../widgets/glass_toast.dart'; // 🟢 ADD THIS TO YOUR IMPORTS
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math'; // 🟢 Required for generating the short ID
import 'dart:async';

class BookingsView extends StatefulWidget {
  final String shopId; // 🟢 ADD THIS
  final String shopName;
  final String category;
  final String shopImage;

  const BookingsView({
    super.key,
    required this.shopId, // 🟢 ADD THIS
    this.shopName = "Zul Barber Shop",
    this.category = "Barber",
    this.shopImage = "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400",
  });

  @override
  State<BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<BookingsView> {
  List<String> _bookedTimes = [];

  int _selectedDateIndex = 0; // Keep this!
  DateTime _selectedCalendarDate = DateTime.now(); // 🟢 ADD THIS FOR THE CALENDAR
  int _selectedTimeIndex = -1;

  final Set<int> _selectedServices = {0};
  final Set<int> _selectedAddons = {};
  bool _hasAllergies = false;

  int _selectedPaymentIndex = 0;
  int _selectedCardIndex = 0;
  int _selectedBankIndex = 0;

  int _frontCardIndex = 0;
  int _currentStep = 0;
  bool _isSubmitted = false;
  // 🟢 We save the ID here so the success screen can use it
  String _generatedBookingId = "";

  final List<Map<String, String>> _staffs = [
    {"name": "Adi Mawi", "specialty": "Expert Barber", "rating": "5.0", "image": "https://i.pinimg.com/736x/cc/c9/00/ccc90020bb124a04b0e466657eb7c699.jpg?q=80&w=150"},
    {"name": "Haris Iqram", "specialty": "Senior Barber", "rating": "4.9", "image": "https://i.pinimg.com/736x/dc/a6/0d/dca60d053ada15f902394178dbe9d4a0.jpg?q=80&w=150"},
    {"name": "Zabir Kaza", "specialty": "Senior Barber", "rating": "4.8", "image": "https://i.pinimg.com/736x/c5/b0/3a/c5b03a796e2ec3ad8efd12795a393fa6.jpg?q=80&w=150"},
  ];

  final List<Map<String, String>> _dates = [];

  final List<String> _times = ["8:00", "9:00", "10:00", "11:00", "12:00", "14:00", "15:00"];

  final List<Map<String, String>> _servicesList = [
    {"name": "Premium Haircut", "price": "RM35", "time": "30m"},
    {"name": "Standard Haircut", "price": "RM25", "time": "20m"},
    {"name": "Buzz Cut", "price": "RM15", "time": "15m"},
  ];

  final List<Map<String, String>> _addonsList = [
    {"name": "Hot Towel Trim", "price": "+RM20", "time": "+20m"},
    {"name": "Scalp Massage", "price": "+RM15", "time": "+15m"},
    {"name": "Hair Wash & Dry", "price": "+RM10", "time": "+10m"},
    {"name": "Beard Oil Styling", "price": "+RM5", "time": "+5m"},
    {"name": "Eyebrow Trim", "price": "+RM5", "time": "+5m"},
  ];

  final List<Map<String, dynamic>> _paymentMethods = [
    {"name": "Credit / Debit Card", "icon": Icons.credit_card_rounded, "type": "card"},
    {"name": "Online Banking (FPX)", "icon": Icons.account_balance_rounded, "type": "fpx"},
    {"name": "Cash at Counter", "icon": Icons.money_rounded, "type": "cash"},
  ];

  final List<String> _banksList = ["Maybank2u", "CIMB Clicks", "Public Bank", "RHB Now"];

  StreamSubscription<List<Map<String, dynamic>>>? _timeStream;
  String? _holdingRecordId;

  int get _totalPrice {
    int total = 0;
    for (int i in _selectedServices) { total += int.parse(_servicesList[i]["price"]!.replaceAll(RegExp(r'[^0-9]'), '')); }
    for (int i in _selectedAddons) { total += int.parse(_addonsList[i]["price"]!.replaceAll(RegExp(r'[^0-9]'), '')); }
    return total;
  }

  int get _totalTime {
    int time = 0;
    for (int i in _selectedServices) { time += int.parse(_servicesList[i]["time"]!.replaceAll(RegExp(r'[^0-9]'), '')); }
    for (int i in _selectedAddons) { time += int.parse(_addonsList[i]["time"]!.replaceAll(RegExp(r'[^0-9]'), '')); }
    return time;
  }

  String get _pageTitle {
    if (_isSubmitted) return "Booking complete!";
    if (_currentStep == 0) return "Select provider:";
    if (_currentStep == 1) return "Select Services:";
    return "Checkout & payment:";
  }

  bool _isTimeValid(String timeStr, int dateIndex) {
    if (dateIndex < 0 || dateIndex >= _dates.length) return false;

    // 🟢 THE NO FAKE HOPE CHECK: Hide it if someone else booked it!
    if (_bookedTimes.contains(timeStr)) return false;

    // Check if the time has passed today
    if (dateIndex > 0) return true;

    final now = DateTime.now();
    final parts = timeStr.split(':');
    final timeToCompare = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));

    return timeToCompare.isAfter(now);
  }

  String _shopName = '';
  String _selectedTime = '';

  // 🟢 Restored Auto-Save Functions
  Future<void> _saveDraftToPreventLoss(String shopName, String selectedTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('draft_shop_name', shopName);
    await prefs.setString('draft_selected_time', selectedTime);
  }

  Future<void> _recoverLostDraft() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = prefs.getString('draft_shop_name') ?? widget.shopName;
      _selectedTime = prefs.getString('draft_selected_time') ?? '';
    });
  }

  // 🟢 Generates 60 days (~2 months) of valid upcoming dates
  void _generateUpcomingDates() {
    final now = DateTime.now();
    final List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    _dates.clear();
    for (int i = 0; i < 90; i++) { // 🟢 Expanded to 90 days for the Calendar
      final date = now.add(Duration(days: i));
      _dates.add({
        "day": weekdays[date.weekday - 1],
        "date": date.day.toString(),
        "month": months[date.month - 1],
        "year": date.year.toString(),
        "fullDate": date.toIso8601String(), // 🟢 Required for Calendar Syncing!
      });
    }
  }

  void _selectFirstAvailableSlot() {
    for (int d = 0; d < _dates.length; d++) {
      for (int t = 0; t < _times.length; t++) {
        if (_isTimeValid(_times[t], d)) {
          setState(() {
            _selectedDateIndex = d;
            // 🟢 FIX 1: Forces the time to be unselected initially!
            _selectedTimeIndex = -1;
            _selectedTime = '';
            _selectedCalendarDate = DateTime.parse(_dates[d]['fullDate']!);
          });
          return;
        }
      }
    }
  }

  void _listenToRealtimeBookings() {
    // 🟢 Magic Stream: Updates the screen instantly if ANYONE books a slot!
    _timeStream = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('business_id', widget.shopId)
        .listen((data) {
      if (!mounted) return;
      setState(() {
        _bookedTimes = data
            .where((b) => b['status'] != 'cancelled') // Keep 'holding', 'pending', and 'confirmed' blocked
            .map<String>((booking) => booking['booking_time'].toString())
            .toList();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    // 🟢 CHANGED TO 0.85 so the left and right cards are clearly visible
    _generateUpcomingDates();
    _selectFirstAvailableSlot();
    _recoverLostDraft();
    _listenToRealtimeBookings();
  }

  @override
  void dispose() {
    _timeStream?.cancel();
    // 🟢 SAFETY CATCH: If they swipe out of the app while holding a slot, delete the lock!
    if (_holdingRecordId != null && !_isSubmitted) {
      Supabase.instance.client.from('bookings').delete().eq('id', _holdingRecordId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isFocused = _currentStep > 0 || _isSubmitted;

    List<int> orderedIndices = List.generate(_staffs.length, (i) => i);
    orderedIndices.sort((a, b) {
      int relA = (a - _frontCardIndex + _staffs.length) % _staffs.length;
      int relB = (b - _frontCardIndex + _staffs.length) % _staffs.length;
      return relB.compareTo(relA);
    });

    return Scaffold(
        backgroundColor: isDark ? const Color(0xFF13171B) : const Color(0xFFE5ECF1),
        body: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF1E242B), const Color(0xFF13171B)]
                          : [const Color(0xFFE5ECF1), const Color(0xFFD4DEE5)],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -100, left: -100,
                child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.35))),
              ),
              Positioned(
                bottom: 100, right: -50,
                child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.indigo.withValues(alpha: isDark ? 0.15 : 0.25))),
              ),
              Positioned.fill(
                child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: const SizedBox()), // 🟢 FIXED
              ),

              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  // 🟢 RESTORED: Left and Right padding! The cards are no longer infinite width.
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGlassIconBox(HugeIcons.strokeRoundedArrowLeft01, isDark, onTap: () => Navigator.pop(context)),
                          Row(
                            children: [
                              _buildGlassIconBox(HugeIcons.strokeRoundedSettings04, isDark, onTap: () {}),
                              const SizedBox(width: 12),
                              _buildGlassBadge("82", isDark),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 16),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                            _pageTitle,
                            key: ValueKey<String>(_pageTitle),
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5, color: isDark ? Colors.white : const Color(0xFF2C2C2C))
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🟢 RESTORED: THE CLASSIC VERTICAL 3D STACK
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragEnd: (DragEndDetails details) {
                          if (isFocused) return; // Locks swipe when they start checkout
                          if (details.primaryVelocity == null) return;

                          if (details.primaryVelocity! > 300) {
                            setState(() => _frontCardIndex = (_frontCardIndex + 1) % _staffs.length);
                          } else if (details.primaryVelocity! < -300) {
                            setState(() => _frontCardIndex = (_frontCardIndex - 1 + _staffs.length) % _staffs.length);
                          }
                        },
                        child: SizedBox(
                          // 🟢 THE MASTER HEIGHT: Dictates the total space available for the deck.
                          height: MediaQuery.of(context).size.height * 0.74,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            clipBehavior: Clip.none,
                            children: orderedIndices.map((index) {
                              int relativePosition = (index - _frontCardIndex + _staffs.length) % _staffs.length;

                              double top; double scale; double opacity;

                              // 🟢 RESTORED: The exact original math that creates the beautiful top stack!
                              if (relativePosition == 0) {
                                top = isFocused ? 10 : 100;
                                scale = 1.0; opacity = 1.0;
                              } else if (relativePosition == 1) {
                                top = isFocused ? 10 : 45;
                                scale = isFocused ? 0.8 : 0.9;
                                opacity = isFocused ? 0.0 : 0.9;
                              } else if (relativePosition == 2) {
                                top = isFocused ? 10 : 5;
                                scale = 0.8;
                                opacity = isFocused ? 0.0 : 0.6;
                              } else {
                                top = 5; scale = 0.8; opacity = 0.0;
                              }

                              return AnimatedPositioned(
                                key: ValueKey(index),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutQuint,
                                top: top,
                                left: 0,
                                right: 0,
                                // 🟢 THE MAGIC FIX:
                                // - If it is the Active Card (0), its bottom is ALWAYS locked to 0.
                                // - If it is an inactive card in the back, it uses the old math so the scale looks right.
                                bottom: relativePosition == 0 ? 0 : (isFocused ? 0 : -top),
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOutQuint,
                                  scale: scale,
                                  alignment: Alignment.topCenter,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 400),
                                    opacity: opacity,
                                    child: GestureDetector(
                                      onTap: () {
                                        // Brings card to front when tapped
                                        if (relativePosition != 0 && !isFocused) {
                                          setState(() => _frontCardIndex = index);
                                        }
                                      },
                                      child: AbsorbPointer(
                                        absorbing: relativePosition != 0, // Blocks accidental button clicks on back cards
                                        child: _buildExpandedGlassCard(
                                            _staffs[index],
                                            isDark,
                                            relativePosition == 0 // Only true for active card
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
    );
  }

  Widget _buildGlassBox({required Widget child, required bool isDark, double radius = 24, double opacity = 1.0, EdgeInsets? padding, double? height, double? width}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20 * opacity, sigmaY: 20 * opacity), // 🟢 FIXED
        child: Container(
          height: height,
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08 * opacity) : Colors.white.withValues(alpha: 0.5 * opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassIconBox(dynamic icon, bool isDark, {required VoidCallback onTap}) {
    return _AnimatedPressable(onTap: onTap, child: _buildGlassBox(isDark: isDark, radius: 100, height: 44, width: 44, child: Center(child: HugeIcon(icon: icon, color: isDark ? Colors.white : Colors.black87, size: 20))));
  }

  Widget _buildGlassBadge(String text, bool isDark) {
    return _AnimatedPressable(onTap: () {}, child: _buildGlassBox(isDark: isDark, radius: 100, height: 44, padding: const EdgeInsets.symmetric(horizontal: 16), child: Center(child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)))));
  }

  // 🟢 Changed 'isFocused' to 'isActiveCard'
  Widget _buildExpandedGlassCard(Map<String, String> staff, bool isDark, bool isActiveCard) {
    Widget contentSwitcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[...previousChildren, if (currentChild != null) currentChild],
        );
      },
      child: _isSubmitted ? _buildSuccessState(isDark) : _buildBookingFlow(isDark, staff, isActiveCard),
    );

    return _buildGlassBox(
      isDark: isDark,
      radius: 28,
      padding: const EdgeInsets.all(20),
      height: null,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                child: FadeTransition(opacity: animation, child: child)
            ),
            child: _currentStep == 0 && !_isSubmitted
                ? Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
                      child: CircleAvatar(backgroundImage: NetworkImage(staff["image"]!), radius: 24)
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff["name"]!, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                        Text(staff["specialty"]!, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[700])),
                      ],
                    ),
                  ),
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(staff["rating"]!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.blue)),
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),

          // Always wrap in Expanded so it fills the bottom of the card perfectly
          Expanded(child: contentSwitcher),
        ],
      ),
    );
  }

  Widget _buildBookingFlow(bool isDark, Map<String, String> staff, bool isFocused) {
    Widget stepSwitcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutQuint,
      switchOutCurve: Curves.easeInQuint,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[...previousChildren, if (currentChild != null) currentChild],
        );
      },
      child: _buildCurrentStep(isDark, staff),
    );

    return Column(
      key: const ValueKey("booking_flow"),
      // 🟢 FIX 1: Always take maximum available height from parent
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4, width: _currentStep == index ? 20 : 6,
                decoration: BoxDecoration(color: _currentStep == index ? Colors.blue : Colors.grey.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        // 🟢 FIX 2: ALWAYS wrap the content in Expanded!
        // This forces the Step contents to respect the card's boundaries and prevents the pixel overflow.
        Expanded(child: stepSwitcher),

        const SizedBox(height: 20),

        Row(
          children: [
            if (_currentStep > 0) ...[
              _AnimatedPressable(
                onTap: () async {
                  // 🟢 IF they back out of the checkout, RELEASE THE SLOT so others can book it!
                  if (_currentStep == 1 && _holdingRecordId != null) {
                    await Supabase.instance.client.from('bookings').delete().eq('id', _holdingRecordId!);
                    _holdingRecordId = null;
                  }
                  setState(() => _currentStep--);
                },
                child: Container(
                  height: 50, width: 50,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black87, size: 18)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _AnimatedPressable(
                onTap: () async {
                  // 🟢 STEP 1: CREATE THE TEMPORARY LOCK
                  if (_currentStep == 0) {
                    if (_selectedTimeIndex == -1) {
                      showGlassToast(context, "Please select an available time slot.", isError: true);
                      return;
                    }

                    final String targetDate = _dates[_selectedDateIndex]['fullDate']!.substring(0, 10);
                    final String targetTime = _times[_selectedTimeIndex];

                    try {
                      // Insert a 'holding' record to claim the slot instantly!
                      final holdResponse = await Supabase.instance.client.from('bookings').insert({
                        'business_id': widget.shopId,
                        'customer_name': UserData.userName.value.isNotEmpty ? UserData.userName.value : 'Guest',
                        'service_name': 'Holding...',
                        'booking_date': targetDate,
                        'booking_time': targetTime,
                        'status': 'holding', // 🟢 Locks the slot for everyone else!
                        'pax': 1,
                        'booking_metadata': { 'customer_auth_id': Supabase.instance.client.auth.currentUser!.id }
                      }).select().single();

                      _holdingRecordId = holdResponse['id'].toString();
                      setState(() => _currentStep++);
                    } catch (e) {
                      showGlassToast(context, "Slot just got taken by someone else! Try another.", isError: true);
                    }

                  } else if (_currentStep == 1) {
                    setState(() => _currentStep++);
                  } else {

                    // 🟢 STEP 3: FINALIZE CHECKOUT
                    if (_selectedPaymentIndex == 0) {
                      final hasCards = UserData.savedPaymentMethods.value.any((m) => m["type"] == "card");
                      if (!hasCards) {
                        showGlassToast(context, "Please add a Credit or Debit Card first.", isError: true);
                        return;
                      }
                    }

                    // Generate Short ID
                    final dt = DateTime.now();
                    final datePart = "${dt.year.toString().substring(2)}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}";
                    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                    final rnd = Random();
                    final randomPart = String.fromCharCodes(Iterable.generate(5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
                    final String shortBookingId = "RZRV-$datePart-$randomPart";

                    try {
                      // 🟢 UPDATE the existing lock to 'pending' with all the final details!
                      await Supabase.instance.client.from('bookings').update({
                        'service_name': _servicesList[_selectedServices.first]["name"]!,
                        'status': 'pending',
                        'booking_metadata': {
                          'short_ref': shortBookingId, // For your UI
                          'booking_id': shortBookingId, // For the MyRezrvView sync
                          'customer_auth_id': Supabase.instance.client.auth.currentUser!.id,
                          'provider_name': staff["name"],
                          'total_price': "RM$_totalPrice",
                          // 🟢 Save Shop details so MyRezrvView can display them directly from the DB!
                          'shop_name': widget.shopName,
                          'shop_image': widget.shopImage,
                          'category': widget.category
                        }
                      }).eq('id', _holdingRecordId!);

                      final dateStr = "${_dates[_selectedDateIndex]['day']}, ${_dates[_selectedDateIndex]['date']} ${_dates[_selectedDateIndex]['month']}";
                      final timeStr = _times[_selectedTimeIndex];

                      LocalNotificationService.showBookingConfirmed(
                        shopName: widget.shopName, category: widget.category, shopImage: widget.shopImage,
                        providerName: staff["name"]!, date: dateStr, time: timeStr, totalPrice: "RM$_totalPrice", bookingId: shortBookingId,
                      );

                      setState(() {
                        _generatedBookingId = shortBookingId;
                        _isSubmitted = true;
                      });

                    } catch (e) {
                      showGlassToast(context, "Failed to confirm payment. Try again.", isError: true);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1976D2)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 6), spreadRadius: 1)],
                  ),
                  child: Center(
                      child: Text(
                          _currentStep < 2 ? "Continue" : "Confirm & Pay RM$_totalPrice",
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)
                      )
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentStep(bool isDark, Map<String, String> staff) {
    if (_currentStep == 0) return _buildStepOneTimeSelection(isDark);
    if (_currentStep == 1) return _buildStepTwoServicesAndAddons(isDark);
    return _buildStepThreeCheckout(isDark, staff);
  }

  void _showAddCardSheet(BuildContext context, bool isDark) {
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    final expiryController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E242B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4), width: 1.5)),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(height: 16),
                        Text("Add Credit/Debit Card", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        _buildPremiumInput(isDark: isDark, label: "Card Number", hint: "0000 0000 0000 0000", icon: HugeIcons.strokeRoundedCreditCard, controller: numberController, keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter(), LengthLimitingTextInputFormatter(19)], validator: (value) {
                          if (value == null) return "Invalid";
                          if (value.replaceAll(' ', '').length != 16 && value.replaceAll(' ', '').length != 15) return "Invalid Length";
                          return null;
                        }),
                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                flex: 3,
                                child: _buildPremiumInput(
                                    isDark: isDark, label: "Card Holder", hint: "NAME ON CARD", icon: HugeIcons.strokeRoundedUser, controller: nameController, keyboardType: TextInputType.name, textCapitalization: TextCapitalization.characters,
                                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), _UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(26)],
                                    validator: (value) { if (value == null || value.trim().isEmpty) return "Cannot be empty"; return null; }
                                )
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                flex: 2,
                                child: _buildPremiumInput(isDark: isDark, label: "Expiry", hint: "MM/YY", icon: HugeIcons.strokeRoundedCalendar01, controller: expiryController, keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryDateFormatter(), LengthLimitingTextInputFormatter(5)], validator: (value) {
                                  if (value == null || !RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(value)) return "Invalid date";
                                  return null;
                                })
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        _AnimatedPressable(
                          onTap: () {
                            if (formKey.currentState!.validate()) {
                              final rawDigits = numberController.text.replaceAll(' ', '');
                              String detectedBrand = 'CARD';
                              if (rawDigits.startsWith('4')) detectedBrand = 'VISA';
                              if (rawDigits.startsWith('5')) detectedBrand = 'MASTERCARD';
                              if (rawDigits.startsWith('34') || rawDigits.startsWith('37')) detectedBrand = 'AMEX';

                              UserData.addPaymentMethod({
                                "id": DateTime.now().millisecondsSinceEpoch.toString(),
                                "type": "card",
                                "name": detectedBrand,
                                "number": "**** **** **** ${rawDigits.length >= 4 ? rawDigits.substring(rawDigits.length - 4) : "0000"}",
                                "holder": nameController.text.toUpperCase(),
                                "expiry": expiryController.text,
                                "isPrimary": false,
                              });

                              setState(() {
                                _selectedPaymentIndex = 0;
                                _selectedCardIndex = 0;
                              });

                              Navigator.pop(context);
                            }
                          },
                          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]), child: const Center(child: Text("Save Card", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddBankSheet(BuildContext context, bool isDark) {
    final accountController = TextEditingController();
    final nameController = TextEditingController();
    String selectedBank = _banksList.first;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E242B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
                        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.4), width: 1.5)),
                      ),
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
                              const SizedBox(height: 16),
                              Text("Link Bank Account", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("SELECT BANK", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14)),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedBank,
                                        isExpanded: true,
                                        dropdownColor: isDark ? const Color(0xFF262626) : Colors.white,
                                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : Colors.black54),
                                        items: _banksList.map((String bank) {
                                          return DropdownMenuItem<String>(
                                              value: bank,
                                              child: Text(bank, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 14))
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) { setSheetState(() => selectedBank = newValue!); },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              _buildPremiumInput(isDark: isDark, label: "Account Number", hint: "Enter bank account number", icon: HugeIcons.strokeRoundedTaskEdit01, controller: accountController, keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], validator: (value) { if (value == null || value.length < 8) return "Invalid account number"; return null; }),
                              const SizedBox(height: 12),

                              _buildPremiumInput(isDark: isDark, label: "Account Holder Name", hint: "AS REGISTERED WITH BANK", icon: HugeIcons.strokeRoundedUser, controller: nameController, keyboardType: TextInputType.name, textCapitalization: TextCapitalization.characters, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')), _UpperCaseTextFormatter()], validator: (value) { if (value == null || value.trim().isEmpty) return "Cannot be empty"; return null; }),

                              const SizedBox(height: 24),

                              _AnimatedPressable(
                                onTap: () {
                                  if (formKey.currentState!.validate()) {
                                    String accRaw = accountController.text;
                                    String masked = "•••• ${accRaw.substring(accRaw.length - 4)}";

                                    UserData.addPaymentMethod({
                                      "id": DateTime.now().millisecondsSinceEpoch.toString(),
                                      "type": "bank",
                                      "name": selectedBank,
                                      "number": masked,
                                      "holder": nameController.text.toUpperCase(),
                                      "expiry": null,
                                      "isPrimary": false,
                                    });
                                    Navigator.pop(context);
                                  }
                                },
                                child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]), child: const Center(child: Text("Link Account", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildPremiumInput({required bool isDark, required String label, required String hint, required dynamic icon, required TextEditingController controller, TextInputType? keyboardType, List<TextInputFormatter>? formatters, TextCapitalization? textCapitalization, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14)),
          child: TextFormField(
            controller: controller, keyboardType: keyboardType, inputFormatters: formatters, validator: validator, textCapitalization: textCapitalization ?? TextCapitalization.none,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontWeight: FontWeight.normal, fontSize: 13),
              prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 14.0), child: HugeIcon(icon: icon, color: Colors.grey, size: 16)),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36), border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepOneTimeSelection(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 89));

    // Extracts the currently selected date strings for the bright header
    String selDay = _dates[_selectedDateIndex]['day']!;
    String selDate = _dates[_selectedDateIndex]['date']!;
    String selMonth = _dates[_selectedDateIndex]['month']!;

    // Initialize displayed month to match the selected calendar date
    DateTime displayedMonth = DateTime(_selectedCalendarDate.year, _selectedCalendarDate.month, 1);
    final List<String> monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    final List<String> shortDays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];

    return SingleChildScrollView(
      key: const ValueKey(0),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      child: StatefulBuilder(
          builder: (context, setLocalState) {
            int daysInMonth = DateUtils.getDaysInMonth(displayedMonth.year, displayedMonth.month);
            int firstWeekday = DateTime(displayedMonth.year, displayedMonth.month, 1).weekday; // 1 = Monday

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟢 DUAL CONFIRMATION HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l10n.bkApptDate, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                    Text(
                        "$selDay, $selDate $selMonth",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.blueAccent)
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 🟢 FULLY CUSTOM PREMIUM GLASS CALENDAR
                _buildGlassBox(
                  isDark: isDark,
                  radius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // --- MONTH NAVIGATION HEADER ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              DateTime prev = DateTime(displayedMonth.year, displayedMonth.month - 1, 1);
                              if (prev.isAfter(DateTime(now.year, now.month - 1, 28))) {
                                setLocalState(() => displayedMonth = prev);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                              child: Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
                            ),
                          ),
                          Text(
                            "${monthNames[displayedMonth.month - 1]} ${displayedMonth.year}",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          ),
                          GestureDetector(
                            onTap: () {
                              DateTime next = DateTime(displayedMonth.year, displayedMonth.month + 1, 1);
                              if (next.isBefore(maxDate.add(const Duration(days: 30)))) {
                                setLocalState(() => displayedMonth = next);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                              child: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- DAYS OF THE WEEK ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: shortDays.map((day) => Expanded(
                          child: Center(child: Text(day, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54))),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),

                      // --- THE CUSTOM DATE GRID ---
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: daysInMonth + firstWeekday - 1,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, index) {
                          if (index < firstWeekday - 1) return const SizedBox.shrink(); // Empty day slot before the 1st

                          int day = index - (firstWeekday - 1) + 1;
                          DateTime thisDate = DateTime(displayedMonth.year, displayedMonth.month, day);

                          DateTime pureThisDate = DateTime(thisDate.year, thisDate.month, thisDate.day);
                          DateTime pureNow = DateTime(now.year, now.month, now.day);
                          DateTime pureSelected = DateTime(_selectedCalendarDate.year, _selectedCalendarDate.month, _selectedCalendarDate.day);

                          bool isSelected = pureSelected == pureThisDate;
                          bool isPast = pureThisDate.isBefore(pureNow) || pureThisDate.isAfter(maxDate);

                          return GestureDetector(
                            onTap: isPast ? null : () {
                              setState(() {
                                _selectedCalendarDate = thisDate;

                                final targetString = thisDate.toIso8601String().substring(0, 10);
                                _selectedDateIndex = _dates.indexWhere((d) => d['fullDate']!.substring(0, 10) == targetString);
                                if (_selectedDateIndex == -1) _selectedDateIndex = 0;

                                // 🟢 FIX 2: Completely clear the time selection when a new date is tapped!
                                // (Removed the for-loop that used to auto-select a time here)
                                _selectedTimeIndex = -1;
                                _selectedTime = '';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blueAccent : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  // 🟢 THE FIX: Transparent border for inactive dates! Only the active one gets the blue ring.
                                    color: isSelected ? Colors.blueAccent : Colors.transparent,
                                    width: 1.5
                                ),
                                boxShadow: isSelected ? [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 1)] : [],
                              ),
                              child: Center(
                                child: Text(
                                  day.toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.white : (isPast ? (isDark ? Colors.white30 : Colors.black26) : (isDark ? Colors.white : Colors.black87)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                Text(l10n.bkAvailTime, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 12),

                // 🟢 HORIZONTAL TIME SCROLL
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  child: Row(
                    children: List.generate(_times.length, (i) {
                      bool isValid = _isTimeValid(_times[i], _selectedDateIndex);

                      if (!isValid) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                            ),
                            child: Center(
                                child: Text(_times[i], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white24 : Colors.black26))
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _buildScrollTimeChip(_times[i], i == _selectedTimeIndex, isDark, i),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            );
          }
      ),
    );
  }

  // 🟢 REDESIGNED WIDE TIME CHIP
  Widget _buildTimeChip(String time, bool isSelected, bool isDark, int index) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTimeIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), // Gives the pill shape
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white.withValues(alpha: isDark ? 0.1 : 0.6), width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 0)] : [],
        ),
        child: Text(time, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
      ),
    );
  }

  // 🟢 NEW HELPER: Designed for the Horizontal Scroll layout
  Widget _buildScrollTimeChip(String time, bool isSelected, bool isDark, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeIndex = index;
          _selectedTime = time;
          _shopName = widget.shopName;
        });
        _saveDraftToPreventLoss(_shopName, _selectedTime);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // 🟢 Padding gives the chip its shape in a Row!
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white.withValues(alpha: isDark ? 0.1 : 0.6), width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 0)] : [],
        ),
        child: Center(
          child: Text(
              time,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)
              )
          ),
        ),
      ),
    );
  }

  Widget _buildStepTwoServicesAndAddons(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Main Service", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Column(children: List.generate(_servicesList.length, (index) => _buildSelectionTile(_servicesList[index], index, isDark, _selectedServices, false))),

          const SizedBox(height: 24),

          Text("Extra Add-ons", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Column(children: List.generate(_addonsList.length, (index) => _buildSelectionTile(_addonsList[index], index, isDark, _selectedAddons, true))),

          const SizedBox(height: 24),
          Text("Health & Safety", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text("Skin allergies or sensitivities?", style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87))),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _hasAllergies, activeColor: Colors.blue, activeTrackColor: Colors.blue.withValues(alpha: 0.3), inactiveThumbColor: isDark ? Colors.grey[400] : Colors.grey[300], inactiveTrackColor: isDark ? Colors.white10 : Colors.black12, onChanged: (val) => setState(() => _hasAllergies = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildStepThreeCheckout(bool isDark, Map<String, String> staff) {
    return SingleChildScrollView(
      key: const ValueKey(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Booking Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._selectedServices.map((i) => _buildReceiptRow(_servicesList[i]["name"]!, _servicesList[i]["price"]!, isDark)).toList(),
                ..._selectedAddons.map((i) => _buildReceiptRow(_addonsList[i]["name"]!, _addonsList[i]["price"]!.replaceAll('+', ''), isDark)).toList(),

                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2))
                ),

                _buildSummaryRow("Location", widget.shopName, Icons.storefront, isDark),
                const SizedBox(height: 12),
                _buildSummaryRow("Provider", staff["name"]!, Icons.person, isDark),
                const SizedBox(height: 12),
                _buildSummaryRow("Date", "${_dates[_selectedDateIndex]['day']}, ${_dates[_selectedDateIndex]['date']} ${_dates[_selectedDateIndex]['month']}", Icons.calendar_month, isDark),                const SizedBox(height: 12),
                _buildSummaryRow("Time", _times[_selectedTimeIndex], Icons.access_time_filled, isDark),

                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2))
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Estimated Duration", style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
                    Text("~$_totalTime mins", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text("Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),

          // 🟢 CLASSIC 3-METHOD LAYOUT (FIXED OVERFLOW)
          Column(
            children: List.generate(_paymentMethods.length, (i) {
              bool isSel = _selectedPaymentIndex == i;
              String pType = _paymentMethods[i]["type"];

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSel ? Colors.blue.withValues(alpha: 0.05) : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSel ? Colors.blue : Colors.white.withValues(alpha: isDark ? 0.05 : 0.6), width: 1.5),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (i == 0) {
                          final hasCards = UserData.savedPaymentMethods.value.any((m) => m["type"] == "card");
                          if (!hasCards) {
                            _showAddCardSheet(context, isDark);
                            return;
                          }
                        }
                        setState(() => _selectedPaymentIndex = i);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Icon(_paymentMethods[i]["icon"], color: isSel ? Colors.blue : (isDark ? Colors.white60 : Colors.black54), size: 22),
                            const SizedBox(width: 12),
                            // 🟢 FIXED: Wrapped in Expanded to prevent title overflow
                            Expanded(
                              child: Text(
                                _paymentMethods[i]["name"],
                                style: TextStyle(fontSize: 15, fontWeight: isSel ? FontWeight.bold : FontWeight.w600, color: isSel ? Colors.blue : (isDark ? Colors.white70 : Colors.black87)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                                isSel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: isSel ? Colors.blue : (isDark ? Colors.white30 : Colors.black26),
                                size: 20
                            ),
                          ],
                        ),
                      ),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: (isSel && pType != "cash")
                          ? Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: pType == "card"

                            ? ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: UserData.savedPaymentMethods,
                          builder: (context, allMethods, _) {
                            final cardMethods = allMethods.where((m) => m["type"] == "card").toList();

                            if (cardMethods.isEmpty) {
                              return _AnimatedPressable(
                                onTap: () => _showAddCardSheet(context, isDark),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.3))),
                                  child: const Center(child: Text("+ Add New Card", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                                ),
                              );
                            }
                            return Column(
                              children: List.generate(cardMethods.length, (subIndex) {
                                bool isSubSel = _selectedCardIndex == subIndex;

                                // 🟢 FIXED: Grab only the last 4 digits for a clean, short display!
                                final method = cardMethods[subIndex];
                                final rawNumber = method["number"].toString();
                                final last4 = rawNumber.length >= 4 ? rawNumber.substring(rawNumber.length - 4) : "0000";
                                String itemName = "${method["name"]}  **** $last4";

                                return GestureDetector(
                                  onTap: () => setState(() => _selectedCardIndex = subIndex),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: isSubSel ? Colors.blue.withValues(alpha: 0.15) : (isDark ? Colors.black26 : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSubSel ? Colors.blue.withValues(alpha: 0.5) : Colors.transparent),
                                    ),
                                    child: Row(
                                      children: [
                                        // 🟢 Clean and short text (e.g., "VISA  •••• 1234")
                                        Text(
                                            itemName,
                                            style: TextStyle(fontSize: 14, fontWeight: isSubSel ? FontWeight.w600 : FontWeight.normal, color: isDark ? Colors.white : Colors.black87)
                                        ),
                                        const Spacer(),
                                        if (isSubSel) const Icon(Icons.check, color: Colors.blue, size: 16)
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        )

                            : Column(
                          children: List.generate(_banksList.length, (subIndex) {
                            bool isSubSel = _selectedBankIndex == subIndex;
                            String itemName = _banksList[subIndex];

                            return GestureDetector(
                              onTap: () => setState(() => _selectedBankIndex = subIndex),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isSubSel ? Colors.blue.withValues(alpha: 0.15) : (isDark ? Colors.black26 : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSubSel ? Colors.blue.withValues(alpha: 0.5) : Colors.transparent),
                                ),
                                child: Row(
                                  children: [
                                    // 🟢 FIXED: Wrapped in Expanded to stop Bank Name overflow
                                    Expanded(
                                      child: Text(
                                        itemName,
                                        style: TextStyle(fontSize: 14, fontWeight: isSubSel ? FontWeight.w600 : FontWeight.normal, color: isDark ? Colors.white : Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isSubSel) const Icon(Icons.check, color: Colors.blue, size: 16) else const SizedBox(width: 16)
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      )
                          : const SizedBox.shrink(),
                    )
                  ],
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Grand Total", style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54)),
              Text("RM$_totalPrice", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.0, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // 🟢 NEW HELPER: Renders the payment cards
  Widget _buildSavedCardWidget(Map<String, dynamic> method, bool isDark, bool isPrimary, bool isSelected) {
    if (isPrimary) {
      return Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1976D2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const HugeIcon(icon: HugeIcons.strokeRoundedBitcoinSquare, color: Colors.white70, size: 24),
                Text(method["name"], style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
              ],
            ),
            Text(method["number"], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 2.0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Card Holder", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)), Text(method["holder"], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Expires", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10)), Text(method["expiry"], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
              ],
            )
          ],
        ),
      );
    } else {
      bool isBank = method["type"] == "bank";
      return Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : Border.all(color: isDark ? Colors.white12 : Colors.black12),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: (isBank ? Colors.green : Colors.orange).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: HugeIcon(icon: isBank ? HugeIcons.strokeRoundedBank : HugeIcons.strokeRoundedCreditCard, color: isBank ? Colors.green : Colors.orange, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(method["name"], style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(method["number"], style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14)),
                    ],
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 28)
              ],
            )
          ],
        ),
      );
    }
  }

  Widget _buildReceiptRow(String title, String price, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
          Text(price, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String val, IconData icon, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
        const SizedBox(width: 16),
        // 🟢 FIXED: Wrapped in Expanded to allow long shop names to drop to the next line safely
        Expanded(
          child: Text(
            val,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 🟢 FIXED: The success screen now shows the proper "View Order" button
  Widget _buildSuccessState(bool isDark) {
    return Center(
      key: const ValueKey("success_state"),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 100, width: 100,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.2), shape: BoxShape.circle,
                    border: Border.all(color: Colors.greenAccent, width: 3),
                    boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: const Center(child: Icon(Icons.check_rounded, color: Colors.greenAccent, size: 50)),
                ),
                const SizedBox(height: 32),
                Text("Booking Confirmed!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text("Your provider has been notified.", style: TextStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.black54)),
                const SizedBox(height: 40),

                // Button to open the ticket immediately after booking
                _AnimatedPressable(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingTicketScreen(
                          shopId: widget.shopId, // 🟢 ADD THIS LINE!
                          shopName: widget.shopName,
                          category: widget.category,
                          shopImage: widget.shopImage,
                          providerName: _staffs[_frontCardIndex]["name"]!,
                          date: "${_dates[_selectedDateIndex]['day']}, ${_dates[_selectedDateIndex]['date']} ${_dates[_selectedDateIndex]['month']}",
                          time: _times[_selectedTimeIndex],
                          totalPrice: "RM$_totalPrice",
                          bookingId: _generatedBookingId,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
                    decoration: BoxDecoration(color: isDark ? Colors.white : Colors.black87, borderRadius: BorderRadius.circular(20)),
                    child: Text("View Order", style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 16),

                // Simple text button to go back
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text("Back to Home", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w600)),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateChip(String day, String date, String month, bool isSelected, bool isDark, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDateIndex = index;

          // 🟢 If the currently selected time is invalid for this new day, auto-select the first valid one
          if (_selectedTimeIndex == -1 || !_isTimeValid(_times[_selectedTimeIndex], index)) {
            _selectedTimeIndex = -1;
            _selectedTime = '';
            for (int t = 0; t < _times.length; t++) {
              if (_isTimeValid(_times[t], index)) {
                _selectedTimeIndex = t;
                _selectedTime = _times[t];
                break;
              }
            }
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white.withValues(alpha: isDark ? 0.1 : 0.6), width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 0)] : [],
        ),
        child: Column(
          children: [
            Text(month.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white70 : Colors.blue)), // 🟢 Added Month
            const SizedBox(height: 2),
            Text(date, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black))),
            const SizedBox(height: 2),
            Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isSelected ? Colors.white70 : (isDark ? Colors.white54 : Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile(Map<String, String> item, int index, bool isDark, Set<int> stateSet, bool isMultiSelect) {
    bool isSelected = stateSet.contains(index);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isMultiSelect) {
            if (isSelected) stateSet.remove(index); else stateSet.add(index);
          } else {
            stateSet.clear(); stateSet.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? Colors.blue : Colors.white.withValues(alpha: isDark ? 0.05 : 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(isSelected ? (isMultiSelect ? Icons.check_box_rounded : Icons.radio_button_checked) : (isMultiSelect ? Icons.check_box_outline_blank_rounded : Icons.radio_button_unchecked), color: isSelected ? Colors.blue : (isDark ? Colors.white54 : Colors.black54), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(item["name"]!, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
            Text("${item["time"]} • ${item["price"]}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.blue : (isDark ? Colors.white60 : Colors.black54))),
          ],
        ),
      ),
    );
  }
}

class _AnimatedPressable extends StatefulWidget {
  final Widget child; final VoidCallback onTap;
  const _AnimatedPressable({required this.child, required this.onTap});
  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}
class _AnimatedPressableState extends State<_AnimatedPressable> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _s = Tween<double>(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTapDown: (_) => _c.forward(),
        onTapUp: (_) { _c.reverse(); widget.onTap(); },
        onTapCancel: () => _c.reverse(),
        child: ScaleTransition(scale: _s, child: widget.child));
  }
}

// ==========================================
// FORMATTERS
// ==========================================

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    String newString = '';
    for (int i = 0; i < text.length; i++) { if (i > 0 && i % 4 == 0) newString += ' '; newString += text[i]; }
    return TextEditingValue(text: newString, selection: TextSelection.collapsed(offset: newString.length));
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) return newValue.copyWith(text: '');
    String newString = '';
    for (int i = 0; i < text.length; i++) { if (i == 2) newString += '/'; newString += text[i]; }
    return TextEditingValue(text: newString, selection: TextSelection.collapsed(offset: newString.length));
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
