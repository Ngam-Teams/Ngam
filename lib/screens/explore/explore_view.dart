import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'bookings_view.dart';
import 'dart:math';
import 'package:ngam/l10n/generated/app_localizations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'shop_detail_screen.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import '../../widgets/glass_toast.dart';
import '../auth/login_screen.dart'; // Make sure this matches your auth screen file name
import 'package:supabase_flutter/supabase_flutter.dart'; 

enum ShopStatus { open, closingSoon, closed }

class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

// REMOVED WidgetsBindingObserver here
class _ExploreViewState extends State<ExploreView> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  void _initAI() {
    _flutterTts = FlutterTts();
    _flutterTts?.setSpeechRate(0.4);
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted && _aiInlineIsListening) {
              setState(() => _aiInlineIsListening = false);
              if (_aiInlineRecognizedWords.isNotEmpty) {
                _aiHandleSend(_aiInlineRecognizedWords);
              }
            }
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Speech initialization error: $e");
    }
  }
  
  void _aiScrollToBottom({bool force = false}) {
    if (!_aiScrollController.hasClients) return;
    bool nearBottom = _aiScrollController.position.maxScrollExtent - _aiScrollController.offset <= 150;
    if (force || nearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_aiScrollController.hasClients) {
          _aiScrollController.animateTo(
            _aiScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _toggleAIVoiceInline() async {
    if (!_speechEnabled) {
      setState(() => _aiChatHistory.add({"role": "system", "message": "Sila benarkan akses mikrofon."}));
      return;
    }
    if (_aiInlineIsListening) {
      _speechToText.stop();
      setState(() => _aiInlineIsListening = false);
    } else {
      _aiInlineRecognizedWords = "";
      setState(() => _aiInlineIsListening = true);
      _speechToText.listen(
        onResult: (val) {
          setState(() {
            _aiInlineRecognizedWords = val.recognizedWords;
          });
        },
        localeId: 'ms_MY',
      );
    }
  }
  
  String _aiSearchByKeyword(String? keyword, {String sortBy = 'distance', String? focusedShopId}) {
    if (!mounted) return "";
    setState(() {
      if (keyword != null && keyword.isNotEmpty) {
        _searchController.text = keyword;
        _activeSearchQuery = keyword;
        _isSearchPanelOpen = true;
        _handleSearch(keyword);
      } else {
        _searchController.clear();
        _activeSearchQuery = null;
        _handleSearch('');
      }
    });

    int count = _displayedShops.length;
    return "$count kedai/servis dijumpai";
  }

  Future<void> _aiHandleSend(String text) async {
    if (text.trim().isEmpty) return;
    final isMalay = true;
    setState(() {
      _aiChatHistory.add({"role": "user", "message": text});
      _aiIsTyping = true;
      _isAIPanelOpen = true;
      _aiInlineIsListening = false;
    });
    _aiInputController.clear();
    _aiScrollToBottom(force: true);

    try {
      await dotenv.load();
      final apiKey = dotenv.env['NVIDIA_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        setState(() {
          _aiIsTyping = false;
          _aiChatHistory.add({"role": "ai", "message": "Maaf, API Key tidak dijumpai."});
        });
        _aiScrollToBottom();
        return;
      }

      final allShops = List<Map<String, dynamic>>.from(_nearbyShops);
      final currentLoc = _currentLocation;
      
      final StringBuffer shopList = StringBuffer();
      int count = 0;
      for (var shop in allShops.take(20)) {
        shopList.writeln('- [' + shop['category'] + '] ' + shop['name'] + ' | ID: ' + shop['id']);
        count++;
      }
      final jobContext = count > 0
          ? 'There are ' + count.toString() + ' available shops right now:\n' + shopList.toString()
          : 'There are no available shops listed right now.';

      final messages = [
        {
          "role": "system",
          "content": """You are a smart, friendly AI assistant for Ngam app.
LIVE CUSTOMER SHOP DATA:
$jobContext

YOUR JOB:
- Help the user find a shop, salon, or service.
- You understand Malay and English.
- Keep message EXTREMELY concise (max 2 short sentences).

RESPONSE FORMAT (JSON ONLY):
{
  "message": "Your reply",
  "search_keyword": "One exact substring to search, or null"
}"""
        }
      ];

      for (var msg in _aiChatHistory) {
        String role = msg['role'] == 'ai' ? 'assistant' : 'user';
        String content = msg['message'] as String;
        if (msg['role'] == 'ai') {
          content = '{"message": "' + content.replaceAll('"', '\\"') + '", "search_keyword": null}';
        }
        if (msg['role'] != 'system_context') {
           messages.add({"role": role, "content": content});
        }
      }

      final response = await http.post(
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({"model": "meta/llama-3.1-8b-instruct", "messages": messages, "temperature": 0.4, "max_tokens": 200, "response_format": {"type": "json_object"}}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawReply = data['choices'][0]['message']['content'];
        String aiMessage = rawReply;
        String? searchKeyword;
        try {
          final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(rawReply);
          if (jsonMatch != null) {
            final parsed = jsonDecode(jsonMatch.group(0)!);
            aiMessage = (parsed['message']?.toString() ?? rawReply);
            final kw = parsed['search_keyword'];
            if (kw is String && kw.toLowerCase() != 'null' && kw.trim().isNotEmpty) {
              searchKeyword = kw.trim();
            }
          }
        } catch (_) {
          aiMessage = rawReply;
        }

        String resultSummary = _aiSearchByKeyword(searchKeyword);
        
        if (mounted) {
          setState(() {
            _aiIsTyping = false;
            _aiChatHistory.add({"role": "ai", "message": aiMessage});
          });
          _aiScrollToBottom(force: true);
          _flutterTts?.speak(aiMessage);
        }
      } else {
        setState(() {
          _aiIsTyping = false;
          _aiChatHistory.add({"role": "ai", "message": "Maaf, ralat pelayan: ${response.statusCode}"});
        });
      }
    } catch (e) {
      setState(() {
        _aiIsTyping = false;
        _aiChatHistory.add({"role": "ai", "message": "Ralat rangkaian."});
      });
    }
  }

  Widget _buildAIChatPanel(bool isDark) {
    if (!_isAIPanelOpen) return const SizedBox.shrink();
    return Positioned(
      bottom: 90,
      left: 16,
      right: 16,
      child: _buildGlassBox(
        isDark: isDark,
        radius: 24,
        child: Container(
          height: 380,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const HugeIcon(icon: HugeIcons.strokeRoundedSparkles, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text("Ngam AI", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54),
                    onPressed: () => setState(() => _isAIPanelOpen = false),
                  )
                ],
              ),
              const Divider(color: Colors.blueAccent, thickness: 0.3),
              Expanded(
                child: ListView.builder(
                  controller: _aiScrollController,
                  itemCount: _aiChatHistory.length,
                  itemBuilder: (context, index) {
                    final msg = _aiChatHistory[index];
                    if (msg['role'] == 'system' || msg['role'] == 'system_context') return const SizedBox.shrink();
                    final isUser = msg['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blue.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isUser ? Colors.blue.withValues(alpha: 0.3) : Colors.transparent),
                        ),
                        child: Text(msg['message'], style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                      ),
                    );
                  },
                ),
              ),
              if (_aiIsTyping) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
                ),
                child: TextField(
                  controller: _aiInputController,
                  onSubmitted: _aiHandleSend,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(
                    hintText: 'Taip mesej...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }


  final MapController _mapController = MapController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  Timer? _minuteTicker;

  final Color _lightModeGray = const Color(0xFF3A3A3C);

  // State untuk AI panel
  bool _isAIPanelOpen = false;
  final List<Map<String, dynamic>> _aiChatHistory = [];
  bool _aiIsTyping = false;
  bool _aiShouldReopenMic = true;
  FlutterTts? _flutterTts;
  final TextEditingController _aiInputController = TextEditingController();
  final ScrollController _aiScrollController = ScrollController();
  bool _aiInlineIsListening = false;
  String _aiInlineRecognizedWords = "";
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isSearchPanelOpen = false;
  bool _isMapReady = false;
  bool _isMapLocked = false;
  final double _baseLatitudeOffset = -0.0055;

  double get _adaptiveOffset {
    double currentZoom = _mapController.camera.zoom;
    // Formula: Offset * 2^(BaseZoom - CurrentZoom)
    return _baseLatitudeOffset * pow(2, 14.0 - currentZoom);
  }

  String _formatTime(int hour, int minute) {
    final String period = hour >= 12 ? "PM" : "AM";
    int h = hour % 12;
    if (h == 0) h = 12;
    return "${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(
        2, '0')} $period";
  }

  // --- 1. CONTROLLERS & TIMERS ---
  late PageController _pageController;
  Timer? _snapBackTimer;
  Timer? _debounce;
  StreamSubscription<Position>? _positionStream;

  // --- 2. STATE VARIABLES ---
  LatLng _currentLocation = const LatLng(3.1390, 101.6869);
  bool _followUser = true;
  bool _isSearching = false;
  bool _isProfileOpen = false;

  Map<String, dynamic>? _selectedShop;
  int _currentCarouselIndex = 0;
  List<Map<String, dynamic>> _nearbyShops = [];
  List<Map<String, dynamic>> _displayedShops = []; // 🟢 Added this back!
  String? _activeSearchQuery;

  // --- NEW: ADVANCED SEARCH STATE ---
  Set<String> _expandedCategories = {};
  List<Map<String, dynamic>> _searchMatchedCategories = [];
  List<Map<String, dynamic>> _searchMatchedShops = [];

  List<Map<String, dynamic>> _realShops = [];

  List<Map<String, dynamic>> _getCategoryTree(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {
        'label': l10n.exploreCatBeauty,
        'id': 'group_beauty',
        'icon': HugeIcons.strokeRoundedScissor,
        'sub': [
          {'label': l10n.exploreCatBarber, 'id': 'barber'},
          {'label': l10n.exploreCatHealth, 'id': 'health'},
        ]
      },
      {
        'label': l10n.exploreCatFood,
        'id': 'group_food',
        'icon': HugeIcons.strokeRoundedRestaurant01,
        'sub': [
          {'label': l10n.exploreCatRestaurant, 'id': 'food'},
          {'label': l10n.exploreCatCafe, 'id': 'cafe'},
        ]
      },
      {
        'label': l10n.exploreCatAuto,
        'id': 'group_auto',
        'icon': HugeIcons.strokeRoundedCar01,
        'sub': [
          {'label': l10n.exploreCatWorkshop, 'id': 'workshop'},
          {'label': l10n.exploreCatGas, 'id': 'gas'},
        ]
      },
      {
        'label': l10n.exploreCatDaily,
        'id': 'group_daily',
        'icon': HugeIcons.strokeRoundedShoppingBasket01,
        'sub': [
          {'label': l10n.exploreCatSupermarket, 'id': 'market'},
          {'label': l10n.exploreCatBanking, 'id': 'bank'},
        ]
      },
      {
        'label': l10n.exploreCatCommunity,
        'id': 'group_community',
        'icon': HugeIcons.strokeRoundedMosque02,
        'sub': [
          {'label': l10n.exploreCatSchool, 'id': 'school'},
          {'label': l10n.exploreCatReligion, 'id': 'religion'},
        ]
      }
    ];
  }

  LatLng _getDynamicCenterOffset(Map<String, dynamic> shop, double targetZoom) {
    // 1. Get screen dimensions
    final double screenHeight = MediaQuery
        .of(context)
        .size
        .height;
    final double screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final double topSafeArea = MediaQuery
        .of(context)
        .padding
        .top;
    final double bottomSafeArea = MediaQuery
        .of(context)
        .padding
        .bottom;

    // 2. Predict the exact height of the bottom sheet (mirroring your modal logic)
    double textAvailableWidth = screenWidth - 108;
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
          text: shop['name'],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )
      ..layout(maxWidth: textAvailableWidth);

    // --- APPLY THE EXACT SAME FIX HERE ---
    int numLines = textPainter
        .computeLineMetrics()
        .length;

    // Make sure these numbers exactly match the ones you used in _showBusinessProfile!
    double baseHeight = numLines > 1 ? 435.0 : 405;
    // -------------------------------------

    double sheetExtent = (baseHeight + bottomSafeArea) / screenHeight;
    sheetExtent = sheetExtent.clamp(0.40, 0.85);

    // 3. Define the UI boundaries on the screen
    final double searchBarBottom = topSafeArea + 80;
    final double bottomSheetTop = screenHeight * (1.0 - sheetExtent);

    // 4. Find the exact middle pixel in the visible map gap
    // Return shop location directly (pixel offset simplified for flutter_map v8 compatibility)
    return shop['location'];
  }




  @override
  void initState() {
    super.initState();

    // 🟢 1. Initialize the PageController for your bottom carousel
    _pageController = PageController(viewportFraction: 0.85);

    // 🟢 2. Attach the listener for the search bar focus
    _searchFocus.addListener(_onSearchFocusChanged);

    // 🟢 3. Start GPS tracking
    _initLocationTracking();

    // 🟢 4. Fetch the data (using the correct method name)
    _fetchShopsFromDatabase();
  }

  // 🟢 1. ADD THIS VARIABLE right above the fetch function
  StreamSubscription<List<Map<String, dynamic>>>? _shopsSubscription;

  // 🟢 2. REPLACE your old _fetchShopsFromDatabase with this real-time stream
  void _fetchShopsFromDatabase() {
    _shopsSubscription?.cancel(); // Kill any old streams

    _shopsSubscription = Supabase.instance.client
        .from('businesses')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (!mounted) return;

      // Transform the raw DB data into your UI format
      List<Map<String, dynamic>> updatedShops = data.map<Map<String, dynamic>>((row) {

        int parsedOpenHour = 9; int parsedOpenMin = 0;
        int parsedCloseHour = 22; int parsedCloseMin = 0;

        try {
          if (row['open_time'] != null) {
            final parts = row['open_time'].toString().split(':');
            parsedOpenHour = int.parse(parts[0]);
            parsedOpenMin = int.parse(parts[1].split(' ')[0]);
          }
          if (row['close_time'] != null) {
            final parts = row['close_time'].toString().split(':');
            parsedCloseHour = int.parse(parts[0]);
            parsedCloseMin = int.parse(parts[1].split(' ')[0]);
          }
        } catch (_) {}

        return {
          'id': row['id'],
          'name': row['name'] ?? 'Unknown Business',
          'category': row['business_type']?.toString().toLowerCase() ?? 'service',
          'location': LatLng(
              (row['latitude'] as num?)?.toDouble() ?? 0.0,
              (row['longitude'] as num?)?.toDouble() ?? 0.0
          ),
          'image': row['logo_url'] ?? "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=300",
          'phone': row['phone'],
          'address': row['address'],
          'openHour': parsedOpenHour,
          'openMinute': parsedOpenMin,
          'closeHour': parsedCloseHour,
          'closeMinute': parsedCloseMin,
          'rating': 4.8,
          'reviews': 124,
          'services': [row['business_type'] ?? 'General Services'],
        };
      }).toList();

      // 🟢 3. THE SORTING ENGINE: Nearest to Farthest
      updatedShops.sort((a, b) {
        double distanceA = Geolocator.distanceBetween(
            _currentLocation.latitude, _currentLocation.longitude,
            a['location'].latitude, a['location'].longitude
        );
        double distanceB = Geolocator.distanceBetween(
            _currentLocation.latitude, _currentLocation.longitude,
            b['location'].latitude, b['location'].longitude
        );
        return distanceA.compareTo(distanceB);
      });

      // 4. Push to UI instantly
      setState(() {
        _realShops = updatedShops;
        _nearbyShops = List.from(_realShops);

        // Only override if they aren't actively searching
        if (_searchController.text.isEmpty) {
          _displayedShops = List.from(_realShops);
        }
      });
    });
  }

  void _onSearchFocusChanged() {
    if (_searchFocus.hasFocus && mounted) {
      setState(() {
        _isSearchPanelOpen = true; // Open panel when tapped
      });
    }
  }

  @override
  void dispose() {
    _shopsSubscription?.cancel();
    _minuteTicker?.cancel();
    _snapBackTimer?.cancel();
    _pageController.dispose();
    _positionStream?.cancel();
    _debounce?.cancel();
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- 3. CORE LOGIC ---

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!_isMapReady) return;
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude,
        end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude,
        end: destLocation.longitude);
    final zoomTween = Tween<double>(
        begin: _mapController.camera.zoom, end: destZoom);

    var controller = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    Animation<double> animation = CurvedAnimation(
        parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation));
    });
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) controller.dispose();
    });
    controller.forward();
  }

  void _killFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) {
      setState(() {
        _isSearchPanelOpen = false; // Completely hides the glass panel
      });
    }
  }

  void _hideKeyboardOnly() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onMapInteractionStart() {
    _killFocus(); // FIX 2: Kill keyboard as soon as user starts dragging the map
    _snapBackTimer?.cancel();
    if (_followUser) setState(() => _followUser = false);
  }

  void _startSnapBackTimer() {
    _snapBackTimer?.cancel();
    _snapBackTimer = Timer(const Duration(seconds: 5), () {
      // Fixed: Removed _searchResults dependency here
      if (mounted && !_followUser && _selectedShop == null &&
          _searchController.text.isEmpty) {
        setState(() => _followUser = true);
        _animatedMapMove(_currentLocation, _mapController.camera.zoom);
      }
    });
  }

  void _onCarouselPageChanged(int index) {
    if (_isMapLocked) return; // STOP if we are currently handling a pin tap

    if (_pageController.page?.round() == index) {
      setState(() {
        _currentCarouselIndex = index;
        _selectedShop = _displayedShops[index]; // Change here
        _followUser = false;
      });

      LatLng targetLocation = _displayedShops[index]['location'];

      // Apply the ADAPTIVE offset here too
      LatLng offsetLocation = LatLng(
          targetLocation.latitude + _adaptiveOffset,
          targetLocation.longitude
      );

      _animatedMapMove(offsetLocation, _mapController.camera.zoom);
    }
  }

  void _onMapPinTapped(Map<String, dynamic> shop, int index, {double? targetZoom}) {
    _killFocus();

    if (_selectedShop?['name'] == shop['name']) {
      _showBusinessProfile(context, shop);
      return;
    }

    _isMapLocked = true;

    setState(() {
      _selectedShop = shop;
      _currentCarouselIndex = index;
      _followUser = false;
      _isProfileOpen = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(index, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }

      double currentZoom = targetZoom ?? _mapController.camera.zoom;
      LatLng offsetLocation = _getDynamicCenterOffset(shop, currentZoom);
      _animatedMapMove(offsetLocation, currentZoom);

      _showBusinessProfile(context, shop);
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _isMapLocked = false;
    });
  }

  void _executeCategorySearch(String categoryId, String categoryLabel, {bool isGroup = false}) {
    _killFocus();
    _searchController.text = categoryLabel;

    List<String> targetIds = [];
    if (isGroup) {
      var group = _getCategoryTree(context).firstWhere((g) => g['id'] == categoryId);
      targetIds = (group['sub'] as List).map((s) => s['id'] as String).toList();
    } else {
      targetIds = [categoryId];
    }

    List<Map<String, dynamic>> results = _nearbyShops.where((shop) => targetIds.contains(shop['category'])).toList();
    _applySearchResults(results, categoryLabel);
  }

  void _applySearchResults(List<Map<String, dynamic>> results, String queryLabel) {
    setState(() {
      _displayedShops = results;
      _activeSearchQuery = queryLabel;
      _searchMatchedCategories = [];
      _searchMatchedShops = [];
      _isSearching = false;
      _selectedShop = results.isNotEmpty ? results.first : null;
      _currentCarouselIndex = 0; // Fixes carousel sync
    });

    if (results.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        _animatedMapMove(results.first['location'], 15.0);
      });
    }
  }

  void _handleSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchMatchedCategories = [];
        _searchMatchedShops = [];
        _displayedShops = List.from(_nearbyShops);
        _activeSearchQuery = null;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 300), () {
      final String q = query.trim().toLowerCase();
      List<Map<String, dynamic>> catMatches = [];
      List<Map<String, dynamic>> shopMatches = [];

      for (var group in _getCategoryTree(context)) {
        if (group['label'].toLowerCase().contains(q)) {
          catMatches.add({'type': 'group', 'label': group['label'], 'id': group['id'], 'icon': group['icon'], 'sub': group['sub']});
        }
        for (var sub in group['sub']) {
          if (sub['label'].toLowerCase().contains(q)) {
            catMatches.add({'type': 'sub', 'label': sub['label'], 'id': sub['id'], 'icon': group['icon']});
          }
        }
      }

      for (var shop in _nearbyShops) {
        final name = shop['name'].toString().toLowerCase();
        if (name.startsWith(q) || name.contains(" $q")) {
          shopMatches.add({'shop': shop, 'match_reason': null});
        } else if (shop['services'] != null) {
          List<String> services = List<String>.from(shop['services']);
          var matchedSrv = services.where((s) => s.toLowerCase().contains(q));
          if (matchedSrv.isNotEmpty) {
            shopMatches.add({'shop': shop, 'match_reason': AppLocalizations.of(context)!.searchMatchProvides(matchedSrv.first)}); // 🟢 Localized
          }
        }
      }

      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchMatchedCategories = catMatches;
          _searchMatchedShops = shopMatches;
        });
      }
    });
  }

  void _executeSearch(String query) {
    _killFocus();
    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }
    List<Map<String, dynamic>> results = _searchMatchedShops.map((e) => e['shop'] as Map<String, dynamic>).toList();
    _applySearchResults(results, query);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchMatchedCategories = [];
      _searchMatchedShops = [];
      _isSearching = false;
      _displayedShops = List.from(_nearbyShops);
      _activeSearchQuery = null;
      _selectedShop = null;
    });
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      // Added check for deniedForever to prevent infinite hanging
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
    }

    // --- FIX: 1. Force an immediate GPS grab for a fast first load ---
    try {
      // Tries to get the location quickly. If it takes more than 4 seconds, it fails gracefully.
      Position initialPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(initialPos.latitude, initialPos.longitude);
        });

        if (_followUser) {
          double zoom = 14.0;
          try {
            zoom = _mapController.camera.zoom;
          } catch (_) {}
          double adaptiveOffset = _baseLatitudeOffset * pow(2, 14.0 - zoom);
          LatLng offsetLocation = LatLng(
              initialPos.latitude + adaptiveOffset, initialPos.longitude);

          // Jump immediately to the real location
          if (_isMapReady) {
            _mapController.move(offsetLocation, zoom);
          }
        }
      }
    } catch (e) {
      debugPrint("Quick location grab timed out or failed: $e");
    }

    // --- 2. THEN start the stream to track them as they walk/drive ---
    _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10 // Only updates if they move 10+ meters
        )
    ).listen((Position pos) {
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });

      if (_followUser) {
        double zoom = 14.0;
        try {
          zoom = _mapController.camera.zoom;
        } catch (_) {}
        double adaptiveOffset = _baseLatitudeOffset * pow(2, 14.0 - zoom);
        LatLng offsetLocation = LatLng(
            pos.latitude + adaptiveOffset, pos.longitude);
        _animatedMapMove(offsetLocation, zoom);
      }
    });
  }

  bool _isShopOpen(Map<String, dynamic> shop) {
    // Assuming you add 'openHour' (e.g., 9) and 'closeHour' (e.g., 22) to shop_data.dart.
    // If they aren't there yet, this defaults to 9 AM - 10 PM.
    final int openHour = shop['openHour'] ?? 9;
    final int closeHour = shop['closeHour'] ?? 22;
    final int currentHour = DateTime
        .now()
        .hour;

    return currentHour >= openHour && currentHour < closeHour;
  }

  String _getDistanceString(LatLng shopLocation) {
    double m = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        shopLocation.latitude,
        shopLocation.longitude
    );
    // Returns just "447 m" or "1.2 km"
    return m < 1000 ? "${m.toStringAsFixed(0)} m" : "${(m / 1000)
        .toStringAsFixed(1)} km";
  }

  ShopStatus _getShopStatus(Map<String, dynamic> shop) {
    // Read hours AND minutes from the data, default to 0 if missing
    final int openHour = shop['openHour'] ?? 9;
    final int openMin = shop['openMinute'] ?? 0;
    final int closeHour = shop['closeHour'] ?? 22;
    final int closeMin = shop['closeMinute'] ?? 0;

    final DateTime now = DateTime.now();

    // Create the time objects for today
    DateTime openTime = DateTime(
        now.year, now.month, now.day, openHour, openMin);
    DateTime closeTime = DateTime(
        now.year, now.month, now.day, closeHour, closeMin);

    // Midnight Rollover Logic (e.g., 6PM to 3AM)
    if (closeTime.isBefore(openTime)) {
      if (now.isAfter(openTime)) {
        // We are currently in the evening, closing is tomorrow morning
        closeTime = closeTime.add(const Duration(days: 1));
      } else {
        // We are currently in the early morning, opening was yesterday evening
        openTime = openTime.subtract(const Duration(days: 1));
      }
    }

    // 1. Check if Closed
    if (now.isBefore(openTime) || now.isAfter(closeTime)) {
      return ShopStatus.closed;
    }

    // 2. Check if Closing Soon (Within 30 minutes)
    final int minutesLeft = closeTime
        .difference(now)
        .inMinutes;
    if (minutesLeft >= 0 && minutesLeft <= 30) {
      return ShopStatus.closingSoon;
    }

    // 3. Otherwise Open
    return ShopStatus.open;
  }

  LiquidGlassSettings _getGlassSettings(bool isDark, {double blur = 2.0}) {
    return isDark
        ? LiquidGlassSettings(
      thickness: 0.1,
      blur: blur, // <--- NOW USES THE CUSTOM BLUR
      // Crystal clear
      refractiveIndex: 1.0,
      glassColor: Colors.transparent,
      // No dark tint
      lightAngle: 45.0,
      lightIntensity: 0.1,
      ambientStrength: 1.0,
      // No dimming of the map
      saturation: 1.0,
      chromaticAberration: 0.0,
    )
        : LiquidGlassSettings(
      thickness: 0.1,
      blur: blur, // <--- NOW USES THE CUSTOM BLUR
      // Crystal clear
      refractiveIndex: 1.0,
      glassColor: Colors.transparent,
      // No white tint
      lightAngle: 45.0,
      lightIntensity: 0.2,
      ambientStrength: 1.0,
      // No dimming of the map
      saturation: 1.0,
      chromaticAberration: 0.0,
    );
  }

  // --- ACTION BUTTON LOGIC ---
  final String _shopPhoneNumber = "+60123456789"; // The target phone number

  Future<void> _makeCall() async {
    final Uri uri = Uri(scheme: 'tel', path: _shopPhoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Could not launch dialer");
    }
  }

  Future<void> _getDirections(Map<String, dynamic> shop) async {
    // We use the shop's LatLng if available, or fallback to KL center (3.1415, 101.6865)
    final double lat = shop['location']?.latitude ?? 3.1415;
    final double lng = shop['location']?.longitude ?? 101.6865;

    // Using Google Maps Universal URL ensures it opens in the Maps app or browser
    final String mapUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final Uri uri = Uri.parse(mapUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showMessageOptions(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!; // 🟢 Fetch l10n
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E242B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                l10n.msgVia, // 🟢 Localized
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            ),
            Divider(color: isDark ? Colors.white12 : Colors.black12),
            _buildMessageOption(l10n.msgWhatsApp, "https://wa.me/${_shopPhoneNumber.replaceAll('+', '')}", isDark, HugeIcons.strokeRoundedWhatsapp), // 🟢 Localized
            _buildMessageOption(l10n.msgTelegram, "https://t.me/$_shopPhoneNumber", isDark, HugeIcons.strokeRoundedTelegram), // 🟢 Localized
            _buildMessageOption(l10n.msgSMS, "sms:$_shopPhoneNumber", isDark, HugeIcons.strokeRoundedMessage01), // 🟢 Localized
          ],
        ),
      ),
    );
  }

  Widget _buildMessageOption(String title, String urlString, bool isDark, dynamic icon) {
    return ListTile(
      leading: HugeIcon(icon: icon, color: Colors.blue, size: 24),
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white30 : Colors.black26),
      onTap: () async {
        Navigator.pop(context); // Close the bottom sheet
        final Uri uri = Uri.parse(urlString);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSearchActive = _isSearchPanelOpen;
    final bool hideBottomPanel = isSearchActive || _isProfileOpen;
    final double bottomPosition = hideBottomPanel ? -500 : (MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom + 20 : 110);

    return PopScope(
      canPop: !_searchFocus.hasFocus && _searchController.text.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _killFocus();
          _clearSearch();
        }
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _killFocus();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Listener(
                onPointerDown: (_) => _onMapInteractionStart(),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: 14.0,

                    // --- 1. PREVENT ZOOMING OUT TOO FAR ---
                    minZoom: 3.5,
                    // Locks maximum zoom out (Lower number = further out)
                    maxZoom: 22.0,
                    // Optional: Prevents zooming in so far the tiles blur

                    // --- 2. PREVENT DRAGGING OFF THE MAP ---
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(-90, -180),
                        // South-West corner of the world
                        const LatLng(90, 180), // North-East corner of the world
                      ),
                    ),

                    interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onMapReady: () {
                      if (mounted) setState(() => _isMapReady = true);
                    },
                    onTap: (tapPosition, latLng) {
                      // FIX: Drops the keyboard and safely clears the advanced search state!
                      _killFocus();
                      _clearSearch();
                    },
                    onPositionChanged: (pos, hasGesture) {
                      if (hasGesture)
                        _onMapInteractionStart();
                      else
                        _startSnapBackTimer();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: isDark
                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',

                      // 🟢 PERFECT FIX: Has (context), but NO 'const' keyword!
                      retinaMode: RetinaMode.isHighDensity(context),

                      tileBuilder: (context, tileWidget, tile) {
                        if (!isDark) return tileWidget;
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            0.85, 0, 0, 0, 8,
                            0, 0.85, 0, 0, 10,
                            0, 0, 1.0, 0, 15,
                            0, 0, 0, 1, 0,
                          ]),
                          child: tileWidget,
                        );
                      },
                    ),

                    // 🟢 1. CLUSTER LAYER (For all unselected shops)
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 45,
                        size: const Size(40, 40),

                        // 🟢 FIXED: Use the official cluster tap handler!
                        onMarkerTap: (Marker marker) {
                          // Find which shop belongs to the tapped marker using its Key
                          final shopName = (marker.key as ValueKey).value;
                          final index = _displayedShops.indexWhere((s) => s['name'] == shopName);
                          if (index != -1) {
                            _onMapPinTapped(_displayedShops[index], index);
                          }
                        },

                        markers: _displayedShops.asMap().entries.where((e) => e.value != _selectedShop).map((e) {
                          final Map<String, dynamic> shop = e.value;
                          return Marker(
                            key: ValueKey(shop['name']), // 🟢 ADDED: Unique key to identify the shop
                            point: shop['location'],
                            width: 44, // Increased slightly for a better touch target
                            height: 44,
                            child: _buildMarkerPin(shop, false), // 🟢 REMOVED GestureDetector from here
                          );
                        }).toList(),

                        builder: (context, markers) {
                          return Container(
                            decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(color: Colors.blue.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)
                                ]
                            ),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // 🟢 2. STANDARD MARKER LAYER (For the User Dot & Selected Shop)
                    // We keep these separate so they ALWAYS stay on top and never get clustered!
                    MarkerLayer(markers: [
                      Marker(
                          point: _currentLocation,
                          width: 60,
                          height: 60,
                          child: const _PulsingUserMarker()
                      ),
                      if (_selectedShop != null)
                        Marker(
                            point: _selectedShop!['location'],
                            width: 35,
                            height: 35,
                            child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                      bottom: 35,
                                      left: -150,
                                      right: -150,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: _buildShopPopup(_selectedShop!, isDark),
                                      )
                                  ),
                                  _buildMarkerPin(_selectedShop!, true)
                                ]
                            )
                        ),
                    ]),
                  ],
                ),
              ),
              Positioned(top: MediaQuery
                  .of(context)
                  .padding
                  .top + 20, left: 0, right: 0, child: _buildSearchRow(isDark)),
              Positioned(top: MediaQuery.of(context).padding.top + 80, left: 24, right: 24,
                  child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: isSearchActive ? 1.0 : 0.0,
                      child: isSearchActive ? _buildResultsGlass(isDark) : const SizedBox.shrink())),
                _buildAIChatPanel(isDark),
              AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutBack,
                  bottom: bottomPosition,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      // --- UPDATED THIS LINE ---
                      opacity: hideBottomPanel ? 0.0 : 1.0,
                      child: _buildBottomGlassPanel(isDark))),
            ],
          ),
        ),
      ),
    );
  }

  // --- 4. UI BUILDERS ---

  Widget _buildGlassBox({
    required bool isDark,
    required double radius,
    required Widget child,
    double? height,
    double? width,
    EdgeInsets? padding,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          // Classic smooth blur
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 
                  0.08) // Dark mode: faint white tint
                  : Colors.white.withValues(alpha: 0.6),
              // Light mode: milky white tint
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow(bool isDark) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          Expanded(
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
              settings: _getGlassSettings(isDark),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: _isSearching
                            ? CircularProgressIndicator(strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? Colors.white : _lightModeGray))
                            : HugeIcon(icon: HugeIcons.strokeRoundedSearch01,
                            color: isDark ? Colors.white70 : _lightModeGray
                                .withValues(alpha: 0.6),
                            size: 20,
                            strokeWidth: 2.0)
                    ),
                    const SizedBox(width: 12),
                    
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: Colors.blue,
                            ),
                            primaryColor: Colors.blue,
                          ),
                          child: TextField(
                            controller: _searchController, focusNode: _searchFocus, onChanged: _handleSearch, onSubmitted: _executeSearch,
                            style: TextStyle(color: isDark ? Colors.white : _lightModeGray, fontWeight: FontWeight.w600, fontSize: 15),
                            cursorColor: Colors.blue, 
                            textAlignVertical: TextAlignVertical.center, 
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.searchHint, 
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : _lightModeGray.withValues(alpha: 0.4), fontSize: 14, fontWeight: FontWeight.w400), 
                              border: InputBorder.none, 
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),

                    if (_searchController.text.isNotEmpty)
                      GestureDetector(onTap: _clearSearch,
                          child: Icon(Icons.close, size: 18,
                              color: isDark ? Colors.white70 : _lightModeGray
                                  .withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _AnimatedPressable(
              onTap: () {
                setState(() {
                  _isAIPanelOpen = !_isAIPanelOpen;
                });
              },
              child: GlassContainer(
                useOwnLayer: true,
                quality: GlassQuality.standard,
                shape: LiquidRoundedSuperellipse(borderRadius: 100.0),
                settings: _getGlassSettings(isDark),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                      child: HugeIcon(icon: HugeIcons.strokeRoundedSparkles,
                          color: Colors.blue,
                          size: 22,
                          strokeWidth: 2.0)
                  ),
                ),
              ),
            ),
        ]),
      );

  Widget _buildResultsGlass(bool isDark) {
    final bool isTyping = _searchController.text.isNotEmpty;

    Widget content;

    if (isTyping && _isSearching) {
      content = const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    } else if (isTyping && _searchMatchedCategories.isEmpty && _searchMatchedShops.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(child: Text("No matches found", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54))),
      );
    } else if (isTyping) {
      content = ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (_searchMatchedCategories.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: 24, bottom: 8, top: 8),
              child: Text(AppLocalizations.of(context)!.searchHeadersCategories, style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            ..._searchMatchedCategories.map((cat) {
              bool isGroup = cat['type'] == 'group';

              if (isGroup) {
                bool isExpanded = _expandedCategories.contains(cat['id']);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: isExpanded ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                        child: HugeIcon(icon: cat['icon'], color: isExpanded ? Colors.blue : (isDark ? Colors.white70 : Colors.black87), size: 20),
                      ),
                      title: Text(cat['label'], style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: isExpanded ? FontWeight.bold : FontWeight.w600)),
                      trailing: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: isExpanded ? 0.5 : 0.0),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, turns, child) {
                            return Transform.rotate(angle: turns * 2 * math.pi, child: child);
                          },
                          child: HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, color: isDark ? Colors.white54 : Colors.black54, size: 20)
                      ),
                      onTap: () {
                        _hideKeyboardOnly();
                        setState(() {
                          if (isExpanded) {
                            _expandedCategories.remove(cat['id']);
                          } else {
                            _expandedCategories.clear(); // 🟢 Closes others
                            _expandedCategories.add(cat['id']);
                          }
                        });
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: !isExpanded ? const SizedBox.shrink() : Padding(
                        padding: const EdgeInsets.only(left: 64, right: 24, bottom: 8),
                        child: Column(
                            children: [
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(AppLocalizations.of(context)!.searchAll(cat['label']), style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold)),
                                  trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.blue.withValues(alpha: 0.5), size: 16),
                                  onTap: () {
                                    _hideKeyboardOnly();
                                    _executeCategorySearch(cat['id'], cat['label'], isGroup: true);
                                  }
                              ),
                              ...(cat['sub'] as List).map((sub) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(sub['label'], style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                                  trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: isDark ? Colors.white24 : Colors.black26, size: 16),
                                  onTap: () {
                                    _hideKeyboardOnly();
                                    _executeCategorySearch(sub['id'], sub['label'], isGroup: false);
                                  }
                              )).toList(),
                            ]
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: HugeIcon(icon: cat['icon'], color: isDark ? Colors.white70 : Colors.black87, size: 20),
                    title: Text(cat['label'], style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                    onTap: () {
                      _hideKeyboardOnly();
                      _executeCategorySearch(cat['id'], cat['label'], isGroup: false);
                    }
                );
              }
            }),
            if (_searchMatchedShops.isNotEmpty) Divider(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3), indent: 24, endIndent: 24),
          ],

          if (_searchMatchedShops.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: 24, bottom: 8, top: 8),
              child: Text(AppLocalizations.of(context)!.searchHeadersShops, style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            ..._searchMatchedShops.map((match) {
              final shop = match['shop'];
              final reason = match['match_reason'];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.3), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.5), width: 1.0)),
                  child: Center(child: _getCategoryIcon(shop, size: 16, color: isDark ? Colors.white : _lightModeGray)),
                ),
                title: Text(shop['name'], style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: reason != null ? Text(reason, style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)) : null,
                onTap: () {
                  _killFocus();
                  _searchController.text = shop['name'];

                  setState(() {
                    _displayedShops = [shop];
                    _activeSearchQuery = shop['name'];
                    _isSearching = false;
                    _selectedShop = shop;
                    _currentCarouselIndex = 0;
                  });

                  LatLng offsetLocation = _getDynamicCenterOffset(shop, 15.0);
                  _animatedMapMove(offsetLocation, 15.0);

                  Future.delayed(const Duration(milliseconds: 150), () {
                    _showBusinessProfile(context, shop);
                  });
                },
              );
            }),
          ]
        ],
      );
    } else {
      content = ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: _getCategoryTree(context).length,
          itemBuilder: (context, index) {
            var group = _getCategoryTree(context)[index];
            bool isExpanded = _expandedCategories.contains(group['id']);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: isExpanded ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                    child: HugeIcon(icon: group['icon'], color: isExpanded ? Colors.blue : (isDark ? Colors.white70 : Colors.black87), size: 20),
                  ),
                  title: Text(group['label'], style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: isExpanded ? FontWeight.bold : FontWeight.w600)),
                  trailing: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: isExpanded ? 0.5 : 0.0),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, turns, child) {
                        return Transform.rotate(angle: turns * 2 * math.pi, child: child);
                      },
                      child: HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, color: isDark ? Colors.white54 : Colors.black54, size: 20)
                  ),
                  onTap: () {
                    _hideKeyboardOnly();
                    setState(() {
                      if (isExpanded) {
                        _expandedCategories.remove(group['id']);
                      } else {
                        _expandedCategories.clear(); // 🟢 Closes others
                        _expandedCategories.add(group['id']);
                      }
                    });
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: !isExpanded ? const SizedBox.shrink() : Padding(
                    padding: const EdgeInsets.only(left: 64, right: 24, bottom: 8),
                    child: Column(
                        children: [
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text("All ${group['label']}", style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold)),
                              trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.blue.withValues(alpha: 0.5), size: 16),
                              onTap: () {
                                _hideKeyboardOnly();
                                _executeCategorySearch(group['id'], group['label'], isGroup: true);
                              }
                          ),
                          ...(group['sub'] as List).map((sub) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(sub['label'], style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                              trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: isDark ? Colors.white24 : Colors.black26, size: 16),
                              onTap: () {
                                _hideKeyboardOnly();
                                _executeCategorySearch(sub['id'], sub['label'], isGroup: false);
                              }
                          )).toList(),
                        ]
                    ),
                  ),
                ),
              ],
            );
          }
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(28.0),
            border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6), width: 1.0),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGlassPanel(bool isDark) =>
      Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: const EdgeInsets.only(right: 24, bottom: 4),
                child: Align(
                    alignment: Alignment.centerRight,
                    child: _AnimatedPressable(
                        onTap: () {
                          setState(() => _followUser = true);
                          double zoom = 14.0;
                          try {
                            zoom = _mapController.camera.zoom;
                          } catch (_) {}
                          double adaptiveOffset = _baseLatitudeOffset *
                              pow(2, 14.0 - zoom);
                          LatLng offsetLocation = LatLng(
                              _currentLocation.latitude + adaptiveOffset,
                              _currentLocation.longitude);
                          _animatedMapMove(offsetLocation, zoom);
                        },
                        child: GlassContainer(
                          useOwnLayer: true,
                          quality: GlassQuality.standard,
                          shape: LiquidRoundedSuperellipse(borderRadius: 100.0),
                          settings: _getGlassSettings(isDark),
                          child: Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 
                                      isDark ? 0.15 : 0.4),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 
                                        isDark ? 0.2 : 0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                  child: HugeIcon(
                                      icon: HugeIcons
                                          .strokeRoundedLocationShare02,
                                      // --- APPLIED GRAY ICON ---
                                      color: _followUser ? Colors.blue : (isDark
                                          ? Colors.white70
                                          : _lightModeGray),
                                      size: 22,
                                      strokeWidth: 2.0
                                  )
                              )
                          ),
                        )
                    )
                )
            ),
            Padding(
                padding: EdgeInsets.only(
                    left: (MediaQuery
                        .of(context)
                        .size
                        .width * 0.075) + 8,
                    bottom: 4
                ),
                child: Text(
                    _activeSearchQuery == null
                        ? AppLocalizations.of(context)!.nearby
                        : (_displayedShops.isNotEmpty
                        ? AppLocalizations.of(context)!.resultsFor(
                        _activeSearchQuery!)
                        : AppLocalizations.of(context)!.noResultsFoundTitle),
                    // --- APPLIED GRAY TEXT ---
                    style: TextStyle(
                        color: isDark ? Colors.white : _lightModeGray,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)
                )
            ),
            SizedBox(height: 135, child: PageView.builder(controller: _pageController, onPageChanged: _onCarouselPageChanged, physics: const ClampingScrollPhysics(), itemCount: _displayedShops.length, itemBuilder: (context, i) => _AnimatedPressable(onTap: () => _onMapPinTapped(_displayedShops[i], i), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _buildCarouselCard(isDark, _displayedShops[i]))))),
          ]);

  Widget _buildEmptyState(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black
            .withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const HugeIcon(icon: HugeIcons.strokeRoundedSearchRemove,
                color: Colors.grey,
                size: 28,
                strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(AppLocalizations.of(context)!.noMatchesFound,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context)!.trySearchingDifferent,
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 12,
                        height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _AnimatedPressable(
            onTap: _clearSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.blue, borderRadius: BorderRadius.circular(16)),
              child: Text(AppLocalizations.of(context)!.clear,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),),
          )
        ],
      ),
    );
  }

  Widget _buildStatusLabel(BuildContext context, Map<String, dynamic> shop) {
    final status = _getShopStatus(shop);
    final l10n = AppLocalizations.of(context)!;
    dynamic icon;
    Color color;
    String text;

    switch (status) {
      case ShopStatus.open:
        icon = HugeIcons.strokeRoundedStore01;
        color = Colors.blue;
        text = l10n.statusOpenCaps;
        break;
      case ShopStatus.closingSoon:
        icon = HugeIcons.strokeRoundedTime02;
        color = Colors.orange;
        text = l10n.statusClosingCaps;
        break;
      case ShopStatus.closed:
        icon = HugeIcons.strokeRoundedUnavailable;
        color = Colors.red;
        text = l10n.statusClosedCaps;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, color: color, size: 10, strokeWidth: 2.5),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildShopPopup(Map<String, dynamic> shop, bool isDark) {
    final frostedGlow = [
      Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 8),
      Shadow(color: Colors.black.withValues(alpha: 0.2),
          offset: const Offset(0.5, 0.5),
          blurRadius: 0),
    ];

    return TweenAnimationBuilder<double>(
      key: ValueKey("popup_${shop['name']}"),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: -6,
              child: Transform.rotate(
                angle: 0.785398,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors
                            .white.withValues(alpha: 0.1),
                        border: Border(
                          bottom: BorderSide(color: Colors.white.withValues(alpha: 
                              isDark ? 0.15 : 0.4), width: 1.0),
                          right: BorderSide(color: Colors.white.withValues(alpha: 
                              isDark ? 0.15 : 0.4), width: 1.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 
                                isDark ? 0.2 : 0.05),
                            blurRadius: 12,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: LiquidRoundedSuperellipse(borderRadius: 12.0),
              settings: _getGlassSettings(isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white
                      .withValues(alpha: 0.1),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                    width: 1.0,
                  ),
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 160,
                          child: Text(
                              shop['name'],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: isDark ? Colors.white : _lightModeGray,
                                shadows: isDark ? frostedGlow : [],
                              )
                          )
                      ),
                      const SizedBox(height: 4),
                      Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.star, color: Colors.amber, size: 10),
                            const SizedBox(width: 4),
                            Text(
                                "${shop['rating']} (${shop['reviews']})",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : _lightModeGray.withValues(alpha: 0.8),
                                )
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6),
                              child: Text("|", style: TextStyle(color: isDark
                                  ? Colors.white24
                                  : _lightModeGray.withValues(alpha: 0.2),
                                  fontSize: 10)),
                            ),
                            _buildStatusLabel(context, shop),
                          ]
                      ),
                    ]
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCategoryIcon(Map<String, dynamic> shop,
      {double size = 18, Color color = Colors.white}) {
    // 1. Check if it's a mobile service first!
    if (shop['isMobileService'] == true) {
      return HugeIcon(icon: HugeIcons.strokeRoundedDeliveryTruck01,
          color: color,
          size: size,
          strokeWidth: 2.0);
    }

    // 2. Otherwise, check the category as normal
    String cat = shop['category'] ?? 'default';
    dynamic d;
    switch (cat) {
      case 'food':
        d = HugeIcons.strokeRoundedRestaurant01;
        break;
      case 'gas':
        d = HugeIcons.strokeRoundedFuelStation;
        break;
      case 'health':
        d = HugeIcons.strokeRoundedHospital02;
        break;
      case 'barber':
        d = HugeIcons.strokeRoundedScissor;
        break;
      case 'religion':
        d = HugeIcons.strokeRoundedMosque02;
        break;
      case 'market':
        d = HugeIcons.strokeRoundedShoppingBasket01;
        break;
      case 'workshop':
        d = HugeIcons.strokeRoundedSettings02;
        break;
      case 'school':
        d = HugeIcons.strokeRoundedSchool;
        break;
      case 'bank':
        d = HugeIcons.strokeRoundedAtm02;
        break;
      default:
        d = HugeIcons.strokeRoundedStore01;
    }
    return HugeIcon(icon: d, color: color, size: size, strokeWidth: 2.0);
  }

  Widget _buildMarkerPin(Map<String, dynamic> shop, bool sel) {
    final ShopStatus status = _getShopStatus(shop);
    Color pinColor;

    switch (status) {
      case ShopStatus.open:
        pinColor = Colors.blue;
        break;
      case ShopStatus.closingSoon:
        pinColor = Colors.orange;
        break;
      case ShopStatus.closed:
        pinColor = Colors.red;
        break;
    }

    bool isUnfocused = _selectedShop != null && !sel;

    Widget pin = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: sel ? 44.0 : 35.0,
      height: sel ? 44.0 : 35.0,
      decoration: BoxDecoration(
        color: sel ? pinColor : pinColor.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
            color: Colors.white,
            width: sel ? 2.5 : 1.0
        ),
        boxShadow: [
          if (!isUnfocused)
            BoxShadow(
                color: pinColor.withValues(alpha: 
                    sel ? 0.6 : (status == ShopStatus.closed ? 0.15 : 0.4)),
                blurRadius: sel ? 16 : 8,
                spreadRadius: sel ? 4 : 1
            )
        ],
      ),
      child: Center(
        child: _getCategoryIcon(
          shop,
          size: sel ? 20 : (status == ShopStatus.closed ? 13 : 15),
        ),
      ),
    );

    Widget finalPin = OverflowBox(
      maxWidth: 60,
      maxHeight: 60,
      child: pin,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isUnfocused ? 0.4 : 1.0,
      child: finalPin,
    );
  }

  Widget _buildCarouselCard(bool isDark, Map<String, dynamic> shop) {
    final frostedGlow = [
      Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 8),
      Shadow(color: Colors.black.withValues(alpha: 0.2),
          offset: const Offset(0.5, 0.5),
          blurRadius: 0),
    ];

    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
      settings: _getGlassSettings(isDark),
      child: Container(
        width: 285,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                      "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=200",
                      width: 70, height: 70, fit: BoxFit.cover)
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            shop['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              // --- APPLIED GRAY TEXT ---
                              color: isDark ? Colors.white : _lightModeGray,
                              shadows: isDark ? frostedGlow : [],
                            )
                        ),
                        const SizedBox(height: 6),
                        Row(
                            children: [
                              // --- APPLIED GRAY ICON ---
                              HugeIcon(icon: HugeIcons.strokeRoundedLocation01,
                                  color: isDark ? Colors.white : _lightModeGray,
                                  size: 14,
                                  strokeWidth: 2.5),
                              const SizedBox(width: 4),
                              Flexible(
                                  child: Text(
                                      _getDistanceString(shop['location']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        // --- APPLIED GRAY TEXT ---
                                        color: isDark
                                            ? Colors.white
                                            : _lightModeGray,
                                        fontWeight: FontWeight.w600,
                                        shadows: isDark ? frostedGlow : [],
                                      ),
                                      overflow: TextOverflow.ellipsis
                                  )
                              )
                            ]
                        )
                      ]
                  )
              )
            ]
        ),
      ),
    );
  }

  // --- 5. BOTTOM SHEET MODAL ---

  void _showBusinessProfile(BuildContext context, Map<String, dynamic> shop) {
    // 🟢 SAFELY set local state here, outside the sheet builder!
    setState(() {
      _isProfileOpen = true;
    });

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ShopStatus status = _getShopStatus(shop);
    Color statusColor;
    String statusText;

    final int closeH = shop['closeHour'] ?? 22;
    final int closeM = shop['closeMinute'] ?? 0;
    final DateTime now = DateTime.now();
    DateTime closeTime = DateTime(now.year, now.month, now.day, closeH, closeM);

    if (closeTime.isBefore(now) && status != ShopStatus.closed) {
      closeTime = closeTime.add(const Duration(days: 1));
    }

    final int minutesLeft = closeTime.difference(now).inMinutes;

    switch (status) {
      case ShopStatus.open:
        statusColor = Colors.blue;
        statusText = AppLocalizations.of(context)!.statusOpenCaps;
        break;
      case ShopStatus.closingSoon:
        statusColor = Colors.orange;
        statusText = AppLocalizations.of(context)!.closingIn(minutesLeft);
        break;
      case ShopStatus.closed:
        statusColor = Colors.red;
        statusText = AppLocalizations.of(context)!.statusClosedCaps;
        break;
    }

    final double topSafeArea = MediaQuery.of(context).padding.top;
    final double bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;

    // 🟢 DEFINE THE HOURS STATE HERE! It lives locally inside the bottom sheet.
    bool localIsHoursExpanded = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (context) {
        return LayoutBuilder(builder: (context, constraints) {
          final String shopName = shop['name'] ?? '';

          double textAvailableWidth = constraints.maxWidth - 108;
          final TextPainter textPainter = TextPainter(
            text: TextSpan(
                text: shopName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
            maxLines: 2,
          )..layout(maxWidth: textAvailableWidth);

          int numLines = textPainter.computeLineMetrics().length;
          double baseHeight = numLines > 1 ? 430.0 : 400;
          double adaptiveInitialSize = (baseHeight + bottomSafeArea) / screenHeight;
          adaptiveInitialSize = adaptiveInitialSize.clamp(0.40, 0.85);
          double sheetExtent = adaptiveInitialSize;

          return DraggableScrollableSheet(
            initialChildSize: adaptiveInitialSize,
            minChildSize: adaptiveInitialSize,
            maxChildSize: 1.0,
            expand: false,
            builder: (context, scrollController) {
              return StatefulBuilder(
                  builder: (BuildContext context, StateSetter setSheetState) {
                    double currentRadius = ((1.0 - sheetExtent) * 150).clamp(0.0, 32.0);

                    return NotificationListener<DraggableScrollableNotification>(
                      onNotification: (notification) {
                        if (sheetExtent != notification.extent) {
                          setSheetState(() => sheetExtent = notification.extent);
                        }
                        return true;
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(currentRadius)),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GlassContainer(
                                useOwnLayer: true,
                                quality: GlassQuality.standard,
                                shape: LiquidRoundedSuperellipse(borderRadius: currentRadius),
                                settings: _getGlassSettings(isDark, blur: 4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
                              children: [
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 150),
                                  opacity: sheetExtent > 0.95 ? 0.0 : 1.0,
                                  child: Center(
                                      child: Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                              color: isDark ? Colors.white24 : _lightModeGray.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(10)))),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(shopName,
                                              style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : _lightModeGray),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 6),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            physics: const BouncingScrollPhysics(),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text((shop['category'] ?? '').toUpperCase(),
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.blue,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 1.2)),
                                                const SizedBox(width: 12),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                      color: statusColor.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: statusColor)),
                                                  child: Text(statusText,
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: statusColor)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildInnerGlassCard(
                                      isDark: isDark,
                                      radius: 100,
                                      padding: const EdgeInsets.all(12),
                                      child: HugeIcon(
                                          icon: HugeIcons.strokeRoundedShare01,
                                          color: isDark ? Colors.white : _lightModeGray,
                                          size: 20,
                                          strokeWidth: 2.0),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildInnerGlassCard(
                                  isDark: isDark,
                                  radius: 20.0,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Expanded(child: _buildStatItem(HugeIcons.strokeRoundedStar, shop['rating'].toString(), AppLocalizations.of(context)!.rating, isDark)),
                                      _buildVerticalDivider(isDark),
                                      Expanded(child: _buildStatItem(HugeIcons.strokeRoundedComment01, shop['reviews'].toString(), AppLocalizations.of(context)!.reviews, isDark)),
                                      _buildVerticalDivider(isDark),
                                      Expanded(child: _buildStatItem(HugeIcons.strokeRoundedLocation01, _getDistanceString(shop['location']), AppLocalizations.of(context)!.away, isDark)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // REPLACE YOUR EXISTING ROW WITH THIS:
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: _buildActionButton(
                                        HugeIcons.strokeRoundedCall,
                                        null,
                                        isDark,
                                        false,
                                        onTap: _makeCall, // 🟢 Triggers phone call
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 1,
                                      child: _buildActionButton(
                                        HugeIcons.strokeRoundedMessage02,
                                        null,
                                        isDark,
                                        false,
                                        onTap: () => _showMessageOptions(context, isDark), // 🟢 Opens the message options popup
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _buildActionButton(
                                        HugeIcons.strokeRoundedRoute01,
                                        AppLocalizations.of(context)!.directions,
                                        isDark,
                                        true,
                                        onTap: () => _getDirections(shop), // 🟢 Opens Google Maps / Apple Maps
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildSectionTitle(AppLocalizations.of(context)!.operatingHours, isDark),

                                // 🟢 PASSED LOCAL STATE INSTEAD OF GLOBAL STATE
                                _buildHoursSection(shop, status, isDark, setSheetState, localIsHoursExpanded, () {
                                  setSheetState(() {
                                    localIsHoursExpanded = !localIsHoursExpanded;
                                  });
                                }),

                                const SizedBox(height: 24),
                                _buildSectionTitle(AppLocalizations.of(context)!.servicesAvailable, isDark),
                                _buildServicesSection(shop, isDark),
                                const SizedBox(height: 24),
                                _buildSectionTitle(AppLocalizations.of(context)!.recentReviews, isDark),
                                _buildReviewsSection(shop, isDark),
                              ],
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.only(left: 24, right: 24, bottom: bottomSafeArea + 16, top: 16),
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEBE7E3),
                                          isDark ? const Color(0xFF1A1A1A).withValues(alpha: 0.0) : const Color(0xFFEBE7E3).withValues(alpha: 0.0)
                                        ])),
                                child: Row(
                                  children: [
                                    // 🟢 BUTTON 1: View Profile
                                    Expanded(
                                      child: _AnimatedPressable(
                                        onTap: () {
                                          _searchFocus.unfocus();
                                          Navigator.pop(context); // Close the bottom sheet
                                          // Navigate to the full detail screen
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => ShopDetailScreen(shop: shop)));
                                        },
                                        // 👇 CHANGED: Now uses the exact same frosted glass style as the Stats Dashboard!
                                        child: _buildInnerGlassCard(
                                          isDark: isDark,
                                          radius: 18.0,
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          child: Center(
                                            child: Text(
                                                AppLocalizations.of(context)!.btnViewProfile, // 🟢 Localized
                                                style: TextStyle(
                                                    color: isDark ? Colors.white : Colors.black87,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold
                                                )
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 🟢 BUTTON 2: Rezrv Now (WITH AUTH GUARD)
                                    Expanded(
                                      child: _AnimatedPressable(
                                        onTap: () {
                                          _searchFocus.unfocus();
                                          Navigator.pop(context); // Close the bottom sheet

                                          // 🟢 THE AUTH GUARD LOGIC
                                          if (Supabase.instance.client.auth.currentUser != null) {
                                            // ✅ USER IS LOGGED IN: Proceed to checkout/booking!
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => BookingsView(
                                              shopId: shop["id"].toString(),
                                              shopName: shop["name"] ?? "Unknown Shop",
                                              category: shop["category"]?.toString().toUpperCase() ?? "SERVICE",
                                              shopImage: shop["image"] ?? "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400",
                                            )));
                                          } else {
                                            // ❌ USER IS GUEST: Show Toast and Redirect to Login!
                                            showGlassToast(
                                                context,
                                                "Please sign in or register to make a reservation.",
                                                isError: true
                                            );

                                            // Send them to the Auth Screen
                                            Navigator.pushNamed(context, '/login');
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(18),
                                              boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                                          child: Center(
                                              child: Text(AppLocalizations.of(context)!.rezrvNow, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  });
            },
          );
        });
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isProfileOpen = false;
        });
      }
    });
  }

  // =========================================================================
  // HELPER: INNER GLASS CARD (Builds frosted borders & background for items)
  // =========================================================================
  Widget _buildInnerGlassCard({
    required Widget child,
    required bool isDark,
    double radius = 16.0,
    EdgeInsetsGeometry? padding,
    Color? overrideColor,
    Color? overrideBorder,
  }) {
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: _getGlassSettings(isDark),
      // Uses same glass settings as GPS button
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          // Sheer tint so it visibly pops out from the completely clear main sheet
          color: overrideColor ??
              (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white
                  .withValues(alpha: 0.4)),
          border: Border.all(
            color: overrideBorder ??
                Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(
          color: isDark ? Colors.white : _lightModeGray,
          fontSize: 16,
          fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHoursSection(Map<String, dynamic> shop, ShopStatus status, bool isDark, StateSetter setSheetState, bool isExpanded, VoidCallback onToggle) {
    final List<String> days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    final DateTime now = DateTime.now();
    final int currentDayIndex = now.weekday - 1;

    final int openHour = shop['openHour'] ?? 9;
    final int openMin = shop['openMinute'] ?? 0;
    final String openStr = _formatTime(openHour, openMin);
    final String closeStr = _formatTime(shop['closeHour'] ?? 22, shop['closeMinute'] ?? 0);
    final String defaultHours = "$openStr - $closeStr";

    DateTime nextOpenTime = DateTime(now.year, now.month, now.day, openHour, openMin);
    if (nextOpenTime.isBefore(now) && status == ShopStatus.closed) {
      nextOpenTime = nextOpenTime.add(const Duration(days: 1));
    }
    if (status == ShopStatus.closingSoon) {
      nextOpenTime = nextOpenTime.add(const Duration(days: 1));
    }
    String nextOpenDayWord = (nextOpenTime.day == now.day) ? "today" : "tomorrow";

    dynamic statusIcon;
    Color statusColor;
    String subtitleText;

    switch (status) {
      case ShopStatus.open:
        statusIcon = HugeIcons.strokeRoundedStore01;
        statusColor = Colors.blue;
        subtitleText = "Open Now";
        break;
      case ShopStatus.closingSoon:
        statusIcon = HugeIcons.strokeRoundedTime02;
        statusColor = Colors.orange;
        subtitleText = "Closing Soon • Closes at $closeStr";
        break;
      case ShopStatus.closed:
        statusIcon = HugeIcons.strokeRoundedUnavailable;
        statusColor = Colors.red;
        subtitleText = "Closed • Opens $nextOpenDayWord at $openStr";
        break;
    }

    return GestureDetector(
      onTap: onToggle, // 🟢 FIRES THE TOGGLE FUNCTION PASSED FROM THE BUILDER
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.hardEdge,
        child: _buildInnerGlassCard(
          isDark: isDark,
          radius: 16.0,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  HugeIcon(icon: statusIcon, color: statusColor, size: 22, strokeWidth: 2.5),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Today", style: TextStyle(color: isDark ? Colors.white : _lightModeGray, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(defaultHours, style: TextStyle(color: isDark ? Colors.white : _lightModeGray, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(subtitleText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: isExpanded ? 0.5 : 0.0), // 🟢 USES PASSED LOCAL STATE
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    builder: (context, turns, child) {
                      return Transform.rotate(angle: turns * 2 * math.pi, child: child);
                    },
                    child: HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, color: isDark ? Colors.white54 : _lightModeGray.withValues(alpha: 0.5), size: 20, strokeWidth: 2.0),
                  )
                ],
              ),
              if (isExpanded) ...[ // 🟢 USES PASSED LOCAL STATE
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                ),
                Column(
                  children: List.generate(7, (i) {
                    int chronologicalIndex = (currentDayIndex + i) % 7;
                    bool isToday = (i == 0);
                    Color rowColor = isToday ? (isDark ? Colors.white : _lightModeGray) : (isDark ? Colors.white60 : _lightModeGray.withValues(alpha: 0.6));
                    FontWeight rowWeight = isToday ? FontWeight.bold : FontWeight.normal;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          const SizedBox(width: 38),
                          Expanded(child: Text(days[chronologicalIndex], style: TextStyle(color: rowColor, fontSize: 13, fontWeight: rowWeight))),
                          Text(defaultHours, style: TextStyle(color: rowColor, fontSize: 13, fontWeight: rowWeight)),
                          const SizedBox(width: 36),
                        ],
                      ),
                    );
                  }),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection(Map<String, dynamic> shop, bool isDark) {
    List<String> services = List<String>.from(
        shop['services'] ?? [AppLocalizations.of(context)!.generalService]);
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: services.map((s) =>
      // Wrapped in Glass Card
      _buildInnerGlassCard(
        isDark: isDark,
        radius: 20.0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        overrideColor: Colors.blue.withValues(alpha: isDark ? 0.1 : 0.15),
        overrideBorder: Colors.blue.withValues(alpha: 0.3),
        child: Text(s, style: const TextStyle(
            color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
      )).toList(),
    );
  }

  Widget _buildReviewsSection(Map<String, dynamic> shop, bool isDark) {
    final List<dynamic> rawReviews = shop['recentReviews'] ?? [];
    final List<Map<String, dynamic>> reviews = rawReviews.cast<
        Map<String, dynamic>>();

    if (reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(AppLocalizations.of(context)!.noReviewsYet,
            style: TextStyle(
                color: isDark ? Colors.white.withValues(alpha: 0.5) : _lightModeGray
                    .withValues(alpha: 0.5))),
      );
    }

    return Column(
      children: reviews.map((review) =>
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            // Wrapped in Glass Card
            child: _buildInnerGlassCard(
              isDark: isDark,
              radius: 16.0,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(review['userName'] ??
                          AppLocalizations.of(context)!.user, style: TextStyle(
                          color: isDark ? Colors.white : _lightModeGray,
                          fontWeight: FontWeight.bold)),
                      Row(children: List.generate(5, (index) =>
                          Icon(index <
                              ((review['rating'] as num?)?.toInt() ?? 0) ? Icons
                              .star : Icons.star_border, color: Colors.amber,
                              size: 14))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(review['comment'] ?? '', style: TextStyle(color: isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : _lightModeGray.withValues(alpha: 0.8),
                      fontSize: 12,
                      height: 1.4)),
                ],
              ),
            ),
          )).toList(),
    );
  }

  Widget _buildStatItem(dynamic icon, String value, String label,
      bool isDark) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: Colors.blue, size: 20, strokeWidth: 2.0),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(
              color: isDark ? Colors.white : _lightModeGray,
              fontWeight: FontWeight.bold,
              fontSize: 14)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              color: isDark ? Colors.white38 : _lightModeGray.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500)),
        ],
      );

  Widget _buildVerticalDivider(bool isDark) =>
      Container(
        height: 30,
        width: 1,
        color: isDark ? Colors.white.withValues(alpha: 0.1) : _lightModeGray
            .withValues(alpha: 0.1),
      );

  Widget _buildActionButton(dynamic icon, String? label, bool isDark,
      bool isPrimary, {VoidCallback? onTap}) {
    Color contentColor = isPrimary ? Colors.white : (isDark
        ? Colors.white
        : _lightModeGray);

    return GestureDetector(
      onTap: onTap,
      child: _buildInnerGlassCard(
        isDark: isDark,
        radius: 14.0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        // If it's primary, use the frosted blue.
        // If not, leave it null so it inherits the exact same glass style as the Stats and Hours cards!
        overrideColor: isPrimary
            ? Colors.blue.withValues(alpha: isDark ? 0.3 : 0.7)
            : null,
        overrideBorder: isPrimary
            ? Colors.blue.withValues(alpha: isDark ? 0.5 : 0.9)
            : null,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                  icon: icon,
                  color: contentColor,
                  size: 18,
                  strokeWidth: 2.0
              ),
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(
                    label,
                    style: TextStyle(
                        color: contentColor,
                        fontWeight: FontWeight.w600
                    )
                ),
              ]
            ]
        ),
      ),
    );
  }
}

// --- SHARED CLASSES ---
class _AnimatedPressable extends StatefulWidget {
  final Widget child; final VoidCallback onTap;
  const _AnimatedPressable({required this.child, required this.onTap});
  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}
class _AnimatedPressableState extends State<_AnimatedPressable> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _s;



  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100)); _s = Tween<double>(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return GestureDetector(onTapDown: (_) => _c.forward(), onTapUp: (_) { _c.reverse(); widget.onTap(); }, onTapCancel: () => _c.reverse(), child: ScaleTransition(scale: _s, child: widget.child)); }
}

class _PulsingUserMarker extends StatefulWidget {
  const _PulsingUserMarker();
  @override
  State<_PulsingUserMarker> createState() => _PulsingUserMarkerState();
}
class _PulsingUserMarkerState extends State<_PulsingUserMarker> with SingleTickerProviderStateMixin {
  late AnimationController _c;



  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      FadeTransition(opacity: ReverseAnimation(Tween<double>(begin: 0.0, end: 1.0).animate(_c)), child: ScaleTransition(scale: Tween<double>(begin: 1.0, end: 2.5).animate(_c), child: Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withValues(alpha: 0.3))))),
      Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: Colors.blue.withValues(alpha: 0.2), width: 1.5)), child: const Center(child: HugeIcon(icon: HugeIcons.strokeRoundedLocationUser01, color: Colors.blue, size: 20, strokeWidth: 2.5))),
    ]);
  }
}