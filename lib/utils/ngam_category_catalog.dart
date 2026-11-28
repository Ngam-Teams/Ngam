import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class NgamSubCategory {
  final String id;
  final String groupId;
  final String titleKey;
  final dynamic icon;
  final List<String> synonyms;

  const NgamSubCategory({
    required this.id,
    required this.groupId,
    required this.titleKey,
    required this.icon,
    required this.synonyms,
  });
}

class NgamCategoryGroup {
  final String id;
  final String titleKey;
  final dynamic icon;
  final Color color;
  final List<String> groupSynonyms;
  final List<NgamSubCategory> children;

  const NgamCategoryGroup({
    required this.id,
    required this.titleKey,
    required this.icon,
    required this.color,
    required this.groupSynonyms,
    required this.children,
  });
}

/// Unified 2-level Category Directory (Main Category -> Sub-Categories) aligned 1:1
/// with Ngam_Business `BusinessTypeCatalog`, plus BM/EN synonym matching so every
/// Home category button, Search filter, Map filter, and Explore Directory matches reliably.
class NgamCategoryCatalog {
  NgamCategoryCatalog._();

  static const List<NgamCategoryGroup> groups = [
    NgamCategoryGroup(
      id: 'fnb',
      titleKey: 'category_explore.groups.fnb',
      icon: HugeIcons.strokeRoundedCoffee02,
      color: Color(0xFFF59E0B),
      groupSynonyms: [
        'fnb', 'food', 'drink', 'drinks', 'makanan', 'minuman', 'makan',
        'cafe', 'kafe', 'kopi', 'coffee', 'restoran', 'restaurant', 'warung',
        'gerai', 'bakery', 'bakeri', 'kek', 'cake', 'boba', 'tea', 'teh',
        'nasi', 'pisang', 'goreng', 'burger', 'katering', 'catering', 'bistro',
      ],
      children: [
        NgamSubCategory(
          id: 'restaurant',
          groupId: 'fnb',
          titleKey: 'category_explore.items.restaurant',
          icon: HugeIcons.strokeRoundedRestaurant01,
          synonyms: ['restaurant', 'restoran', 'bistro', 'seafood', 'western', 'tomyam', 'mamak', 'dine'],
        ),
        NgamSubCategory(
          id: 'kedai_makan',
          groupId: 'fnb',
          titleKey: 'category_explore.items.kedai_makan',
          icon: HugeIcons.strokeRoundedRestaurant01,
          synonyms: ['kedai_makan', 'kedai makan', 'nasi campur', 'nasi lemak', 'lauk', 'kampung', 'eatery'],
        ),
        NgamSubCategory(
          id: 'cafe_bakery',
          groupId: 'fnb',
          titleKey: 'category_explore.items.cafe_bakery',
          icon: HugeIcons.strokeRoundedCoffee02,
          synonyms: ['cafe_bakery', 'cafe', 'kafe', 'kopi', 'coffee', 'bakery', 'bakeri', 'roti', 'kek', 'cake', 'pastry', 'latte', 'matcha', 'kopitiam'],
        ),
        NgamSubCategory(
          id: 'food_stall',
          groupId: 'fnb',
          titleKey: 'category_explore.items.food_stall',
          icon: HugeIcons.strokeRoundedStore01,
          synonyms: ['food_stall', 'gerai', 'warung', 'hawker', 'stall', 'pisang goreng', 'putu bambu', 'kuih', 'street food', 'burger', 'roti canai'],
        ),
        NgamSubCategory(
          id: 'food_truck',
          groupId: 'fnb',
          titleKey: 'category_explore.items.food_truck',
          icon: HugeIcons.strokeRoundedTruck,
          synonyms: ['food_truck', 'food truck', 'trak makanan', 'pasar malam'],
        ),
        NgamSubCategory(
          id: 'catering',
          groupId: 'fnb',
          titleKey: 'category_explore.items.catering',
          icon: HugeIcons.strokeRoundedRestaurant01,
          synonyms: ['catering', 'katering', 'kenduri', 'bufet', 'buffet', 'jamuan'],
        ),
        NgamSubCategory(
          id: 'dessert_drinks',
          groupId: 'fnb',
          titleKey: 'category_explore.items.dessert_drinks',
          icon: HugeIcons.strokeRoundedCoffee02,
          synonyms: ['dessert_drinks', 'dessert', 'drinks', 'minuman', 'boba', 'milk tea', 'bubble tea', 'aiskrim', 'ice cream', 'waffle', 'cendol', 'abc', 'jus'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'beauty',
      titleKey: 'category_explore.groups.beauty',
      icon: HugeIcons.strokeRoundedSparkles,
      color: Color(0xFF8B5CF6),
      groupSynonyms: [
        'beauty', 'kecantikan', 'barber', 'barbershop', 'gunting', 'rambut',
        'hair', 'haircut', 'salon', 'salun', 'spa', 'massage', 'urut',
        'nail', 'kuku', 'lash', 'facial', 'aesthetic', 'estetik', 'medispa',
      ],
      children: [
        NgamSubCategory(
          id: 'barbershop',
          groupId: 'beauty',
          titleKey: 'category_explore.items.barbershop',
          icon: HugeIcons.strokeRoundedScissor,
          synonyms: ['barbershop', 'barber', 'gunting', 'rambut', 'haircut', 'fade', 'pomade', 'cukur'],
        ),
        NgamSubCategory(
          id: 'muslimah_salon',
          groupId: 'beauty',
          titleKey: 'category_explore.items.muslimah_salon',
          icon: HugeIcons.strokeRoundedScissor,
          synonyms: ['muslimah_salon', 'salon', 'salun', 'muslimah', 'hijab', 'hair', 'rebonding'],
        ),
        NgamSubCategory(
          id: 'spa_massage',
          groupId: 'beauty',
          titleKey: 'category_explore.items.spa_massage',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['spa_massage', 'spa', 'massage', 'urut', 'urutan', 'refleksologi', 'lulur', 'sauna', 'pantang'],
        ),
        NgamSubCategory(
          id: 'nail_lash',
          groupId: 'beauty',
          titleKey: 'category_explore.items.nail_lash',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['nail_lash', 'nail', 'kuku', 'manicure', 'pedicure', 'lash', 'eyelash', 'brow', 'inai', 'henna'],
        ),
        NgamSubCategory(
          id: 'aesthetic_clinic',
          groupId: 'beauty',
          titleKey: 'category_explore.items.aesthetic_clinic',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['aesthetic_clinic', 'aesthetic', 'estetik', 'facial', 'skin', 'kulit', 'laser', 'medispa'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'automotive',
      titleKey: 'category_explore.groups.automotive',
      icon: HugeIcons.strokeRoundedCar01,
      color: Color(0xFF06B6D4),
      groupSynonyms: [
        'automotive', 'automotif', 'auto', 'car', 'kereta', 'carwash', 'cuci kereta',
        'detailing', 'workshop', 'bengkel', 'mekanik', 'motor', 'motosikal',
        'tayar', 'tyre', 'bateri', 'tinted', 'tint', 'polish', 'coating',
      ],
      children: [
        NgamSubCategory(
          id: 'carwash',
          groupId: 'automotive',
          titleKey: 'category_explore.items.carwash',
          icon: HugeIcons.strokeRoundedCar01,
          synonyms: ['carwash', 'car wash', 'cuci kereta', 'snow wash', 'basuh kereta', 'vakum'],
        ),
        NgamSubCategory(
          id: 'detailing',
          groupId: 'automotive',
          titleKey: 'category_explore.items.detailing',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['detailing', 'polish', 'coating', 'ceramic', 'ppf', 'wrap'],
        ),
        NgamSubCategory(
          id: 'workshop',
          groupId: 'automotive',
          titleKey: 'category_explore.items.workshop',
          icon: HugeIcons.strokeRoundedWrench01,
          synonyms: ['workshop', 'bengkel', 'mekanik', 'repair', 'enjin', 'minyak hitam', 'servis kereta'],
        ),
        NgamSubCategory(
          id: 'tyre_battery',
          groupId: 'automotive',
          titleKey: 'category_explore.items.tyre_battery',
          icon: HugeIcons.strokeRoundedWrench01,
          synonyms: ['tyre_battery', 'tayar', 'tyre', 'tire', 'bateri', 'battery', 'alignment', 'rim'],
        ),
        NgamSubCategory(
          id: 'tint_accessories',
          groupId: 'automotive',
          titleKey: 'category_explore.items.tint_accessories',
          icon: HugeIcons.strokeRoundedCar01,
          synonyms: ['tint_accessories', 'tinted', 'tint', 'aksesori kereta', 'dashcam', 'audio'],
        ),
        NgamSubCategory(
          id: 'motorcycle_shop',
          groupId: 'automotive',
          titleKey: 'category_explore.items.motorcycle_shop',
          icon: HugeIcons.strokeRoundedWrench01,
          synonyms: ['motorcycle_shop', 'motor', 'motosikal', 'motorcycle', 'bike', 'superbike'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'retail',
      titleKey: 'category_explore.groups.retail',
      icon: HugeIcons.strokeRoundedShoppingBag02,
      color: Color(0xFFEC4899),
      groupSynonyms: [
        'retail', 'runcit', 'kedai runcit', 'minimarket', 'mart', 'grocery',
        'pasar', 'butik', 'boutique', 'fesyen', 'fashion', 'baju', 'pakaian',
        'tudung', 'kasut', 'bunga', 'florist', 'hadiah', 'emas', 'gold', 'shop',
      ],
      children: [
        NgamSubCategory(
          id: 'minimarket',
          groupId: 'retail',
          titleKey: 'category_explore.items.minimarket',
          icon: HugeIcons.strokeRoundedStore01,
          synonyms: ['minimarket', 'mini market', 'runcit', 'grocery', 'mart', 'serbaneka'],
        ),
        NgamSubCategory(
          id: 'fresh_market',
          groupId: 'retail',
          titleKey: 'category_explore.items.fresh_market',
          icon: HugeIcons.strokeRoundedShoppingBag02,
          synonyms: ['fresh_market', 'pasar segar', 'sayur', 'buah', 'ikan', 'ayam', 'daging'],
        ),
        NgamSubCategory(
          id: 'boutique_fashion',
          groupId: 'retail',
          titleKey: 'category_explore.items.boutique_fashion',
          icon: HugeIcons.strokeRoundedShoppingBag02,
          synonyms: ['boutique_fashion', 'butik', 'boutique', 'fesyen', 'fashion', 'baju', 'pakaian', 'tudung', 'kasut', 'clothing'],
        ),
        NgamSubCategory(
          id: 'florist',
          groupId: 'retail',
          titleKey: 'category_explore.items.florist',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['florist', 'bunga', 'bouquet', 'hadiah', 'gift', 'hamper'],
        ),
        NgamSubCategory(
          id: 'jewelry_gold',
          groupId: 'retail',
          titleKey: 'category_explore.items.jewelry_gold',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['jewelry_gold', 'emas', 'gold', 'barang kemas', 'jewelry', 'cincin'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'health',
      titleKey: 'category_explore.groups.health',
      icon: HugeIcons.strokeRoundedFirstAidKit,
      color: Color(0xFF10B981),
      groupSynonyms: [
        'health', 'healthcare', 'kesihatan', 'klinik', 'clinic', 'poliklinik',
        'doktor', 'doctor', 'medical', 'dental', 'gigi', 'pergigian', 'dentist',
        'fisio', 'physio', 'physiotherapy', 'farmasi', 'pharmacy', 'optik',
        'cermin mata', 'bekam', 'hijama', 'akupunktur',
      ],
      children: [
        NgamSubCategory(
          id: 'medical_clinic',
          groupId: 'health',
          titleKey: 'category_explore.items.medical_clinic',
          icon: HugeIcons.strokeRoundedFirstAidKit,
          synonyms: ['medical_clinic', 'klinik', 'clinic', 'poliklinik', 'doktor', 'doctor', 'medical'],
        ),
        NgamSubCategory(
          id: 'dental_clinic',
          groupId: 'health',
          titleKey: 'category_explore.items.dental_clinic',
          icon: HugeIcons.strokeRoundedFirstAidKit,
          synonyms: ['dental_clinic', 'dental', 'dentist', 'gigi', 'pergigian', 'braces', 'scaling'],
        ),
        NgamSubCategory(
          id: 'physiotherapy',
          groupId: 'health',
          titleKey: 'category_explore.items.physiotherapy',
          icon: HugeIcons.strokeRoundedFirstAidKit,
          synonyms: ['physiotherapy', 'fisio', 'fisioterapi', 'physio', 'rehab', 'chiropractic'],
        ),
        NgamSubCategory(
          id: 'optical_shop',
          groupId: 'health',
          titleKey: 'category_explore.items.optical_shop',
          icon: HugeIcons.strokeRoundedFirstAidKit,
          synonyms: ['optical_shop', 'optik', 'optical', 'cermin mata', 'spek', 'optometri'],
        ),
        NgamSubCategory(
          id: 'pharmacy',
          groupId: 'health',
          titleKey: 'category_explore.items.pharmacy',
          icon: HugeIcons.strokeRoundedFirstAidKit,
          synonyms: ['pharmacy', 'farmasi', 'ubat', 'vitamin', 'medicine'],
        ),
        NgamSubCategory(
          id: 'acupuncture_hijama',
          groupId: 'health',
          titleKey: 'category_explore.items.acupuncture_hijama',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['acupuncture_hijama', 'bekam', 'hijama', 'akupunktur', 'acupuncture'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'pets',
      titleKey: 'category_explore.groups.pets',
      icon: HugeIcons.strokeRoundedStore01,
      color: Color(0xFFF97316),
      groupSynonyms: [
        'pets', 'pet', 'haiwan', 'kucing', 'cat', 'pet_shop', 'pet shop',
        'pet_hotel', 'cat hotel', 'hotel kucing', 'grooming', 'vet', 'veterinar',
        'kibbles', 'royal canin', 'pets station',
      ],
      children: [
        NgamSubCategory(
          id: 'pet_shop',
          groupId: 'pets',
          titleKey: 'category_explore.items.pet_shop',
          icon: HugeIcons.strokeRoundedShoppingBag02,
          synonyms: ['pet_shop', 'pet shop', 'pets', 'kedai haiwan', 'kucing', 'makanan kucing', 'kibbles', 'pasir'],
        ),
        NgamSubCategory(
          id: 'pet_hotel',
          groupId: 'pets',
          titleKey: 'category_explore.items.pet_hotel',
          icon: HugeIcons.strokeRoundedHome01,
          synonyms: ['pet_hotel', 'cat hotel', 'hotel kucing', 'boarding', 'asrama kucing'],
        ),
        NgamSubCategory(
          id: 'pet_grooming',
          groupId: 'pets',
          titleKey: 'category_explore.items.pet_grooming',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['pet_grooming', 'grooming', 'mandi kucing', 'potong bulu'],
        ),
        NgamSubCategory(
          id: 'pet_clinic',
          groupId: 'pets',
          titleKey: 'category_explore.items.pet_clinic',
          icon: HugeIcons.strokeRoundedFirstAidKit,
          synonyms: ['pet_clinic', 'vet', 'veterinar', 'klinik haiwan'],
        ),
        NgamSubCategory(
          id: 'pet_cafe',
          groupId: 'pets',
          titleKey: 'category_explore.items.pet_cafe',
          icon: HugeIcons.strokeRoundedCoffee02,
          synonyms: ['pet_cafe', 'cat cafe', 'kafe kucing'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'stay',
      titleKey: 'category_explore.groups.stay',
      icon: HugeIcons.strokeRoundedHome01,
      color: Color(0xFF6366F1),
      groupSynonyms: [
        'stay', 'penginapan', 'hotel', 'homestay', 'chalet', 'roomstay',
        'resort', 'glamping', 'villa', 'vila', 'inap', 'bermalam', 'overnight',
      ],
      children: [
        NgamSubCategory(
          id: 'hotel',
          groupId: 'stay',
          titleKey: 'category_explore.items.hotel',
          icon: HugeIcons.strokeRoundedHome01,
          synonyms: ['hotel', 'suite', 'motel', 'inn'],
        ),
        NgamSubCategory(
          id: 'homestay',
          groupId: 'stay',
          titleKey: 'category_explore.items.homestay',
          icon: HugeIcons.strokeRoundedHome01,
          synonyms: ['homestay', 'rumah tamu', 'guest house', 'airbnb'],
        ),
        NgamSubCategory(
          id: 'chalet',
          groupId: 'stay',
          titleKey: 'category_explore.items.chalet',
          icon: HugeIcons.strokeRoundedHome01,
          synonyms: ['chalet', 'kabin', 'cabin', 'lodge'],
        ),
        NgamSubCategory(
          id: 'roomstay',
          groupId: 'stay',
          titleKey: 'category_explore.items.roomstay',
          icon: HugeIcons.strokeRoundedHome01,
          synonyms: ['roomstay', 'bilik sewa', 'room'],
        ),
        NgamSubCategory(
          id: 'resort',
          groupId: 'stay',
          titleKey: 'category_explore.items.resort',
          icon: HugeIcons.strokeRoundedHome01,
          synonyms: ['resort', 'villa', 'vila', 'retreat'],
        ),
        NgamSubCategory(
          id: 'glamping',
          groupId: 'stay',
          titleKey: 'category_explore.items.glamping',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['glamping', 'khemah', 'camping', 'campsite', 'dome'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'home_services',
      titleKey: 'category_explore.groups.home_services',
      icon: HugeIcons.strokeRoundedWrench01,
      color: Color(0xFF0EA5E9),
      groupSynonyms: [
        'home_services', 'servis rumah', 'aircond', 'aircon', 'cleaning',
        'cuci rumah', 'plumber', 'paip', 'elektrik', 'wiring', 'dobi',
        'laundry', 'renovation', 'kontraktor', 'pest control', 'handyman',
      ],
      children: [
        NgamSubCategory(
          id: 'aircond_service',
          groupId: 'home_services',
          titleKey: 'category_explore.items.aircond_service',
          icon: HugeIcons.strokeRoundedWrench01,
          synonyms: ['aircond_service', 'aircond', 'aircon', 'penyaman udara'],
        ),
        NgamSubCategory(
          id: 'home_cleaning',
          groupId: 'home_services',
          titleKey: 'category_explore.items.home_cleaning',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['home_cleaning', 'cleaning', 'cuci rumah', 'cleaner', 'maid', 'karpet', 'sofa'],
        ),
        NgamSubCategory(
          id: 'plumbing_electric',
          groupId: 'home_services',
          titleKey: 'category_explore.items.plumbing_electric',
          icon: HugeIcons.strokeRoundedWrench01,
          synonyms: ['plumbing_electric', 'paip', 'plumber', 'elektrik', 'wiring', 'handyman'],
        ),
        NgamSubCategory(
          id: 'laundry_dobi',
          groupId: 'home_services',
          titleKey: 'category_explore.items.laundry_dobi',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['laundry_dobi', 'dobi', 'laundry', 'dry clean', 'basuh baju'],
        ),
        NgamSubCategory(
          id: 'renovation_contractor',
          groupId: 'home_services',
          titleKey: 'category_explore.items.renovation_contractor',
          icon: HugeIcons.strokeRoundedWrench01,
          synonyms: ['renovation_contractor', 'renovation', 'ubah suai', 'kontraktor', 'contractor', 'kabinet'],
        ),
        NgamSubCategory(
          id: 'pest_control',
          groupId: 'home_services',
          titleKey: 'category_explore.items.pest_control',
          icon: HugeIcons.strokeRoundedFirstAidKit,
          synonyms: ['pest_control', 'pest', 'anai', 'serangga', 'fogging'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'sports',
      titleKey: 'category_explore.groups.sports',
      icon: HugeIcons.strokeRoundedSparkles,
      color: Color(0xFF22C55E),
      groupSynonyms: [
        'sports', 'sukan', 'badminton', 'futsal', 'pickleball', 'tennis',
        'tenis', 'gym', 'gim', 'fitness', 'yoga', 'pilates', 'swimming', 'renang', 'court',
      ],
      children: [
        NgamSubCategory(
          id: 'futsal_court',
          groupId: 'sports',
          titleKey: 'category_explore.items.futsal_court',
          icon: HugeIcons.strokeRoundedFootballPitch,
          synonyms: ['futsal_court', 'futsal', 'arena futsal', 'gelanggang futsal', 'bola', 'padang', 'turf', '5v5'],
        ),
        NgamSubCategory(
          id: 'badminton_court',
          groupId: 'sports',
          titleKey: 'category_explore.items.badminton_court',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['badminton_court', 'badminton', 'gelanggang', 'court'],
        ),
        NgamSubCategory(
          id: 'pickleball_court',
          groupId: 'sports',
          titleKey: 'category_explore.items.pickleball_court',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['pickleball_court', 'pickleball', 'tenis', 'tennis', 'padel'],
        ),
        NgamSubCategory(
          id: 'fitness_gym',
          groupId: 'sports',
          titleKey: 'category_explore.items.fitness_gym',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['fitness_gym', 'gym', 'gim', 'fitness', 'workout', 'crossfit'],
        ),
        NgamSubCategory(
          id: 'yoga_pilates',
          groupId: 'sports',
          titleKey: 'category_explore.items.yoga_pilates',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['yoga_pilates', 'yoga', 'pilates', 'zumba'],
        ),
        NgamSubCategory(
          id: 'swimming_academy',
          groupId: 'sports',
          titleKey: 'category_explore.items.swimming_academy',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['swimming_academy', 'swimming', 'renang', 'kolam'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'education',
      titleKey: 'category_explore.groups.education',
      icon: HugeIcons.strokeRoundedStore01,
      color: Color(0xFF3B82F6),
      groupSynonyms: [
        'education', 'pendidikan', 'tuisyen', 'tuition', 'mengaji', 'quran',
        'tadika', 'taska', 'kindergarten', 'daycare', 'muzik', 'music', 'seni',
        'memandu', 'driving', 'kelas', 'akademi',
      ],
      children: [
        NgamSubCategory(
          id: 'tuition_center',
          groupId: 'education',
          titleKey: 'category_explore.items.tuition_center',
          icon: HugeIcons.strokeRoundedStore01,
          synonyms: ['tuition_center', 'tuisyen', 'tuition', 'akademik'],
        ),
        NgamSubCategory(
          id: 'quran_class',
          groupId: 'education',
          titleKey: 'category_explore.items.quran_class',
          icon: HugeIcons.strokeRoundedStore01,
          synonyms: ['quran_class', 'mengaji', 'quran', 'alquran', 'iqra', 'kafa'],
        ),
        NgamSubCategory(
          id: 'kindergarten_daycare',
          groupId: 'education',
          titleKey: 'category_explore.items.kindergarten_daycare',
          icon: HugeIcons.strokeRoundedHome01,
          synonyms: ['kindergarten_daycare', 'tadika', 'taska', 'kindergarten', 'daycare', 'preschool'],
        ),
        NgamSubCategory(
          id: 'music_art',
          groupId: 'education',
          titleKey: 'category_explore.items.music_art',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['music_art', 'muzik', 'music', 'seni', 'art', 'piano', 'gitar'],
        ),
        NgamSubCategory(
          id: 'driving_school',
          groupId: 'education',
          titleKey: 'category_explore.items.driving_school',
          icon: HugeIcons.strokeRoundedCar01,
          synonyms: ['driving_school', 'memandu', 'driving', 'lesen'],
        ),
      ],
    ),
    NgamCategoryGroup(
      id: 'professional',
      titleKey: 'category_explore.groups.professional',
      icon: HugeIcons.strokeRoundedStore01,
      color: Color(0xFF64748B),
      groupSynonyms: [
        'professional', 'profesional', 'software', 'it', 'tech', 'studio',
        'foto', 'photography', 'printing', 'cetak', 'banner', 'gadget',
        'repair', 'telefon', 'phone', 'laptop', 'komputer', 'coworking', 'services',
      ],
      children: [
        NgamSubCategory(
          id: 'photography_studio',
          groupId: 'professional',
          titleKey: 'category_explore.items.photography_studio',
          icon: HugeIcons.strokeRoundedSparkles,
          synonyms: ['photography_studio', 'studio foto', 'photography', 'kamera', 'gambar'],
        ),
        NgamSubCategory(
          id: 'printing_banner',
          groupId: 'professional',
          titleKey: 'category_explore.items.printing_banner',
          icon: HugeIcons.strokeRoundedStore01,
          synonyms: ['printing_banner', 'printing', 'print', 'cetak', 'banner', 'sticker', 'bunting'],
        ),
        NgamSubCategory(
          id: 'gadget_repair',
          groupId: 'professional',
          titleKey: 'category_explore.items.gadget_repair',
          icon: HugeIcons.strokeRoundedWrench01,
          synonyms: ['gadget_repair', 'phone', 'telefon', 'laptop', 'komputer', 'gadget', 'software', 'it'],
        ),
        NgamSubCategory(
          id: 'coworking_space',
          groupId: 'professional',
          titleKey: 'category_explore.items.coworking_space',
          icon: HugeIcons.strokeRoundedHome01,
          synonyms: ['coworking_space', 'coworking', 'ruang kerja', 'office'],
        ),
      ],
    ),
  ];

  /// Legacy shortcut key aliases -> canonical group or sub-category IDs.
  static const Map<String, String> _legacyAliases = {
    'barber': 'barbershop',
    'haircut': 'barbershop',
    'cafe': 'fnb',
    'food': 'fnb',
    'salon': 'beauty',
    'spa': 'spa_massage',
    'clinic': 'health',
    'auto': 'automotive',
    'pet': 'pets',
  };

  static String normalizeKey(String rawKey) {
    final k = rawKey.trim().toLowerCase();
    return _legacyAliases[k] ?? k;
  }

  /// Find title localization key for any group ID, sub-category ID, or legacy key.
  static String? titleKeyFor(String rawKey) {
    final key = normalizeKey(rawKey);
    for (final g in groups) {
      if (g.id == key) return g.titleKey;
      for (final c in g.children) {
        if (c.id == key) return c.titleKey;
      }
    }
    return null;
  }

  /// Collect all synonyms & exact IDs for a group or sub-category key.
  static List<String> synonymsFor(String rawKey) {
    final key = normalizeKey(rawKey);
    for (final g in groups) {
      if (g.id == key) {
        final out = <String>{g.id, ...g.groupSynonyms};
        for (final c in g.children) {
          out.add(c.id);
          out.addAll(c.synonyms);
        }
        return out.toList();
      }
      for (final c in g.children) {
        if (c.id == key) {
          return <String>{c.id, ...c.synonyms}.toList();
        }
      }
    }
    return [key];
  }

  /// Check if a shop map matches a Main Category, Sub-Category, or legacy shortcut key.
  static bool matchesShop(Map<String, dynamic> shop, String rawCategoryKey) {
    final key = normalizeKey(rawCategoryKey);
    if (key.isEmpty || key == 'all' || key == '__all__') return true;

    final bizType = (shop['business_type'] ?? '').toString().trim().toLowerCase();
    final catGroup = (shop['category_group'] ?? '').toString().trim().toLowerCase();
    final industry = (shop['business_industry'] ?? '').toString().trim().toLowerCase();
    final category = (shop['category'] ?? '').toString().trim().toLowerCase();
    final name = (shop['business_name'] ?? shop['trading_name'] ?? shop['name'] ?? '').toString().toLowerCase();

    // 1. Exact ID match on structured columns
    if (bizType == key || catGroup == key || industry == key || category == key) {
      return true;
    }

    // 2. If key is a Main Category group, check if shop's business_type belongs to it
    for (final g in groups) {
      if (g.id == key) {
        if (g.children.any((c) => c.id == bizType || c.id == category)) {
          return true;
        }
        break;
      }
    }

    // 3. Synonym match across all descriptive text fields
    final haystack = '$bizType $catGroup $industry $category $name';
    return matchesText(haystack, key);
  }

  /// Check if a free-text haystack (shop + product name/category) matches a category key.
  static bool matchesText(String text, String rawCategoryKey) {
    final key = normalizeKey(rawCategoryKey);
    if (key.isEmpty || key == 'all' || key == '__all__') return true;
    final hay = text.toLowerCase();
    for (final syn in synonymsFor(key)) {
      if (syn.length <= 2) {
        if (RegExp('\\b${RegExp.escape(syn)}\\b').hasMatch(hay)) return true;
      } else if (hay.contains(syn)) {
        return true;
      }
    }
    return false;
  }
}
