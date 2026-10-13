import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'business_store_view.dart';

// =============================================================================
// StoreRouteLoader
// Dynamic deep-link and QR route resolver for Ngam Customer app.
// Handles URL pattern: /store/<business_id>?table=<table_number>&promo=<promo>
// =============================================================================

class StoreRouteLoader extends StatefulWidget {
  final String businessId;
  final String? tableNumber;
  final String? promoCode;

  const StoreRouteLoader({
    super.key,
    required this.businessId,
    this.tableNumber,
    this.promoCode,
  });

  @override
  State<StoreRouteLoader> createState() => _StoreRouteLoaderState();
}

class _StoreRouteLoaderState extends State<StoreRouteLoader> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _shopData;

  @override
  void initState() {
    super.initState();
    _fetchShopDetails();
  }

  Future<void> _fetchShopDetails() async {
    final rawId = widget.businessId.trim();
    if (rawId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ID Kedai tidak sah atau tiada.';
        });
      }
      return;
    }

    try {
      // 1. Query businesses table by UUID id or business_name
      final res = await Supabase.instance.client
          .from('businesses')
          .select()
          .or('id.eq.$rawId,business_name.ilike.%$rawId%')
          .maybeSingle();

      if (res == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Kedai tidak dijumpai dalam pangkalan data.';
          });
        }
        return;
      }

      final Map<String, dynamic> row = Map<String, dynamic>.from(res);
      final bId = row['id']?.toString() ?? '';

      // 2. Fetch business_settings for operating hours
      Map<String, dynamic>? opHours;
      try {
        final settingsRes = await Supabase.instance.client
            .from('business_settings')
            .select('operating_hours')
            .eq('business_id', bId)
            .maybeSingle();
        if (settingsRes != null && settingsRes['operating_hours'] is Map) {
          opHours = Map<String, dynamic>.from(settingsRes['operating_hours']);
        }
      } catch (_) {}

      int parsedOpenHour = 9;
      int parsedOpenMin = 0;
      int parsedCloseHour = 22;
      int parsedCloseMin = 0;

      if (opHours != null) {
        final openStr = opHours['open_time'] as String?;
        final closeStr = opHours['close_time'] as String?;
        if (openStr != null && openStr.contains(':')) {
          final parts = openStr.split(':');
          parsedOpenHour = int.tryParse(parts[0]) ?? 9;
          parsedOpenMin = int.tryParse(parts[1]) ?? 0;
        }
        if (closeStr != null && closeStr.contains(':')) {
          final parts = closeStr.split(':');
          parsedCloseHour = int.tryParse(parts[0]) ?? 22;
          parsedCloseMin = int.tryParse(parts[1]) ?? 0;
        }
      }

      final formattedShop = <String, dynamic>{
        'id': row['id'],
        'name': row['business_name'] ?? 'Peniaga Ngam',
        'category': row['business_industry'] ?? 'fnb',
        'location': LatLng(
          (row['latitude'] as num?)?.toDouble() ?? 3.1390,
          (row['longitude'] as num?)?.toDouble() ?? 101.6869,
        ),
        'image': row['business_logo_url'] ??
            'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=300',
        'cover': row['business_cover_url'] ?? row['business_logo_url'] ?? '',
        'phone': row['business_phone'] ?? '',
        'address': row['address_line'] ?? row['business_city'] ?? '',
        'openHour': parsedOpenHour,
        'openMinute': parsedOpenMin,
        'closeHour': parsedCloseHour,
        'closeMinute': parsedCloseMin,
        'operating_hours': opHours,
        'rating': (row['rating_average'] as num?)?.toDouble() ?? 4.8,
        'reviews': (row['total_reviews'] as num?)?.toInt() ?? 0,
        'services': ['Dine-In', 'Takeaway', 'Pesanan Meja'],
      };

      if (mounted) {
        setState(() {
          _shopData = formattedShop;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ralat memuatkan maklumat kedai: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F141C),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF00E676)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Membuka Kedai...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.tableNumber != null && widget.tableNumber!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Pesanan Meja #${widget.tableNumber}',
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _shopData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F141C),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_outlined,
                    color: Colors.redAccent,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Kedai Tidak Ditemui',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Kedai yang diimbas tidak wujud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/customer-home');
                  },
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Kembali ke Utama'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BusinessStoreView(
      shop: _shopData!,
      tableNumber: widget.tableNumber,
      promoCode: widget.promoCode,
    );
  }
}
