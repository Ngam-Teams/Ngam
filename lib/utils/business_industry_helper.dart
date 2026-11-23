enum StoreOrderContext {
  fnb,
  retail,
  service,
}

/// Resolves the commercial fulfillment context (F&B vs Retail vs Service)
/// from a merchant's `business_industry`, granular `business_type`, `category`,
/// and (as a last-resort fallback) store name.
class BusinessIndustryHelper {
  BusinessIndustryHelper._();

  static const Set<String> _fnbTypes = {
    'fnb',
    'f&b',
    'food',
    'restaurant',
    'cafe_bakery',
    'food_stall',
    'food_truck',
    'catering',
    'dessert_drinks',
    'pet_cafe',
    'cafe',
    'bakery',
    'dining',
  };

  static const Set<String> _retailTypes = {
    'retail',
    'minimarket',
    'fresh_market',
    'florist',
    'boutique_fashion',
    'jewelry_gold',
    'pet_shop',
    'pharmacy',
    'optical_shop',
    'tailor',
  };

  static const Set<String> _serviceTypes = {
    'barber',
    'barbershop',
    'services',
    'service',
    'beauty',
    'salon',
    'muslimah_salon',
    'spa',
    'spa_massage',
    'nail_lash',
    'aesthetic_clinic',
    'automotive',
    'auto',
    'carwash',
    'car_wash',
    'detailing',
    'workshop',
    'tyre_battery',
    'tint_accessories',
    'motorcycle_shop',
    'home_services',
    'aircond_service',
    'home_cleaning',
    'plumbing_electric',
    'laundry',
    'laundry_dobi',
    'renovation_contractor',
    'pest_control',
    'sports',
    'badminton_court',
    'pickleball_court',
    'fitness_gym',
    'gym',
    'yoga_pilates',
    'swimming_academy',
    'health',
    'clinic',
    'medical_clinic',
    'dental_clinic',
    'physiotherapy',
    'acupuncture_hijama',
    'education',
    'tuition_center',
    'quran_class',
    'kindergarten_daycare',
    'music_art',
    'driving_school',
    'pets',
    'pet_hotel',
    'pet_grooming',
    'pet_clinic',
    'professional',
    'studio',
    'photography_studio',
    'printing_banner',
    'gadget_repair',
    'coworking_space',
    'event_hall',
    'hotel',
    'hospitality',
  };

  static StoreOrderContext? _matchToken(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty ||
        lower == 'business' ||
        lower == 'general' ||
        lower == 'other' ||
        lower == 'all') {
      return null;
    }

    if (_fnbTypes.contains(lower)) return StoreOrderContext.fnb;
    if (_retailTypes.contains(lower)) return StoreOrderContext.retail;
    if (_serviceTypes.contains(lower)) return StoreOrderContext.service;

    // Keyword matching for free-form category strings
    if (lower.contains('barber') ||
        lower.contains('gunting') ||
        lower.contains('rambut') ||
        lower.contains('salon') ||
        lower.contains('salun') ||
        lower.contains('spa') ||
        lower.contains('beauty') ||
        lower.contains('kecantikan') ||
        lower.contains('bengkel') ||
        lower.contains('workshop') ||
        lower.contains('carwash') ||
        lower.contains('car wash') ||
        lower.contains('auto') ||
        lower.contains('klinik') ||
        lower.contains('clinic') ||
        lower.contains('dental') ||
        lower.contains('dobi') ||
        lower.contains('laundry') ||
        lower.contains('grooming') ||
        lower.contains('gym') ||
        lower.contains('court') ||
        lower.contains('tuition') ||
        lower.contains('tuisyen') ||
        lower.contains('studio') ||
        lower.contains('repair') ||
        lower.contains('servis') ||
        lower.contains('service') ||
        lower.contains('hotel') ||
        lower.contains('homestay')) {
      return StoreOrderContext.service;
    }

    if (lower.contains('retail') ||
        lower.contains('runcit') ||
        lower.contains('minimarket') ||
        lower.contains('mini market') ||
        lower.contains('grocer') ||
        lower.contains('pasar') ||
        lower.contains('florist') ||
        lower.contains('bunga') ||
        lower.contains('boutique') ||
        lower.contains('butik') ||
        lower.contains('fashion') ||
        lower.contains('pakaian') ||
        lower.contains('farmasi') ||
        lower.contains('pharmacy') ||
        lower.contains('optik') ||
        lower.contains('optical') ||
        lower.contains('pet shop') ||
        lower.contains('jewelry') ||
        lower.contains('emas')) {
      return StoreOrderContext.retail;
    }

    if (lower.contains('fnb') ||
        lower.contains('f&b') ||
        lower.contains('food') ||
        lower.contains('makan') ||
        lower.contains('minum') ||
        lower.contains('restaurant') ||
        lower.contains('restoran') ||
        lower.contains('cafe') ||
        lower.contains('kafe') ||
        lower.contains('kopi') ||
        lower.contains('coffee') ||
        lower.contains('bakery') ||
        lower.contains('warung') ||
        lower.contains('gerai') ||
        lower.contains('bistro') ||
        lower.contains('mamak') ||
        lower.contains('catering') ||
        lower.contains('katering') ||
        lower.contains('dessert') ||
        lower.contains('beverage') ||
        lower.contains('dining') ||
        lower.contains('kitchen') ||
        lower.contains('dapur')) {
      return StoreOrderContext.fnb;
    }

    return null;
  }

  static StoreOrderContext resolve({
    String? granularType,
    String? industry,
    String? category,
    String? shopName,
    bool hasTableNumber = false,
  }) {
    // 1. Most specific: granular business_type from business_settings.operating_hours
    if (granularType != null) {
      final matched = _matchToken(granularType);
      if (matched != null) return matched;
    }

    // 2. Canonical businesses.business_industry
    if (industry != null) {
      final matched = _matchToken(industry);
      if (matched != null) return matched;
    }

    // 3. Passed shop category
    if (category != null) {
      final matched = _matchToken(category);
      if (matched != null) return matched;
    }

    // 4. Smart fallback from store name
    if (shopName != null) {
      final matched = _matchToken(shopName);
      if (matched != null) return matched;
    }

    // 5. If opened from a table QR scan with unknown metadata, treat as F&B;
    // otherwise default to retail/self-pickup so we never show Dine-In / Bungkus erroneously.
    return hasTableNumber ? StoreOrderContext.fnb : StoreOrderContext.retail;
  }

  static bool isFnb({
    String? granularType,
    String? industry,
    String? category,
    String? shopName,
    bool hasTableNumber = false,
  }) {
    return resolve(
          granularType: granularType,
          industry: industry,
          category: category,
          shopName: shopName,
          hasTableNumber: hasTableNumber,
        ) ==
        StoreOrderContext.fnb;
  }
}
