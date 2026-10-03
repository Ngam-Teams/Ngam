import 'package:flutter_dotenv/flutter_dotenv.dart';

// ============================================================
// Ngam App — Constants (Pemalar) & Konfigurasi
// ============================================================

// ─── Kunci Supabase ──────────────────────────────────────────
String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? 'https://rsueaoglsdxhzpupjljd.supabase.co';
String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? 'sb_publishable_qP4whY5B6wxIasWOVGoPCw_vrhOXj_J';

// ─── Kategori Task ───────────────────────────────────────────
class TaskCategory {
  static const String food = 'Food';
  static const String shopping = 'Shopping';
  static const String print = 'Print';
  static const String heavy = 'Heavy';
  static const String parcel = 'Parcel';
  static const String cleaning = 'Cleaning';
  static const String petCare = 'Pet Care';
  static const String errands = 'Errands';
  static const String automotive = 'Automotive';
  static const String others = 'Others';

  static const List<String> all = [
    food,
    shopping,
    print,
    heavy,
    parcel,
    cleaning,
    petCare,
    errands,
    automotive,
    others,
  ];

  /// Returns an icon for each category
  static String icon(String category) {
    switch (category) {
      case food:
        return '🍔';
      case shopping:
        return '🛒';
      case print:
        return '🖨️';
      case heavy:
        return '📦';
      case parcel:
        return '📮';
      case cleaning:
        return '🧹';
      case petCare:
        return '🐕';
      case errands:
        return '🚶‍♂️';
      case automotive:
        return '🚗';
      case others:
        return '✨';
      default:
        return '📋';
    }
  }
}

// ─── Status Task/Gig ─────────────────────────────────────────
class GigStatus {
  static const String open = 'OPEN';
  static const String pending = 'PENDING';
  static const String locked = 'LOCKED';
  static const String inProgress = 'IN-PROGRESS';
  static const String delivered = 'DELIVERED';
  static const String completed = 'COMPLETED';
  static const String cancelled = 'CANCELLED';
  static const String service = 'SERVICE';
  static const String disabled = 'DISABLED';
  static const String disabledService = 'DISABLED';
}

// ─── Role User ───────────────────────────────────────────────
class UserRole {
  static const String customer = 'customer';
  static const String runner = 'runner';
}

// ─── Tempoh Masa SLA (dalam minit) ikut Kategori ─────────────
class SlaDuration {
  static int forCategory(String category) {
    switch (category) {
      case TaskCategory.food:
        return 30;
      case TaskCategory.shopping:
        return 60;
      case TaskCategory.print:
        return 20;
      case TaskCategory.heavy:
        return 90;
      case TaskCategory.parcel:
        return 45;
      case TaskCategory.cleaning:
        return 120;
      case TaskCategory.petCare:
        return 60;
      case TaskCategory.errands:
        return 60;
      case TaskCategory.automotive:
        return 120;
      case TaskCategory.others:
        return 60;
      default:
        return 60;
    }
  }
}

// ─── Nama Table DB ───────────────────────────────────────────
class DbTable {
  static const String users = 'users';
  static const String gigs = 'gigs';
  static const String statusLogs = 'status_logs';
  static const String reviews = 'reviews';
}
