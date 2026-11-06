import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../widgets/glass_nav_button.dart';
import 'package:flutter/services.dart'; //  REQUIRED for TextInputFormatter
import 'package:hugeicons/hugeicons.dart';
//  REQUIRED for LiquidGlassSettings
import 'booking_ticket_screen.dart';
import '../../models/user_data.dart';
import 'package:ngam/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/booking_notification_service.dart'; //  ADD THIS LINE
import '../../widgets/glass_toast.dart'; //  ADD THIS TO YOUR IMPORTS
import '../../services/voucher_service.dart';
import '../../widgets/voucher_selection_sheet.dart';
import '../../widgets/customer_payment_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math'; //  Required for generating the short ID
import 'dart:async';

enum BookingType {
  service,
  barber,
  dining,
  hospitality,
  automotive,
  health,
  facility,
  beauty,
  retail,
}

class BookingsView extends StatefulWidget {
  final String shopId; //  ADD THIS
  final String shopName;
  final String category;
  final String shopImage;

  const BookingsView({
    super.key,
    required this.shopId, //  ADD THIS
    this.shopName = "Zul Barber Shop",
    this.category = "Barber",
    this.shopImage = "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400",
  });

  @override
  State<BookingsView> createState() => _BookingsViewState();
}

class _BookingsViewState extends State<BookingsView> {
  List<Map<String, dynamic>> _activeBookings = [];

  late final TextEditingController _customerNameCtrl;
  late final TextEditingController _customerPhoneCtrl;
  late final TextEditingController _bookingNotesCtrl;

  int _selectedDateIndex = 0; // Keep this!
  DateTime _selectedCalendarDate = DateTime.now(); //  ADD THIS FOR THE CALENDAR
  int _selectedTimeIndex = -1;

  final Set<int> _selectedServices = {0};
  final Set<int> _selectedAddons = {};
  bool _hasAllergies = false;

  int _selectedPaymentIndex = 0;
  Map<String, dynamic>? _selectedVoucher;
  double _voucherDiscount = 0.0;
  bool _userDismissedVoucher = false;

  int _frontCardIndex = 0;
  int _currentStep = 0;
  bool _isSubmitted = false;
  //  We save the ID here so the success screen can use it
  String _generatedBookingId = "";

  late BookingType _bookingType;
  List<Map<String, String>> _staffs = [];
  final List<Map<String, String>> _dates = [];
  final List<String> _times = ["8:00", "9:00", "10:00", "11:00", "12:00", "14:00", "15:00", "16:00", "17:00", "19:00", "20:00"];
  List<Map<String, String>> _servicesList = [];
  List<Map<String, String>> _addonsList = [];

  BookingType _detectBookingType([String? overrideCategory, String? overrideName]) {
    final cat = (overrideCategory ?? widget.category).toLowerCase().trim();
    final name = (overrideName ?? widget.shopName).toLowerCase().trim();

    // 1. HOSPITALITY / HOTEL / RESORT / HOMESTAY / PENGINAPAN
    if (cat.contains('hotel') ||
        cat.contains('resort') ||
        cat.contains('homestay') ||
        cat.contains('chalet') ||
        cat.contains('motel') ||
        cat.contains('lodge') ||
        cat.contains('villa') ||
        cat.contains('vila') ||
        cat.contains('stay') ||
        cat.contains('penginapan') ||
        cat.contains('bilik') ||
        cat.contains('guesthouse') ||
        cat.contains('hostel') ||
        cat.contains('glamping') ||
        cat.contains('airbnb') ||
        cat.contains('dorm') ||
        name.contains('hotel') ||
        name.contains('resort') ||
        name.contains('homestay') ||
        name.contains('chalet') ||
        name.contains('motel') ||
        name.contains('villa') ||
        name.contains('vila') ||
        name.contains('lodge') ||
        name.contains('stay') ||
        name.contains('glamping') ||
        name.contains('guesthouse') ||
        name.contains('hostel')) {
      return BookingType.hospitality;
    }

    // 2. DINING / KEDAI MAKAN / RESTORAN / F&B
    if (cat == 'fnb' ||
        cat.contains('fnb') ||
        cat.contains('f&b') ||
        cat.contains('food') ||
        cat.contains('makan') ||
        cat.contains('restaurant') ||
        cat.contains('restoran') ||
        cat.contains('cafe') ||
        cat.contains('kafe') ||
        cat.contains('dining') ||
        cat.contains('coffee') ||
        cat.contains('kopi') ||
        cat.contains('kopitiam') ||
        cat.contains('warung') ||
        cat.contains('dapur') ||
        cat.contains('bistro') ||
        cat.contains('kitchen') ||
        cat.contains('bakery') ||
        cat.contains('pastry') ||
        cat.contains('burger') ||
        cat.contains('steamboat') ||
        cat.contains('satay') ||
        cat.contains('sate') ||
        cat.contains('nasi') ||
        cat.contains('mee') ||
        cat.contains('ayam') ||
        cat.contains('seafood') ||
        cat.contains('mamak') ||
        cat.contains('tomyam') ||
        cat.contains('beverage') ||
        cat.contains('minuman') ||
        cat.contains('dessert') ||
        name.contains('cafe') ||
        name.contains('kafe') ||
        name.contains('restoran') ||
        name.contains('restaurant') ||
        name.contains('coffee') ||
        name.contains('kopi') ||
        name.contains('kopitiam') ||
        name.contains('bistro') ||
        name.contains('kitchen') ||
        name.contains('dapur') ||
        name.contains('warung') ||
        name.contains('burger') ||
        name.contains('steamboat') ||
        name.contains('nasi') ||
        name.contains('mee') ||
        name.contains('ayam') ||
        name.contains('satay') ||
        name.contains('sate') ||
        name.contains('seafood') ||
        name.contains('bakery') ||
        name.contains('roti') ||
        name.contains('mamak') ||
        name.contains('tomyam') ||
        name.contains('makan') ||
        name.contains('cendol') ||
        name.contains('laksa')) {
      return BookingType.dining;
    }

    // 3. BARBER / SALON LELAKI / GUNTING RAMBUT
    if (cat.contains('barber') ||
        cat.contains('gunting rambut') ||
        cat.contains('fade') ||
        cat.contains('pomade') ||
        cat.contains('salon lelaki') ||
        name.contains('barber') ||
        name.contains('gunting rambut') ||
        name.contains('barbershop') ||
        name.contains('fade') ||
        name.contains('pomade')) {
      return BookingType.barber;
    }

    // 4. FACILITY / COURT / SUKAN
    if (cat.contains('sport') ||
        cat.contains('sukan') ||
        cat.contains('court') ||
        cat.contains('gelanggang') ||
        cat.contains('futsal') ||
        cat.contains('badminton') ||
        cat.contains('pickleball') ||
        cat.contains('tennis') ||
        cat.contains('squash') ||
        cat.contains('padang') ||
        cat.contains('kemudahan') ||
        cat.contains('arena') ||
        cat.contains('gym') ||
        cat.contains('fitness') ||
        cat.contains('swimming') ||
        cat.contains('renang') ||
        name.contains('sport') ||
        name.contains('sukan') ||
        name.contains('futsal') ||
        name.contains('badminton') ||
        name.contains('pickleball') ||
        name.contains('tennis') ||
        name.contains('court') ||
        name.contains('gelanggang') ||
        name.contains('arena') ||
        name.contains('gym') ||
        name.contains('fitness') ||
        name.contains('padang')) {
      return BookingType.facility;
    }

    // 5. AUTOMOTIVE / BENGKEL
    if (cat.contains('workshop') ||
        cat.contains('auto') ||
        cat.contains('car') ||
        cat.contains('motor') ||
        cat.contains('bengkel') ||
        cat.contains('wash') ||
        cat.contains('cucian') ||
        cat.contains('tyre') ||
        cat.contains('tayar') ||
        cat.contains('garage') ||
        cat.contains('detailing') ||
        name.contains('auto') ||
        name.contains('car wash') ||
        name.contains('cucian') ||
        name.contains('bengkel') ||
        name.contains('tyre') ||
        name.contains('tayar') ||
        name.contains('motor') ||
        name.contains('garage') ||
        name.contains('detailing')) {
      return BookingType.automotive;
    }

    // 6. HEALTH / KLINIK / PERUBATAN
    if (cat.contains('health') ||
        cat.contains('clinic') ||
        cat.contains('klinik') ||
        cat.contains('dental') ||
        cat.contains('gigi') ||
        cat.contains('perubatan') ||
        cat.contains('farmasi') ||
        cat.contains('pharmacy') ||
        cat.contains('poliklinik') ||
        cat.contains('doktor') ||
        cat.contains('fisioterapi') ||
        name.contains('clinic') ||
        name.contains('klinik') ||
        name.contains('dental') ||
        name.contains('gigi') ||
        name.contains('poliklinik') ||
        name.contains('farmasi') ||
        name.contains('dr.')) {
      return BookingType.health;
    }

    // 7. BEAUTY / SALON / SPA / ESTETIKA
    if (cat.contains('salon') ||
        cat.contains('spa') ||
        cat.contains('facial') ||
        cat.contains('massage') ||
        cat.contains('urut') ||
        cat.contains('reflexology') ||
        cat.contains('refleksologi') ||
        cat.contains('nail') ||
        cat.contains('kuku') ||
        cat.contains('beauty') ||
        cat.contains('kecantikan') ||
        cat.contains('waxing') ||
        cat.contains('lash') ||
        cat.contains('bulu mata') ||
        cat.contains('estetik') ||
        cat.contains('aesthetic') ||
        cat.contains('makeup') ||
        cat.contains('mekap') ||
        cat.contains('andam') ||
        cat.contains('muslimah') ||
        name.contains('salon') ||
        name.contains('spa') ||
        name.contains('facial') ||
        name.contains('massage') ||
        name.contains('urut') ||
        name.contains('reflexology') ||
        name.contains('refleksologi') ||
        name.contains('nail') ||
        name.contains('beauty') ||
        name.contains('kecantikan') ||
        name.contains('lash') ||
        name.contains('aesthetic') ||
        name.contains('makeup') ||
        name.contains('muslimah')) {
      return BookingType.beauty;
    }

    // 8. RETAIL / SHOPPING / BUTIK / KEDAI RUNCIT
    if (cat.contains('retail') ||
        cat.contains('runcit') ||
        cat.contains('pasar') ||
        cat.contains('market') ||
        cat.contains('grocery') ||
        cat.contains('butik') ||
        cat.contains('boutique') ||
        cat.contains('fashion') ||
        cat.contains('fesyen') ||
        cat.contains('baju') ||
        cat.contains('pakaian') ||
        cat.contains('kasut') ||
        cat.contains('tudung') ||
        cat.contains('jubah') ||
        cat.contains('perfume') ||
        cat.contains('minyak wangi') ||
        cat.contains('aksesori') ||
        cat.contains('bundle') ||
        cat.contains('perabot') ||
        cat.contains('buku') ||
        cat.contains('florist') ||
        cat.contains('bunga') ||
        cat.contains('shopping') ||
        name.contains('butik') ||
        name.contains('boutique') ||
        name.contains('fashion') ||
        name.contains('fesyen') ||
        name.contains('tudung') ||
        name.contains('jubah') ||
        name.contains('perfume') ||
        name.contains('florist') ||
        name.contains('bundle') ||
        name.contains('shopping')) {
      return BookingType.retail;
    }

    // 9. SERVICE / KHIDMAT AM & JURUTEKNIK
    return BookingType.service;
  }

  void _initCategoryTemplate() {
    _bookingType = _detectBookingType();

    switch (_bookingType) {
      case BookingType.dining:
        _staffs = [
          {
            "name": "Meja Santai Tingkap (2-4 Pax)",
            "specialty": "Pemandangan Luar & Pencahayaan Cantik",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400",
          },
          {
            "name": "Meja Booth Sofa (4-6 Pax)",
            "specialty": "Ruang Privasi & Selesa Berkumpul",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=400",
          },
          {
            "name": "Meja Jamuan Keluarga (6-10 Pax)",
            "specialty": "Ruang Luas Tengah Restoran",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?q=80&w=400",
          },
          {
            "name": "Bilik VIP Eksklusif (10-15 Pax)",
            "specialty": "Bilik Tertutup Berhawa Dingin & TV",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1544025162-d76694265947?q=80&w=400",
          },
        ];
        _servicesList = [
          {"name": "Tempahan Meja Santai (Walk-in Hold)", "price": "RM0", "time": "90m"},
          {"name": "Pakej Makan Malam Kombo Keluarga", "price": "RM120", "time": "90m"},
          {"name": "Pakej Sambutan Hari Jadi / Ulang Tahun", "price": "RM85", "time": "120m"},
          {"name": "Set Minum Petang Hi-Tea & Pastri", "price": "RM45", "time": "60m"},
          {"name": "Pakej Chef Tasting / Omakase Khas", "price": "RM180", "time": "120m"},
        ];
        _addonsList = [
          {"name": "Kerusi Bayi (Baby Chair)", "price": "+RM0", "time": "+0m"},
          {"name": "Hiasan Meja Hari Jadi & Belon Eksklusif", "price": "+RM35", "time": "+0m"},
          {"name": "Kek Coklat Fudge Mini & Lilin Sambutan", "price": "+RM25", "time": "+0m"},
          {"name": "Pilihan Meja Berhawa Dingin Sejuk", "price": "+RM0", "time": "+0m"},
          {"name": "Jug Jus Buah Segar (Untuk 4 Pax)", "price": "+RM18", "time": "+0m"},
        ];
        break;

      case BookingType.hospitality:
        _staffs = [
          {
            "name": "Standard Queen Room (1-2 Pax)",
            "specialty": "Katil Queen Selesa & Bilik Mandi En-Suite",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1590490360182-c33d57733427?q=80&w=400",
          },
          {
            "name": "Deluxe King Suite (2 Pax)",
            "specialty": "Pemandangan Menarik, Balkoni & Tab Mandi",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1566665797739-1674de7a421a?q=80&w=400",
          },
          {
            "name": "Family Suite Room (3-5 Pax)",
            "specialty": "2 Katil Queen, Ruang Tamu & Dapur Kecil",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?q=80&w=400",
          },
          {
            "name": "Private Pool Villa / Homestay (6-10 Pax)",
            "specialty": "Kolam Peribadi, Kawasan BBQ & 3 Bilik Tidur",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1540555700478-4be289fbecef?q=80&w=400",
          },
        ];
        _servicesList = [
          {"name": "Penginapan 1 Malam (Bilik Sahaja / Room Only)", "price": "RM150", "time": "1440m"},
          {"name": "Pakej Staycation + Sarapan Pagi Bufet (2 Pax)", "price": "RM210", "time": "1440m"},
          {"name": "Pakej Percutian Keluarga Penuh (Bilik + Makan + Kolam)", "price": "RM350", "time": "1440m"},
          {"name": "Day Use Room / Transit Rehat (6 Jam)", "price": "RM80", "time": "360m"},
          {"name": "Pakej Romantik Bulan Madu / Honeymoon Surprise", "price": "RM290", "time": "1440m"},
        ];
        _addonsList = [
          {"name": "Sarapan Pagi Bufet Tambahan (Dewasa/Kanak)", "price": "+RM25", "time": "+0m"},
          {"name": "Katil Tambahan (Extra Bed & Bantal)", "price": "+RM45", "time": "+0m"},
          {"name": "Daftar Keluar Lewat (Late Check-Out hingga 2:00 PM)", "price": "+RM30", "time": "+0m"},
          {"name": "Hiasan Bilik Romantik & Sejambak Bunga", "price": "+RM60", "time": "+0m"},
          {"name": "Set Arang & Peralatan Barbeku (BBQ Pit)", "price": "+RM40", "time": "+0m"},
          {"name": "Slot Parkir Kereta Berbumbung Terjamin", "price": "+RM10", "time": "+0m"},
        ];
        break;

      case BookingType.barber:
        _staffs = [
          {
            "name": "Mana-mana Barber Bertugas (Paling Pantas)",
            "specialty": "Giliran Pertama Tanpa Tunggu Lama",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=400",
          },
          {
            "name": "Adi Mawi (Master Barber)",
            "specialty": "Fade King & Pakar Pompadour Klasik",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=400",
          },
          {
            "name": "Haris Iqram (Senior Barber & Beard Master)",
            "specialty": "Pakar Guntingan Moden, Taper & Shave",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=400",
          },
          {
            "name": "Zul 'The Barber' (Founder & Stylist)",
            "specialty": "Konsultasi Bentuk Wajah & Gaya Premium",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?q=80&w=400",
          },
        ];
        _servicesList = [
          {"name": "Signature Fade & Scissor Haircut", "price": "RM35", "time": "30m"},
          {"name": "Guntingan Rambut Asas & Trim Kemas", "price": "RM25", "time": "20m"},
          {"name": "Gunting Rambut Kanak-kanak / Pelajar", "price": "RM20", "time": "20m"},
          {"name": "Full Royal Shave & Hot Towel", "price": "RM30", "time": "25m"},
          {"name": "Pakej Gentleman (Haircut + Shave + Wash + Massage)", "price": "RM65", "time": "50m"},
          {"name": "Rawatan Kelemumur & Kulit Kepala (Scalp Treatment)", "price": "RM45", "time": "35m"},
          {"name": "Pewarna Rambut / Bleach & Tone", "price": "RM80", "time": "60m"},
        ];
        _addonsList = [
          {"name": "Rawatan Tuala Panas & Minyak Herba", "price": "+RM15", "time": "+10m"},
          {"name": "Cuci Rambut Menthol Dingin & Blow Dry", "price": "+RM10", "time": "+10m"},
          {"name": "Urutan Leher & Bahu Santai (Massage)", "price": "+RM12", "time": "+10m"},
          {"name": "Trim & Bentuk Janggut / Misai Rapi", "price": "+RM10", "time": "+10m"},
          {"name": "Sapuan Pomade / Hair Wax Premium", "price": "+RM5", "time": "+0m"},
        ];
        break;

      case BookingType.automotive:
        _staffs = [
          {
            "name": "Stesen Servis Pantas",
            "specialty": "Tukar Minyak, Filter & Diagnostic Komputer",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=400",
          },
          {
            "name": "Bay Cuci Kereta Snow Wash & Detailing",
            "specialty": "Salun Kilat, Nano Coating & Interior Vacuum",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1601362840469-51e4d8d58785?q=80&w=400",
          },
          {
            "name": "Pusat Diagnostik & Tayar 3D Laser",
            "specialty": "Pakar Mekanikal Bertauliah & Balancing",
            "rating": "4.8",
            "image": "https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=400",
          },
        ];
        _servicesList = [
          {"name": "Cuci Salji Snow Wash & Vacuum Dalaman", "price": "RM20", "time": "30m"},
          {"name": "Servis Minyak Hitam Semi-Sintetik & Filter", "price": "RM110", "time": "45m"},
          {"name": "Servis Minyak Hitam Fully Synthetic (10k km)", "price": "RM180", "time": "50m"},
          {"name": "Wax & Polish Kilat Body 3-Lapisan", "price": "RM75", "time": "60m"},
          {"name": "Alignment 3D Komputer & Balancing 4 Roda", "price": "RM45", "time": "35m"},
          {"name": "Pemeriksaan Keselamatan 25 Titik", "price": "RM0", "time": "20m"},
        ];
        _addonsList = [
          {"name": "Cuci Ruang Enjin Menggunakan Stim", "price": "+RM25", "time": "+20m"},
          {"name": "Sanitasi Asap Fogging Anti-Bakteria Kabin", "price": "+RM20", "time": "+15m"},
          {"name": "Tukar Bilah Wiper Silikon Baharu Depan", "price": "+RM35", "time": "+10m"},
          {"name": "Top-up Radiator Coolant & Minyak Brek", "price": "+RM15", "time": "+5m"},
          {"name": "Coating Cermin Anti-Hujan Rain-Repellent", "price": "+RM25", "time": "+10m"},
        ];
        break;

      case BookingType.health:
        _staffs = [
          {
            "name": "Doktor Perubatan Am Bertugas Seterusnya",
            "specialty": "Giliran Pantas & Rawatan Segera",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?q=80&w=400",
          },
          {
            "name": "Dr. Amirul Hakim",
            "specialty": "Pakar Kesihatan Keluarga & Kronik",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1622253692010-333f2da6031d?q=80&w=400",
          },
          {
            "name": "Dr. Farah Nadhirah",
            "specialty": "Pakar Kesihatan Kanak-kanak & Wanita",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1594824813590-78531e217277?q=80&w=400",
          },
          {
            "name": "Dr. Dental (Pakar Pergigian)",
            "specialty": "Pembersihan Karang Gigi, Tampalan & Pemutihan",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1629909613654-28e377c37b09?q=80&w=400",
          },
        ];
        _servicesList = [
          {"name": "Konsultasi Am Doktor & Pemeriksaan Kesihatan", "price": "RM40", "time": "20m"},
          {"name": "Pakej Cuci Karang Gigi (Scaling & Polishing)", "price": "RM85", "time": "35m"},
          {"name": "Pemeriksaan Kesihatan Komprehensif Eksekutif", "price": "RM120", "time": "45m"},
          {"name": "Rawatan Ringan, Jahitan & Dressing Luka", "price": "RM45", "time": "25m"},
          {"name": "Suntikan Vaksin / Vitamin Booster", "price": "RM50", "time": "15m"},
        ];
        _addonsList = [
          {"name": "Ujian Pantas Glukosa (Gula) & Kolesterol", "price": "+RM20", "time": "+10m"},
          {"name": "Ujian Tekanan Darah & ECG Jantung", "price": "+RM35", "time": "+15m"},
          {"name": "Ujian Air Kencing Urine Test Analisis", "price": "+RM15", "time": "+10m"},
          {"name": "Ubat-ubatan Tambahan Asas (Demam/Batuk)", "price": "+RM20", "time": "+0m"},
        ];
        break;

      case BookingType.facility:
        _staffs = [
          {
            "name": "Court 1 (Badminton Rubber Mat BWF Approved)",
            "specialty": "Lantai Getah Hijau BWF & Pencahayaan Anti-Glare",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?q=80&w=400",
          },
          {
            "name": "Court 2 (Pickleball Tournament Indoor)",
            "specialty": "Lantai Khas Pickleball & Jaring Bertauliah",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=400",
          },
          {
            "name": "Gelanggang Futsal Sintetik Premium",
            "specialty": "Rumput Tiruan Lembut Bertaraf Antarabangsa",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1529900240041-22f1df4d189a?q=80&w=400",
          },
          {
            "name": "Court VIP Berhawa Dingin (Aircond Lounge)",
            "specialty": "Kawasan Eksklusif Tertutup & Ruang Rehat VIP",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1526676037777-05a232554f77?q=80&w=400",
          },
        ];
        _servicesList = [
          {"name": "Sesi 1 Jam Permainan Santai", "price": "RM25", "time": "60m"},
          {"name": "Sesi 2 Jam Kombo Perlawanan", "price": "RM45", "time": "120m"},
          {"name": "Sesi 3 Jam Latihan Pasukan / Liga Mini", "price": "RM65", "time": "180m"},
          {"name": "Pas Pasukan / Kelab (Slot Bulanan)", "price": "RM160", "time": "240m"},
        ];
        _addonsList = [
          {"name": "Sewa 2x Raket & 1 Tiub Bulu Tangkis (3 Biji)", "price": "+RM15", "time": "+0m"},
          {"name": "Sewa Raket Pickleball & 2 Bola Khas", "price": "+RM12", "time": "+0m"},
          {"name": "Sewa Bibs Pasukan (2 Warna Berbeza)", "price": "+RM10", "time": "+0m"},
          {"name": "Sewa Bola Futsal Rasmi FIFA", "price": "+RM8", "time": "+0m"},
          {"name": "Pek Air Mineral Sejuk (3 Botol 1.5L)", "price": "+RM10", "time": "+0m"},
          {"name": "Sewa Kasut Sukan (Saiz Biasa 38-44)", "price": "+RM8", "time": "+0m"},
        ];
        break;

      case BookingType.beauty:
        _staffs = [
          {
            "name": "Mana-mana Terapis Wanita Bertugas",
            "specialty": "Giliran Pantas & Layanan Lembut",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=400",
          },
          {
            "name": "Puan Farhana (Senior Aesthetician)",
            "specialty": "Pakar Kulit Wajah, Facial Glowing & Anti-Aging",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?q=80&w=400",
          },
          {
            "name": "Kak Lily (Pakar Urutan & Spa)",
            "specialty": "Urutan Tradisional, Herba & Refleksologi",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1580489944761-15a19d654956?q=80&w=400",
          },
          {
            "name": "Sarah (Nail & Lash Specialist)",
            "specialty": "Manicure Gel, Nail Art & Lash Lift Lentik",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1560066984-138dadb4c035?q=80&w=400",
          },
        ];
        _servicesList = [
          {"name": "Rawatan Glowing Facial & Hydrating Spa", "price": "RM85", "time": "75m"},
          {"name": "Urutan Aromaterapi Seluruh Badan & Refleksologi", "price": "RM75", "time": "60m"},
          {"name": "Pakej Spa Herba Tradisional & Mandian Bunga", "price": "RM120", "time": "90m"},
          {"name": "Manicure & Pedicure Gel Spa Bersih", "price": "RM55", "time": "50m"},
          {"name": "Rawatan Rambut Spa Muslimah & Masker Keratin", "price": "RM70", "time": "60m"},
          {"name": "Lash Lift & Tinting Bulu Mata Lentik", "price": "RM50", "time": "45m"},
        ];
        _addonsList = [
          {"name": "Lulur Badan & Body Scrub Herba Wangi", "price": "+RM25", "time": "+15m"},
          {"name": "Minyak Aromaterapi Essential Khas", "price": "+RM15", "time": "+0m"},
          {"name": "Masker Kolagen Emas Anti-Kedut Wajah", "price": "+RM20", "time": "+0m"},
          {"name": "Urutan Batu Panas (Hot Stone Therapy)", "price": "+RM30", "time": "+15m"},
          {"name": "Serum Rambut Argan Oil & Vitamin Booster", "price": "+RM15", "time": "+0m"},
        ];
        break;

      case BookingType.retail:
        _staffs = [
          {
            "name": "Personal Shopper & Perunding Gaya",
            "specialty": "Bimbingan Produk, Padanan & Saiz",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1441986300917-64674bd600d8?q=80&w=400",
          },
          {
            "name": "Bilik Fitting & Percubaan Eksklusif VIP",
            "specialty": "Ruang Percubaan Pakaian VIP Selesa",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1472851294608-062f824d29cc?q=80&w=400",
          },
          {
            "name": "Slot Ambil Barang Ekspres (Click & Collect)",
            "specialty": "Pengambilan Pantas Tanpa Perlu Beratur",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1526178613552-2b45c6c302f0?q=80&w=400",
          },
        ];
        _servicesList = [
          {"name": "Janji Temu Lawatan Butik & Akses Koleksi", "price": "RM0", "time": "30m"},
          {"name": "Sesi Konsultasi Fesyen & Ukuran Khas", "price": "RM30", "time": "45m"},
          {"name": "Sesi Fitting Baju Pengantin / Busana Majlis VIP", "price": "RM60", "time": "60m"},
        ];
        _addonsList = [
          {"name": "Khidmat Ukur & Jahit Alteration Segera", "price": "+RM20", "time": "+15m"},
          {"name": "Balutan Hadiah Eksklusif & Kad Ucapan Khas", "price": "+RM15", "time": "+0m"},
          {"name": "Penghantaran Terus ke Kenderaan (Curbside)", "price": "+RM0", "time": "+0m"},
        ];
        break;

      case BookingType.service:
        _staffs = [
          {
            "name": "Juruteknik Bertauliah Seterusnya (Segera)",
            "specialty": "Pakar Khidmat Am & Giliran Paling Cepat",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1581092921461-eab62e97a780?q=80&w=400",
          },
          {
            "name": "Pak Din (Pakar Servis Aircond & Elektrik)",
            "specialty": "Berpengalaman 12 Tahun, Kemas & Pantas",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1621905251189-08b45d6a269e?q=80&w=400",
          },
          {
            "name": "Crew Bersih Pro (Pakar Pembersihan Rumah)",
            "specialty": "Deep Cleaning & Sanitasi Menyeluruh",
            "rating": "4.9",
            "image": "https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=400",
          },
          {
            "name": "Studio Foto & Potret Kreatif",
            "specialty": "Sesi Penggambaran Profil & Studio",
            "rating": "5.0",
            "image": "https://images.unsplash.com/photo-1520854221256-17451cc331bf?q=80&w=400",
          },
        ];
        _servicesList = [
          {"name": "Servis Cuci Aircond Kimia Asas (1 Unit / 1.0-1.5HP)", "price": "RM75", "time": "45m"},
          {"name": "Servis Aircond Overhaul Kimia Lengkap (1 Unit)", "price": "RM130", "time": "75m"},
          {"name": "Pemeriksaan & Pembaikan Pendawaian Elektrik", "price": "RM60", "time": "45m"},
          {"name": "Deep Cleaning Rumah / Apartment (Asas 2 Jam)", "price": "RM110", "time": "120m"},
          {"name": "Pemeriksaan & Servis Paip Tersumbat / Bocor", "price": "RM70", "time": "45m"},
          {"name": "Sesi Fotografi Studio / Potret Profil (1 Jam)", "price": "RM150", "time": "60m"},
        ];
        _addonsList = [
          {"name": "Tambah Gas Aircond R32 / R410A Penuh", "price": "+RM35", "time": "+15m"},
          {"name": "Pembersihan Outdoor Unit Condenser Ekstra", "price": "+RM25", "time": "+15m"},
          {"name": "Sanitasi Kabus Anti-Bakteria & Virus", "price": "+RM30", "time": "+15m"},
          {"name": "Tukar Soket / Suis Lampu Tambahan", "price": "+RM20", "time": "+10m"},
          {"name": "Pembersihan Karpet / Kusyen Ekstra", "price": "+RM25", "time": "+15m"},
        ];
        break;
    }
  }

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      "name": "DuitNow QR Pantas (Zero Fee)",
      "subtitle": "Imbas guna mana-mana aplikasi Bank atau e-Wallet (TNG, GrabPay, MAE)",
      "icon": HugeIcons.strokeRoundedQrCode,
      "type": "duitnow",
      "badge": "DISYORKAN",
    },
    {
      "name": "Perbankan FPX & Kad Debit / Kredit",
      "subtitle": "Maybank2u, CIMB Clicks, Bank Islam, Visa & Mastercard (CHIP Asia)",
      "icon": HugeIcons.strokeRoundedCreditCard,
      "type": "fpx_card",
    },
    {
      "name": "Bayar di Kaunter (Tunai)",
      "subtitle": "Buat bayaran secara fizikal terus di premis kedai",
      "icon": HugeIcons.strokeRoundedCash01,
      "type": "cash",
    },
  ];

  String _lastPaymentStatus = 'unpaid';
  String _lastPaymentMethod = 'Bayar di Kedai (Tunai)';
  int _paxCount = 2;
  int _nightsCount = 1;
  final TextEditingController _industryDetailCtrl = TextEditingController();

  StreamSubscription<List<Map<String, dynamic>>>? _timeStream;
  String? _holdingRecordId;

  double _parseMoney(String s) =>
      double.tryParse(RegExp(r'[0-9]+(\.[0-9]+)?').firstMatch(s)?.group(0) ?? '') ?? 0.0;

  String _fmtMoney(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  double get _subtotal {
    double total = 0;
    final int multiplier = _bookingType == BookingType.hospitality ? _nightsCount : 1;
    for (int i in _selectedServices) {
      if (i >= 0 && i < _servicesList.length) {
        total += _parseMoney(_servicesList[i]["price"] ?? '') * multiplier;
      }
    }
    for (int i in _selectedAddons) {
      if (i >= 0 && i < _addonsList.length) {
        total += _parseMoney(_addonsList[i]["price"] ?? '');
      }
    }
    return double.parse(total.toStringAsFixed(2));
  }

  double get _totalPrice {
    final sub = _subtotal;
    final total = (sub - _voucherDiscount).clamp(0.0, 999999.0);
    return double.parse(total.toStringAsFixed(2));
  }

  String get _totalPriceLabel => _fmtMoney(_totalPrice);

  int get _totalTime {
    int time = 0;
    for (int i in _selectedServices) { if (i >= 0 && i < _servicesList.length) time += int.tryParse((_servicesList[i]["time"] ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0; }
    for (int i in _selectedAddons) { if (i >= 0 && i < _addonsList.length) time += int.tryParse((_addonsList[i]["time"] ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0; }
    return time;
  }

  String get _pageTitle {
    if (_isSubmitted) return "Booking complete!";
    switch (_bookingType) {
      case BookingType.dining:
        if (_currentStep == 0) return "Pilih saiz meja:";
        if (_currentStep == 1) return "Pakej & keperluan meja:";
        return "Sahkan tempahan meja:";
      case BookingType.hospitality:
        if (_currentStep == 0) return "Pilih jenis bilik / suite:";
        if (_currentStep == 1) return "Pakej penginapan & tambahan:";
        return "Sahkan tempahan penginapan:";
      case BookingType.barber:
        if (_currentStep == 0) return "Pilih tukang gunting / barber:";
        if (_currentStep == 1) return "Pilih gaya potongan & rawatan:";
        return "Sahkan tempahan barber:";
      case BookingType.automotive:
        if (_currentStep == 0) return "Pilih stesen servis:";
        if (_currentStep == 1) return "Pilih pakej kenderaan:";
        return "Sahkan servis kenderaan:";
      case BookingType.health:
        if (_currentStep == 0) return "Pilih doktor / pakar:";
        if (_currentStep == 1) return "Pilih rawatan & ujian:";
        return "Sahkan janji temu klinik:";
      case BookingType.facility:
        if (_currentStep == 0) return "Pilih gelanggang / court:";
        if (_currentStep == 1) return "Pilih tempoh & peralatan:";
        return "Sahkan tempahan court:";
      case BookingType.beauty:
        if (_currentStep == 0) return "Pilih terapis / juruestetik:";
        if (_currentStep == 1) return "Pilih rawatan spa & estetika:";
        return "Sahkan tempahan spa & salun:";
      case BookingType.retail:
        if (_currentStep == 0) return "Pilih jenis sesi / bantuan:";
        if (_currentStep == 1) return "Pakej & keperluan lawatan:";
        return "Sahkan janji temu butik:";
      case BookingType.service:
        if (_currentStep == 0) return "Pilih juruteknik / pakar:";
        if (_currentStep == 1) return "Pilih servis & tambahan:";
        return "Sahkan tempahan servis:";
    }
  }

  String get _mainServiceTitle {
    switch (_bookingType) {
      case BookingType.dining: return "Pilihan Meja / Pakej Makan";
      case BookingType.hospitality: return "Pilihan Bilik & Pakej Penginapan";
      case BookingType.barber: return "Pakej Potongan & Penggayaan";
      case BookingType.automotive: return "Pakej Servis Kenderaan";
      case BookingType.health: return "Pilihan Rawatan & Konsultasi";
      case BookingType.facility: return "Tempoh Sesi Permainan";
      case BookingType.beauty: return "Pilihan Rawatan Utama";
      case BookingType.retail: return "Pilihan Sesi & Bantuan";
      case BookingType.service: return "Servis Utama";
    }
  }

  String get _addonsTitle {
    switch (_bookingType) {
      case BookingType.dining: return "Permintaan & Kemudahan Khas";
      case BookingType.hospitality: return "Kemudahan & Fasiliti Tambahan";
      case BookingType.barber: return "Servis Tambahan & Rawatan";
      case BookingType.automotive: return "Servis Tambahan Pilihan";
      case BookingType.health: return "Ujian & Rawatan Lanjutan";
      case BookingType.facility: return "Sewa Peralatan Tambahan";
      case BookingType.beauty: return "Pakej Tambahan & Aroma";
      case BookingType.retail: return "Perkhidmatan Tambahan";
      case BookingType.service: return "Servis Tambahan (Add-ons)";
    }
  }

  String get _healthToggleTitle {
    switch (_bookingType) {
      case BookingType.dining: return "Alergi Makanan / Keperluan Diet Khas?";
      case BookingType.hospitality: return "Bilik Bebas Asap Rokok (Non-Smoking) / Aras Tinggi?";
      case BookingType.barber: return "Kulit Kepala Sensitif atau Alahan Sabun/Pewarna?";
      case BookingType.automotive: return "Kenderaan Saiz Besar (SUV / 4x4 / MPV)?";
      case BookingType.health: return "Alahan Ubat-ubatan (Drug Allergies)?";
      case BookingType.facility: return "Perlu Bantuan Fasilitator / Pengadil?";
      case BookingType.beauty: return "Kulit Sensitif atau Mengandung?";
      case BookingType.retail: return "Perlukan Bantuan Aksesibiliti?";
      case BookingType.service: return "Lokasi Bertingkat / Perlukan Tangga Khas?";
    }
  }

  String get _healthToggleSubtitle {
    switch (_bookingType) {
      case BookingType.dining: return "Tandakan jika ada alahan kacang, makanan laut atau gluten";
      case BookingType.hospitality: return "Tandakan untuk mengutamakan bilik bebas bau rokok atau bilik aras tinggi";
      case BookingType.barber: return "Kulit sensitif terhadap sabun pencuci, minyak wangi atau pewarna rambut";
      case BookingType.automotive: return "Tandakan jika kenderaan anda memerlukan ruang bay besar";
      case BookingType.health: return "Tandakan jika ada alahan kepada sebarang jenis ubat";
      case BookingType.facility: return "Tandakan jika memerlukan bantuan fasilitator perlawanan";
      case BookingType.beauty: return "Tandakan jika ada alahan produk kulit atau perlukan minyak mesra ibu mengandung";
      case BookingType.retail: return "Tandakan jika memerlukan bantuan kerusi roda atau panduan khas";
      case BookingType.service: return "Tandakan jika perlu membawa tangga panjang atau alat pemanjat khas";
    }
  }

  String get _providerSummaryLabel {
    switch (_bookingType) {
      case BookingType.dining: return "Pilihan Meja";
      case BookingType.hospitality: return "Pilihan Bilik / Suite";
      case BookingType.barber: return "Pakar Barber";
      case BookingType.automotive: return "Stesen / Servis";
      case BookingType.health: return "Doktor / Pakar";
      case BookingType.facility: return "Gelanggang / Bilik";
      case BookingType.beauty: return "Terapis / Bilik";
      case BookingType.retail: return "Sesi / Butik";
      case BookingType.service: return "Juruteknik / Staf";
    }
  }

  dynamic get _providerSummaryIcon {
    switch (_bookingType) {
      case BookingType.dining:
        return HugeIcons.strokeRoundedRestaurant01;
      case BookingType.hospitality:
        return HugeIcons.strokeRoundedBedDouble;
      case BookingType.barber:
        return HugeIcons.strokeRoundedScissor;
      case BookingType.automotive:
        return HugeIcons.strokeRoundedCar01;
      case BookingType.health:
        return HugeIcons.strokeRoundedHospital02;
      case BookingType.facility:
        return HugeIcons.strokeRoundedBadminton;
      case BookingType.beauty:
        return HugeIcons.strokeRoundedSparkles;
      case BookingType.retail:
        return HugeIcons.strokeRoundedShoppingBag02;
      case BookingType.service:
        return HugeIcons.strokeRoundedWrench01;
    }
  }

  /// A 'holding' row older than 10 minutes is abandoned (app killed / user left).
  bool _isStaleHold(Map<String, dynamic> b) {
    if (b['status'] != 'holding') return false;
    final created = DateTime.tryParse('${b['created_at']}');
    if (created == null) return false;
    return DateTime.now().toUtc().difference(created.toUtc()) > const Duration(minutes: 10);
  }

  bool _rowTakesSlot(Map<String, dynamic> b, String targetDate, String timeStr,
      bool isSpecificStaff, String selectedStaffId, String selectedStaffName) {
    final status = (b['status'] ?? '').toString();
    if (const ['cancelled', 'rejected', 'declined', 'no_show'].contains(status)) return false;
    if (_isStaleHold(b)) return false;
    final String bDate = b['booking_date']?.toString() ?? '';
    final String bTime = b['booking_time']?.toString() ?? '';
    if (bDate != targetDate) return false;

    int? parseMins(String t) {
      final p = t.split(':');
      if (p.length < 2) return null;
      final h = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return h * 60 + m;
    }

    final int? slotMins = parseMins(timeStr);
    final int? bookedStartMins = parseMins(bTime);
    if (slotMins == null || bookedStartMins == null) {
      if (bTime != timeStr) return false;
    } else {
      final metaMap = (b['booking_metadata'] is Map)
          ? Map<String, dynamic>.from(b['booking_metadata'] as Map)
          : <String, dynamic>{};
      final int bookedDur = (metaMap['estimated_duration_mins'] as num?)?.toInt() ?? 60;
      final int effectiveBookedDur = bookedDur > 60 ? bookedDur : 60;
      final int myDur = _totalTime > 60 ? _totalTime : 60;
      final int bookedEndMins = bookedStartMins + effectiveBookedDur;
      final int slotEndMins = slotMins + myDur;
      final bool overlaps = slotMins < bookedEndMins && slotEndMins > bookedStartMins;
      if (!overlaps) return false;
    }

    if (isSpecificStaff) {
      final meta = (b['booking_metadata'] is Map)
          ? Map<String, dynamic>.from(b['booking_metadata'] as Map)
          : <String, dynamic>{};
      final String bStaffId = (b['staff_id'] ?? meta['staff_id'] ?? '').toString();
      final String bProviderName = (meta['provider_name'] ?? '').toString();
      if (bStaffId.isNotEmpty && bStaffId != selectedStaffId) return false;
      if (bProviderName.isNotEmpty &&
          !bProviderName.toLowerCase().contains('mana-mana') &&
          bProviderName != selectedStaffName) {
        return false;
      }
    }
    return true;
  }

  /// Booked slots visible to this customer: realtime table rows ∪ privacy-safe RPC rows.
  List<Map<String, dynamic>> get _slotRows {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final b in [..._activeBookings, ..._rpcSlots]) {
      final id = b['id']?.toString() ?? '';
      if (id.isNotEmpty && !seen.add(id)) continue;
      out.add(b);
    }
    return out;
  }

  List<Map<String, dynamic>> _rpcSlots = [];
  Timer? _slotRefreshTimer;
  bool _busy = false;

  /// Uses the `get_booked_slots` RPC (see supabase/migrations/20261030_*.sql) which
  /// exposes only slot data (no customer names/phones). Silently ignored until deployed.
  Future<void> _refreshBookedSlots() async {
    if (widget.shopId.length <= 20) return;
    try {
      final res = await Supabase.instance.client
          .rpc('get_booked_slots', params: {'p_business_id': widget.shopId});
      if (res is List) {
        _rpcSlots = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (mounted) setState(() {});
      }
    } catch (_) {
      // RPC not deployed yet → rely on the realtime stream.
    }
  }

  bool _isTimeValid(String timeStr, int dateIndex) {
    if (dateIndex < 0 || dateIndex >= _dates.length) return false;

    final String targetDate = _dates[dateIndex]['fullDate']!.substring(0, 10);
    final String selectedStaffName = _staffs.isNotEmpty && _frontCardIndex < _staffs.length
        ? (_staffs[_frontCardIndex]['name'] ?? '')
        : '';
    final String selectedStaffId = _staffs.isNotEmpty && _frontCardIndex < _staffs.length
        ? (_staffs[_frontCardIndex]['id'] ?? '')
        : '';
    final bool isSpecificStaff = selectedStaffId.isNotEmpty &&
        selectedStaffId != 'any' &&
        !selectedStaffName.toLowerCase().contains('mana-mana');

    // Semak jika slot masa pada tarikh (dan staf) tersebut telah ditempah orang lain
    final bool isSlotTaken = _slotRows.any((b) {
      if (_holdingRecordId != null && b['id']?.toString() == _holdingRecordId) {
        return false; // Jangan kunci slot yang sedang dipegang oleh pengguna ini sendiri
      }
      return _rowTakesSlot(b, targetDate, timeStr, isSpecificStaff, selectedStaffId, selectedStaffName);
    });

    if (isSlotTaken) return false;

    // Check if the time has passed today
    if (dateIndex > 0) return true;

    final now = DateTime.now();
    final parts = timeStr.split(':');
    final timeToCompare = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));

    return timeToCompare.isAfter(now);
  }

  String get _fullServiceSummary {
    final List<String> mainNames = _selectedServices
        .where((i) => i >= 0 && i < _servicesList.length)
        .map((i) => _servicesList[i]['name']!)
        .toList();
    final List<String> addonNames = _selectedAddons
        .where((i) => i >= 0 && i < _addonsList.length)
        .map((i) => _addonsList[i]['name']!)
        .toList();
    if (mainNames.isEmpty) return 'Servis Pilihan';
    if (addonNames.isEmpty) return mainNames.join(', ');
    return '${mainNames.join(', ')} + ${addonNames.join(', ')}';
  }

  Future<void> _autoApplyVoucher() async {
    if (_userDismissedVoucher || _selectedVoucher != null || _subtotal <= 0) return;
    try {
      final best = await VoucherService.getBestAutoVoucher(
        businessId: widget.shopId,
        subtotal: _subtotal,
        category: widget.category,
      );
      if (best != null && mounted && !_userDismissedVoucher && _selectedVoucher == null) {
        final d = (best['calculated_discount'] as num?)?.toDouble() ??
            VoucherService.computeDiscount(best, _subtotal);
        if (d > 0) {
          setState(() {
            _selectedVoucher = best;
            _voucherDiscount = d;
          });
          showGlassToast(context, 'Baucar ${best['code']} (Jimat RM ${_fmtMoney(d)}) auto-digunakan! 🎟️');
        }
      }
    } catch (e) {
      debugPrint('[BookingsView] Auto-apply voucher error: $e');
    }
  }

  void _refreshBookingVoucher() {
    if (_selectedVoucher == null) {
      if (!_userDismissedVoucher && _subtotal > 0) {
        _autoApplyVoucher();
      }
      return;
    }
    final status = VoucherService.checkVoucherEligibility(
      _selectedVoucher!,
      businessId: widget.shopId,
      subtotal: _subtotal,
      category: widget.category,
    );
    if (status['isEligible'] != true) {
      setState(() {
        _selectedVoucher = null;
        _voucherDiscount = 0.0;
      });
      showGlassToast(context, status['reason'] ?? 'Baucar tidak lagi layak untuk tempahan ini.', isError: true);
      if (!_userDismissedVoucher) {
        _autoApplyVoucher();
      }
    } else {
      setState(() {
        _voucherDiscount = (status['discountAmount'] as num?)?.toDouble() ??
            VoucherService.computeDiscount(_selectedVoucher!, _subtotal);
      });
    }
  }

  Future<void> _openBookingVoucherPicker() async {
    final selected = await VoucherSelectionSheet.show(
      context: context,
      businessId: widget.shopId,
      subtotal: _subtotal,
      currentVoucherCode: _selectedVoucher?['code']?.toString(),
      category: widget.category,
    );

    if (selected == null) return;
    if (selected['clear'] == true) {
      setState(() {
        _selectedVoucher = null;
        _voucherDiscount = 0.0;
        _userDismissedVoucher = true;
      });
      if (mounted) showGlassToast(context, 'Baucar telah dibatalkan');
      return;
    }

    final d = (selected['calculated_discount'] as num?)?.toDouble() ??
        VoucherService.computeDiscount(selected, _subtotal);
    if (!mounted) return;
    setState(() {
      _selectedVoucher = selected;
      _voucherDiscount = d;
      _userDismissedVoucher = false;
    });
    showGlassToast(context, 'Baucar ${selected['code']} digunakan! Jimat RM ${_fmtMoney(d)}');
  }

  String get _notesHintText {
    switch (_bookingType) {
      case BookingType.dining:
        return 'Cth: 4 Dewasa, 1 Kerusi Bayi / Meja tepi tingkap';
      case BookingType.hospitality:
        return 'Cth: Tiba lewat sekitar 8:00 PM / minta katil saiz King';
      case BookingType.barber:
        return 'Cth: Gaya Low Fade & kemaskan janggut';
      case BookingType.automotive:
        return 'Cth: No. Plat VAB 1234 (Honda Civic Putih)';
      case BookingType.health:
        return 'Cth: Simptom demam / pemeriksaan kesihatan tahunan';
      case BookingType.facility:
        return 'Cth: 6 pemain / perlukan sewa raket tambahan';
      case BookingType.beauty:
        return 'Cth: Kulit sensitif / pilihan urutan sederhana';
      case BookingType.retail:
        return 'Cth: Saiz M & L / warna tema pastel';
      case BookingType.service:
        return 'Cth: Aircond bilik utama kurang sejuk & berbunyi';
    }
  }

  String _shopName = '';
  String _selectedTime = '';

  String get _resolvedShopName {
    final s = _shopName.trim();
    if (s.isNotEmpty &&
        s.toLowerCase() != 'kedai ngam' &&
        s.toLowerCase() != 'store' &&
        s.toLowerCase() != 'zul barber shop') {
      return s;
    }
    return widget.shopName;
  }

  //  Restored Auto-Save Functions
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

  //  Generates 60 days (~2 months) of valid upcoming dates
  void _generateUpcomingDates() {
    final now = DateTime.now();
    final List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    _dates.clear();
    for (int i = 0; i < 90; i++) { //  Expanded to 90 days for the Calendar
      final date = now.add(Duration(days: i));
      _dates.add({
        "day": weekdays[date.weekday - 1],
        "date": date.day.toString(),
        "month": months[date.month - 1],
        "year": date.year.toString(),
        "fullDate": date.toIso8601String(), //  Required for Calendar Syncing!
      });
    }
  }

  void _selectFirstAvailableSlot() {
    for (int d = 0; d < _dates.length; d++) {
      for (int t = 0; t < _times.length; t++) {
        if (_isTimeValid(_times[t], d)) {
          setState(() {
            _selectedDateIndex = d;
            //  FIX 1: Forces the time to be unselected initially!
            _selectedTimeIndex = -1;
            _selectedTime = '';
            _selectedCalendarDate = DateTime.parse(_dates[d]['fullDate']!);
          });
          return;
        }
      }
    }
  }

  Future<void> _fetchMerchantLiveConfig() async {
    if (widget.shopId.isNotEmpty) {
      // 0. Auto-heal: Query industry sebenar dari table businesses Supabase
      try {
        final biz = await Supabase.instance.client
            .from('businesses')
            .select('id, business_name, business_industry')
            .eq('id', widget.shopId)
            .maybeSingle();

        if (biz != null) {
          final realIndustry = biz['business_industry']?.toString() ?? '';
          final realName = biz['business_name']?.toString() ?? widget.shopName;
          if (realName.trim().isNotEmpty) {
            _shopName = realName.trim();
          }
          final detected = _detectBookingType(realIndustry, realName);
          if (detected != _bookingType) {
            _bookingType = detected;
            _initCategoryTemplate();
          }
          if (mounted) setState(() {});
        }
      } catch (e) {
        debugPrint('Error fetching business info in booking: $e');
      }
    }

    // 1. Dapatkan waktu operasi sebenar dari business_settings
    try {
      final settings = await Supabase.instance.client
          .from('business_settings')
          .select('operating_hours')
          .eq('business_id', widget.shopId)
          .maybeSingle();

      if (settings != null && settings['operating_hours'] is Map) {
        final opHours = settings['operating_hours'] as Map<String, dynamic>;
        final openStr = opHours['open_time'] as String?;
        final closeStr = opHours['close_time'] as String?;

        int openH = 9;
        int closeH = 22;

        if (openStr != null && openStr.contains(':')) {
          openH = int.tryParse(openStr.split(':')[0]) ?? 9;
        }
        if (closeStr != null && closeStr.contains(':')) {
          closeH = int.tryParse(closeStr.split(':')[0]) ?? 22;
        }

        List<String> dynamicTimes = [];
        if (closeH > openH) {
          for (int h = openH; h < closeH; h++) {
            dynamicTimes.add('$h:00');
          }
        } else if (closeH < openH) {
          for (int h = openH; h < 24; h++) {
            dynamicTimes.add('$h:00');
          }
          for (int h = 0; h < closeH; h++) {
            dynamicTimes.add('$h:00');
          }
        }

        if (dynamicTimes.isNotEmpty) {
          _times.clear();
          _times.addAll(dynamicTimes);
        }
      }
    } catch (e) {
      debugPrint('Error fetching business_settings in booking: $e');
    }

    // 2. Dapatkan katalog servis sebenar dari business_products (jika wujud)
    try {
      final products = await Supabase.instance.client
          .from('business_products')
          .select('id, name, price, duration_minutes, item_type')
          .eq('shop_id', widget.shopId)
          .eq('is_active', true);

      if (products.isNotEmpty) {
        final services = products.where((p) => p['item_type'] == 'service').toList();
        final effective = services.isNotEmpty ? services : products;

        if (effective.isNotEmpty) {
          _servicesList = effective.take(40).map<Map<String, String>>((row) {
            final name = row['name']?.toString() ?? 'Servis';
            final priceVal = (row['price'] as num?)?.toDouble() ?? 0.0;
            final dur = (row['duration_minutes'] as num?)?.toInt() ?? 30;
            return {
              "id": row['id']?.toString() ?? '',
              "name": name,
              "price": "RM${_fmtMoney(priceVal)}",
              "time": "${dur}m",
            };
          }).toList();
          // Template add-ons are placeholders (not real merchant data) → hide them.
          _addonsList = [];
          _selectedAddons.clear();
          _selectedServices.removeWhere((i) => i >= _servicesList.length);
          if (_selectedServices.isEmpty && _servicesList.isNotEmpty) _selectedServices.add(0);
        }
      }
    } catch (e) {
      debugPrint('Error fetching business_products in booking: $e');
    }

    // 3. Dapatkan staf sebenar dari team_members (hanya jika jenis service/barber/health/automotive/beauty)
    if (_bookingType == BookingType.service ||
        _bookingType == BookingType.barber ||
        _bookingType == BookingType.health ||
        _bookingType == BookingType.beauty ||
        _bookingType == BookingType.automotive) {
      try {
        final members = await Supabase.instance.client
            .from('team_members')
            .select('id, name, designation')
            .eq('business_id', widget.shopId)
            .eq('status', 'active');

        if (members.isNotEmpty) {
          final List<Map<String, String>> dbStaffs = [
            {
              "id": "any",
              "name": "Mana-mana Staf Bertugas",
              "specialty": "Giliran Slot Paling Cepat",
              "rating": "5.0",
              "image": "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=400",
            }
          ];

          for (var m in members) {
            dbStaffs.add({
              "id": m['id']?.toString() ?? '',
              "name": m['name']?.toString() ?? 'Pakar',
              "specialty": m['designation']?.toString() ?? 'Staff Bertugas',
              "rating": "4.9",
              "image": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=400",
            });
          }

          _staffs = dbStaffs;
        }
      } catch (e) {
        debugPrint('Error fetching team_members in booking: $e');
      }
    }

    if (mounted) {
      setState(() {
        if (_selectedTimeIndex >= _times.length) {
          _selectedTimeIndex = -1;
          _selectedTime = '';
        }
        _selectFirstAvailableSlot();
      });
    }
  }

  void _listenToRealtimeBookings() {
    if (widget.shopId.isEmpty) return;
    _timeStream = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('business_id', widget.shopId)
        .listen((data) {
      if (!mounted) return;
      setState(() {
        _activeBookings = data
            .where((b) => !const ['cancelled', 'rejected', 'declined', 'no_show'].contains(b['status']))
            .map((b) => Map<String, dynamic>.from(b))
            .toList();
      });
    }, onError: (e) {
      debugPrint('[BookingsView] Realtime bookings stream notice: $e');
    });
  }

  @override
  void initState() {
    super.initState();
    final currentUser = Supabase.instance.client.auth.currentUser;

    // Jika pengguna belum log in, arahkan terus ke halaman log masuk
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Supabase.instance.client.auth.currentUser == null && mounted) {
        showGlassToast(
          context,
          'Sila log masuk untuk membuat tempahan servis.',
          isError: true,
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    });

    String initName = UserData.userName.value.trim();
    if (initName.isEmpty || initName == 'Guest') {
      initName = (currentUser?.userMetadata?['full_name'] as String?) ??
          (currentUser?.userMetadata?['name'] as String?) ??
          (currentUser?.email?.split('@').first) ??
          '';
    }
    String initPhone = UserData.userPhone.value.trim();
    if (initPhone.isEmpty) {
      initPhone = currentUser?.phone ??
          (currentUser?.userMetadata?['phone'] as String?) ??
          '';
    }
    _customerNameCtrl = TextEditingController(text: initName);
    _customerPhoneCtrl = TextEditingController(text: initPhone);
    _bookingNotesCtrl = TextEditingController();

    _initCategoryTemplate();
    _generateUpcomingDates();
    _selectFirstAvailableSlot();
    _recoverLostDraft();
    _listenToRealtimeBookings();
    _fetchMerchantLiveConfig();
    _refreshBookedSlots();
    _slotRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshBookedSlots());
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _bookingNotesCtrl.dispose();
    _timeStream?.cancel();
    _slotRefreshTimer?.cancel();
    if (_holdingRecordId != null && !_isSubmitted) {
      _releaseHold(); // fire-and-forget; frees the slot for others
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
                child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: const SizedBox()), //  FIXED
              ),

              SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      //  RESTORED: Left and Right padding! The cards are no longer infinite width.
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 76, bottom: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                            _pageTitle,
                            key: ValueKey<String>(_pageTitle),
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5, color: isDark ? Colors.white : const Color(0xFF2C2C2C))
                        ),
                      ),
                      const SizedBox(height: 16),

                      //  RESTORED: THE CLASSIC VERTICAL 3D STACK
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
                          //  THE MASTER HEIGHT: Dictates the total space available for the deck.
                          height: MediaQuery.of(context).size.height * 0.74,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            clipBehavior: Clip.none,
                            children: orderedIndices.map((index) {
                              int relativePosition = (index - _frontCardIndex + _staffs.length) % _staffs.length;

                              double top; double scale; double opacity;

                              //  RESTORED: The exact original math that creates the beautiful top stack!
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
                                //  THE MAGIC FIX:
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
                    FloatingTopBar(
                      isDark: isDark,
                      leading: GlassNavButton.back(
                        context: context,
                        isDark: isDark,
                        size: 44,
                        iconSize: 20,
                      ),
                      title: widget.shopName,
                      subtitle: widget.category,
                      actions: [
                        GlassNavPill(
                          isDark: isDark,
                          height: 44,
                          items: [
                            GlassNavPillItem(
                              icon: _providerSummaryIcon,
                              tooltip: _providerSummaryLabel,
                              onTap: () {},
                            ),
                            GlassNavPillItem(
                              icon: HugeIcons.strokeRoundedTicket01,
                              tooltip: 'Baucar & Ganjaran',
                              onTap: () => _openBookingVoucherPicker(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
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
        filter: ui.ImageFilter.blur(sigmaX: 20 * opacity, sigmaY: 20 * opacity), //  FIXED
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





  //  Changed 'isFocused' to 'isActiveCard'
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
                  const HugeIcon(icon: HugeIcons.strokeRoundedStar, color: Colors.amber, size: 16),
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
      //  FIX 1: Always take maximum available height from parent
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

        //  FIX 2: ALWAYS wrap the content in Expanded!
        // This forces the Step contents to respect the card's boundaries and prevents the pixel overflow.
        Expanded(child: stepSwitcher),

        const SizedBox(height: 20),

        Row(
          children: [
            if (_currentStep > 0) ...[
              _AnimatedPressable(
                onTap: () async {
                  //  IF they back out of the checkout, RELEASE THE SLOT so others can book it!
                  if (_currentStep == 1 && _holdingRecordId != null) {
                    await _releaseHold();
                  }
                  if (mounted) setState(() => _currentStep--);
                },
                child: Container(
                  height: 50, width: 50,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: isDark ? Colors.white : Colors.black87, size: 18)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _AnimatedPressable(
                onTap: () => _onPrimaryTap(staff),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1976D2)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 6), spreadRadius: 1)],
                  ),
                  child: Center(
                      child: Text(
                          _currentStep < 2
                              ? "Continue"
                              : (_busy
                                  ? "Menghantar..."
                                  : (_totalPrice == 0
                                      ? "Hantar Tempahan (Percuma)"
                                      : "Hantar Tempahan · RM$_totalPriceLabel")),
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

  // ─────────────────────────────────────────────────────────────
  //  Slot hold / release / confirm (robust against RLS + network errors)
  // ─────────────────────────────────────────────────────────────

  Future<void> _releaseHold() async {
    final id = _holdingRecordId;
    _holdingRecordId = null;
    if (id == null || id.startsWith('local_')) return;
    final db = Supabase.instance.client;
    try {
      // Prefer deleting (keeps merchant list clean). Without a delete policy this
      // returns no rows, so fall back to cancelling (always allowed for own holds).
      final deleted = await db.from('bookings').delete().eq('id', id).select('id');
      if ((deleted as List).isNotEmpty) return;
    } catch (_) {}
    try {
      await db.from('bookings').update({'status': 'cancelled'}).eq('id', id);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _insertBooking(Map<String, dynamic> payload) async {
    final db = Supabase.instance.client;
    Future<Map<String, dynamic>> run(Map<String, dynamic> p) async =>
        Map<String, dynamic>.from(await db.from('bookings').insert(p).select().single());
    try {
      return await run(payload);
    } on PostgrestException catch (e) {
      if (payload.containsKey('total_price') && (e.message.contains('total_price') || e.code == 'PGRST204' || e.code == '42703')) {
        return await run({...payload}..remove('total_price'));
      }
      rethrow;
    }
  }

  Future<List<dynamic>> _updateBooking(String id, Map<String, dynamic> payload) async {
    final db = Supabase.instance.client;
    Future<List<dynamic>> run(Map<String, dynamic> p) async =>
        await db.from('bookings').update(p).eq('id', id).select('id');
    try {
      return await run(payload);
    } on PostgrestException catch (e) {
      if (payload.containsKey('total_price') && (e.message.contains('total_price') || e.code == 'PGRST204' || e.code == '42703')) {
        return await run({...payload}..remove('total_price'));
      }
      rethrow;
    }
  }

  bool _isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 9 && digits.length <= 14;
  }

  Future<void> _onPrimaryTap(Map<String, String> staff) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _handlePrimaryAction(staff);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handlePrimaryAction(Map<String, String> staff) async {
    final db = Supabase.instance.client;

    // ───────── STEP 1 → 2: reserve the slot (temporary hold) ─────────
    if (_currentStep == 0) {
      if (_selectedTimeIndex == -1) {
        showGlassToast(context, "Sila pilih slot masa yang tersedia terlebih dahulu.", isError: true);
        return;
      }
      if (widget.shopId.length <= 20) {
        showGlassToast(context, "Kedai ini belum boleh menerima tempahan.", isError: true);
        return;
      }

      var user = db.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        showGlassToast(context, "Sila log masuk untuk membuat tempahan.", isError: true);
        Navigator.pushNamed(context, '/login');
        return;
      }

      await _refreshBookedSlots();
      if (!mounted) return;
      if (!_isTimeValid(_times[_selectedTimeIndex], _selectedDateIndex)) {
        showGlassToast(context, "Slot masa ini baru sahaja diambil. Sila pilih masa lain.", isError: true);
        setState(() => _selectedTimeIndex = -1);
        return;
      }

      final String targetDate = _dates[_selectedDateIndex]['fullDate']!.substring(0, 10);
      final String targetTime = _times[_selectedTimeIndex];
      final String holdName = _customerNameCtrl.text.trim().isNotEmpty
          ? _customerNameCtrl.text.trim()
          : (UserData.userName.value.isNotEmpty ? UserData.userName.value : 'Pelanggan Ngam');

      final String? staffUuid = (staff["id"] != null && staff["id"] != "any" && staff["id"]!.length > 10) ? staff["id"] : null;

      Map<String, dynamic> basePayload(bool withCustomerId) => {
            'business_id': widget.shopId,
            if (withCustomerId) 'customer_id': user.id,
            'customer_name': holdName,
            'service_name': 'Holding...',
            'booking_date': targetDate,
            'booking_time': targetTime,
            'status': 'holding',
            'pax': _paxCount,
            if (staffUuid != null) 'staff_id': staffUuid,
            'booking_metadata': {
              'customer_auth_id': user.id,
              'provider_name': staff["name"],
              'phone': _customerPhoneCtrl.text.trim(),
            }
          };

      Map<String, dynamic>? hold;
      try {
        try {
          hold = await _insertBooking(basePayload(true));
        } on PostgrestException catch (e) {
          if (e.code == '23505') rethrow; // slot already taken (unique index)
          // e.g. customer_id FK for guest accounts → rely on metadata ownership
          hold = await _insertBooking(basePayload(false));
        }
      } on PostgrestException catch (e) {
        debugPrint('[BookingsView] hold failed: ${e.code} ${e.message}');
        if (!mounted) return;
        showGlassToast(
          context,
          e.code == '23505'
              ? "Slot masa ini baru sahaja diambil. Sila pilih masa lain."
              : "Tidak dapat menempah slot ini. Semak sambungan internet & cuba lagi.",
          isError: true,
        );
        if (e.code == '23505') setState(() => _selectedTimeIndex = -1);
        return;
      } catch (e) {
        debugPrint('[BookingsView] hold error: $e');
        if (!mounted) return;
        showGlassToast(context, "Tidak dapat menempah slot ini. Semak sambungan internet & cuba lagi.", isError: true);
        return;
      }

      _holdingRecordId = hold['id'].toString();

      // Two customers may hold the same slot at the same moment: the earliest hold wins.
      await _refreshBookedSlots();
      final myCreated = DateTime.tryParse('${hold['created_at']}');
      final bool isSpecific = staffUuid != null;
      final bool lostRace = _slotRows.any((b) {
        if (b['id']?.toString() == _holdingRecordId) return false;
        if (!_rowTakesSlot(b, targetDate, targetTime, isSpecific, staffUuid ?? '', staff["name"] ?? '')) return false;
        final theirs = DateTime.tryParse('${b['created_at']}');
        if (theirs == null || myCreated == null) return false;
        return theirs.isBefore(myCreated);
      });
      if (lostRace) {
        await _releaseHold();
        if (!mounted) return;
        showGlassToast(context, "Slot masa ini baru sahaja diambil. Sila pilih masa lain.", isError: true);
        setState(() => _selectedTimeIndex = -1);
        return;
      }

      if (mounted) setState(() => _currentStep++);
      return;
    }

    // ───────── STEP 2 → 3: services ─────────
    if (_currentStep == 1) {
      if (_selectedServices.isEmpty) {
        showGlassToast(context, "Sila pilih sekurang-kurangnya satu servis utama.", isError: true);
        return;
      }
      setState(() => _currentStep++);
      _autoApplyVoucher();
      return;
    }

    // ───────── STEP 3: confirm & send to merchant ─────────
    final String finalCustomerName = _customerNameCtrl.text.trim();
    final String finalCustomerPhone = _customerPhoneCtrl.text.trim();
    if (finalCustomerName.length < 2) {
      showGlassToast(context, "Sila masukkan nama anda.", isError: true);
      return;
    }
    if (!_isValidPhone(finalCustomerPhone)) {
      showGlassToast(context, "Sila masukkan no. telefon yang sah supaya kedai boleh menghubungi anda.", isError: true);
      return;
    }
    final String finalNotes = _bookingNotesCtrl.text.trim();

    // Simpan nama & telefon untuk kemudahan tempahan seterusnya
    UserData.userName.value = finalCustomerName;
    UserData.userPhone.value = finalCustomerPhone;

    // Generate Short ID
    final dt = DateTime.now();
    final datePart = "${dt.year.toString().substring(2)}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}";
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    final randomPart = String.fromCharCodes(Iterable.generate(5, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    final String shortBookingId = "RZRV-$datePart-$randomPart";

    final String targetDate = _dates[_selectedDateIndex]['fullDate']!.substring(0, 10);
    final String targetTime = _times[_selectedTimeIndex];
    final String combinedServiceTitle = _fullServiceSummary;
    final List<String> selectedAddonNames = _selectedAddons
        .where((i) => i >= 0 && i < _addonsList.length)
        .map((i) => _addonsList[i]['name']!)
        .toList();

    final String? staffId = (staff["id"] != null && staff["id"] != "any" && staff["id"]!.length > 10) ? staff["id"] : null;
    final String? serviceId = (_selectedServices.isNotEmpty && _selectedServices.first < _servicesList.length)
        ? _servicesList[_selectedServices.first]["id"]
        : null;
    final currentUser = db.auth.currentUser;
    if (currentUser == null) {
      showGlassToast(context, "Sesi tamat. Sila log masuk semula.", isError: true);
      Navigator.pushNamed(context, '/login');
      return;
    }

    String combinedNotes = finalNotes;
    if (_hasAllergies) {
      combinedNotes = combinedNotes.isEmpty
          ? '[Perhatian: $_healthToggleTitle]'
          : '$combinedNotes | [Perhatian: $_healthToggleTitle]';
    }

    final String chosenPaymentType = _paymentMethods[_selectedPaymentIndex]["type"] as String;
    final String chosenPaymentName = _paymentMethods[_selectedPaymentIndex]["name"] as String;

    String paymentStatus = chosenPaymentType == 'cash' ? 'unpaid' : 'pending';
    String transactionRef = '';

    Map<String, dynamic> buildMetadataPayload(String currentPayStatus, String currentRef) => {
      'short_ref': shortBookingId,
      'booking_id': shortBookingId,
      'customer_auth_id': currentUser.id,
      'customer_name': finalCustomerName,
      'phone': finalCustomerPhone,
      'provider_name': staff["name"],
      if (staffId != null) 'staff_id': staffId,
      if (serviceId != null && serviceId.isNotEmpty) 'service_id': serviceId,
      'addons_list': selectedAddonNames,
      'estimated_duration_mins': _totalTime,
      'payment_method': chosenPaymentName,
      'payment_status': currentPayStatus,
      if (currentRef.isNotEmpty) 'transaction_ref': currentRef,
      'total_price': "RM$_totalPriceLabel",
      if (_selectedVoucher != null) 'voucher_code': _selectedVoucher!['code'],
      if (_voucherDiscount > 0) 'discount_amount': _voucherDiscount,
      if (_voucherDiscount > 0) 'original_subtotal': "RM${_fmtMoney(_subtotal)}",
      'shop_name': _resolvedShopName,
      'shop_image': widget.shopImage,
      'category': widget.category,
      'booking_type': _bookingType.name,
      'pax': _paxCount,
      if (_bookingType == BookingType.hospitality) 'nights_count': _nightsCount,
      if (_industryDetailCtrl.text.trim().isNotEmpty) 'industry_detail': _industryDetailCtrl.text.trim(),
      'has_allergies_or_notes': _hasAllergies,
      'notes': [
        if (_bookingType == BookingType.dining || _bookingType == BookingType.hospitality || _bookingType == BookingType.facility)
          '$_paxCount Pax',
        if (_bookingType == BookingType.hospitality) '$_nightsCount Malam',
        if (_industryDetailCtrl.text.trim().isNotEmpty) _industryDetailCtrl.text.trim(),
        if (combinedNotes.isNotEmpty) combinedNotes,
      ].join(' • ').isNotEmpty
          ? [
              if (_bookingType == BookingType.dining || _bookingType == BookingType.hospitality || _bookingType == BookingType.facility)
                '$_paxCount Pax',
              if (_bookingType == BookingType.hospitality) '$_nightsCount Malam',
              if (_industryDetailCtrl.text.trim().isNotEmpty) _industryDetailCtrl.text.trim(),
              if (combinedNotes.isNotEmpty) combinedNotes,
            ].join(' • ')
          : 'Tempahan melalui Aplikasi Ngam',
    };

    // Jika pembayaran dalam talian (DuitNow QR atau FPX / Kad), kemas kini rekod 'holding' dahulu
    // dengan harga sebenar & short_ref supaya pelayan CHIP boleh mengesahkan harga tanpa menghantar
    // notifikasi awal ke Ngam Business sebelum bayaran selesai!
    if (chosenPaymentType != "cash" && _totalPrice > 0) {
      final pendingMeta = buildMetadataPayload('pending', '');
      final String? holdId = _holdingRecordId;
      if (holdId != null && !holdId.startsWith('local_')) {
        try {
          await _updateBooking(holdId, {
            'customer_name': finalCustomerName,
            'service_name': combinedServiceTitle,
            'status': 'holding',
            'total_price': _totalPrice,
            if (staffId != null) 'staff_id': staffId,
            'booking_metadata': pendingMeta,
          });
        } catch (e) {
          debugPrint('[BookingsView] pre-payment hold update warning: $e');
        }
      } else {
        try {
          final insertedHold = await _insertBooking({
            'business_id': widget.shopId,
            'customer_id': currentUser.id,
            'customer_name': finalCustomerName,
            'service_name': combinedServiceTitle,
            'booking_date': targetDate,
            'booking_time': targetTime,
            'status': 'holding',
            'pax': _paxCount,
            'total_price': _totalPrice,
            if (staffId != null) 'staff_id': staffId,
            'booking_metadata': pendingMeta,
          });
          _holdingRecordId = insertedHold['id']?.toString();
        } catch (e) {
          debugPrint('[BookingsView] pre-payment hold insert warning: $e');
        }
      }

      if (!mounted) return;
      final bool paid = await CustomerPaymentModal.show(
        context: context,
        amount: _totalPrice,
        orderTitle: 'Tempahan $combinedServiceTitle - $_resolvedShopName',
        shopName: _resolvedShopName,
        orderId: shortBookingId,
        customerName: finalCustomerName,
        customerPhone: finalCustomerPhone,
        initialMethod: chosenPaymentType,
        voucherCode: _selectedVoucher != null ? _selectedVoucher!['code']?.toString() : null,
        discountAmount: _voucherDiscount > 0 ? _voucherDiscount : null,
        onPaymentSuccess: (method, ref) async {
          paymentStatus = 'paid';
          transactionRef = ref;
        },
      );

      if (!paid) {
        if (!mounted) return;
        showGlassToast(context, 'Pembayaran dibatalkan. Tempahan belum dihantar ke kedai.', isError: true);
        return;
      }
      paymentStatus = 'paid';
    } else {
      paymentStatus = 'unpaid';
    }

    _lastPaymentStatus = paymentStatus;
    _lastPaymentMethod = chosenPaymentName;

    final Map<String, dynamic> metadataPayload = buildMetadataPayload(paymentStatus, transactionRef);

    String? savedId;
    final String? oldHold = _holdingRecordId;

    // 1) Promote our hold → pending (works when RLS allows holding→pending)
    if (oldHold != null && !oldHold.startsWith('local_')) {
      try {
        final rows = await _updateBooking(oldHold, {
          'customer_name': finalCustomerName,
          'service_name': combinedServiceTitle,
          'status': 'pending',
          'total_price': _totalPrice,
          if (staffId != null) 'staff_id': staffId,
          'booking_metadata': metadataPayload,
        });
        if (rows.isNotEmpty) savedId = oldHold;
      } catch (e) {
        debugPrint('[BookingsView] promote hold failed: $e');
      }
    }

    // 2) Fallback: release the hold and insert a fresh pending booking
    if (savedId == null) {
      await _releaseHold();
      try {
        final inserted = await _insertBooking({
          'business_id': widget.shopId,
          'customer_id': currentUser.id,
          'customer_name': finalCustomerName,
          'service_name': combinedServiceTitle,
          'booking_date': targetDate,
          'booking_time': targetTime,
          'status': 'pending',
          'pax': _paxCount,
          'total_price': _totalPrice,
          if (staffId != null) 'staff_id': staffId,
          'booking_metadata': metadataPayload,
        });
        savedId = inserted['id'].toString();
      } on PostgrestException catch (e) {
        debugPrint('[BookingsView] insert pending failed: ${e.code} ${e.message}');
        if (!mounted) return;
        showGlassToast(
          context,
          e.code == '23505'
              ? "Slot masa ini baru sahaja diambil. Sila pilih masa lain."
              : "Tempahan gagal dihantar. Sila cuba lagi.",
          isError: true,
        );
        if (e.code == '23505') {
          setState(() {
            _currentStep = 0;
            _selectedTimeIndex = -1;
          });
        }
        return;
      } catch (e) {
        debugPrint('[BookingsView] insert pending error: $e');
        if (!mounted) return;
        showGlassToast(context, "Tempahan gagal dihantar. Semak internet & cuba lagi.", isError: true);
        return;
      }
    }

    _holdingRecordId = savedId;

    // Rekod penebusan baucar supaya tidak boleh diguna semula melebihi kuota
    if (_selectedVoucher != null && _voucherDiscount > 0) {
      await VoucherService.recordVoucherRedemption(
        voucher: _selectedVoucher!,
        discountAmount: _voucherDiscount,
        orderSubtotal: _subtotal,
        businessId: widget.shopId,
        orderId: savedId,
        customerPhone: finalCustomerPhone,
      );
    }

    final dateStr = "${_dates[_selectedDateIndex]['day']}, ${_dates[_selectedDateIndex]['date']} ${_dates[_selectedDateIndex]['month']}";
    final timeStr = _times[_selectedTimeIndex];

    LocalNotificationService.showBookingConfirmed(
      shopName: widget.shopName,
      category: combinedServiceTitle,
      shopImage: widget.shopImage,
      providerName: staff["name"]!,
      date: dateStr,
      time: timeStr,
      totalPrice: "RM$_totalPriceLabel",
      bookingId: shortBookingId,
    );

    if (mounted) {
      setState(() {
        _generatedBookingId = shortBookingId;
        _isSubmitted = true;
      });
    }
  }

  Widget _buildCurrentStep(bool isDark, Map<String, String> staff) {
    if (_currentStep == 0) return _buildStepOneTimeSelection(isDark);
    if (_currentStep == 1) return _buildStepTwoServicesAndAddons(isDark);
    return _buildStepThreeCheckout(isDark, staff);
  }

  Widget _buildPremiumInput({
    required bool isDark,
    required String label,
    required String hint,
    required dynamic icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    TextCapitalization? textCapitalization,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            validator: validator,
            textCapitalization: textCapitalization ?? TextCapitalization.none,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontWeight: FontWeight.normal, fontSize: 13),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: HugeIcon(icon: icon, color: Colors.grey, size: 16),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              border: InputBorder.none,
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
                //  DUAL CONFIRMATION HEADER
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

                //  FULLY CUSTOM PREMIUM GLASS CALENDAR
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
                              child: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: isDark ? Colors.white : Colors.black87, size: 20),
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
                              child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: isDark ? Colors.white : Colors.black87, size: 20),
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

                                //  FIX 2: Completely clear the time selection when a new date is tapped!
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
                                  //  THE FIX: Transparent border for inactive dates! Only the active one gets the blue ring.
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

                //  HORIZONTAL TIME SCROLL
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
                if (_bookingType == BookingType.hospitality ||
                    _bookingType == BookingType.dining ||
                    _bookingType == BookingType.facility) ...[
                  const SizedBox(height: 22),
                  _buildGlassBox(
                    isDark: isDark,
                    radius: 18,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _bookingType == BookingType.hospitality
                                      ? 'Bilangan Tetamu (Dewasa/Kanak-kanak)'
                                      : (_bookingType == BookingType.dining
                                          ? 'Bilangan Tetamu Meja (Pax)'
                                          : 'Bilangan Pemain (Pax)'),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Sila tetapkan jumlah kehadiran',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (_paxCount > 1) setState(() => _paxCount--);
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.remove, size: 16, color: isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '$_paxCount Pax',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    if (_paxCount < 30) setState(() => _paxCount++);
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_bookingType == BookingType.hospitality) ...[
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tempoh Penginapan (Malam)',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Check-out: ${_selectedCalendarDate.add(Duration(days: _nightsCount)).day}/${_selectedCalendarDate.add(Duration(days: _nightsCount)).month}/${_selectedCalendarDate.add(Duration(days: _nightsCount)).year}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (_nightsCount > 1) {
                                        setState(() => _nightsCount--);
                                        _refreshBookingVoucher();
                                      }
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.remove, size: 16, color: isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      '$_nightsCount Malam',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (_nightsCount < 30) {
                                        setState(() => _nightsCount++);
                                        _refreshBookingVoucher();
                                      }
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            );
          }
      ),
    );
  }


  //  NEW HELPER: Designed for the Horizontal Scroll layout
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
        //  Padding gives the chip its shape in a Row!
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
          Text(_mainServiceTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Column(children: List.generate(_servicesList.length, (index) => _buildSelectionTile(_servicesList[index], index, isDark, _selectedServices, false))),

          if (_addonsList.isNotEmpty) ...[
          const SizedBox(height: 24),

          Text(_addonsTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Column(children: List.generate(_addonsList.length, (index) => _buildSelectionTile(_addonsList[index], index, isDark, _selectedAddons, true))),
          ],

          const SizedBox(height: 24),
          Text("booking.requirements_safety".tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_healthToggleTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(_healthToggleSubtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[600])),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _hasAllergies,
                  activeColor: Colors.blue,
                  activeTrackColor: Colors.blue.withValues(alpha: 0.3),
                  inactiveThumbColor: isDark ? Colors.grey[400] : Colors.grey[300],
                  inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
                  onChanged: (val) => setState(() => _hasAllergies = val),
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
          Text("booking.summary".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
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
                ..._selectedServices.map((i) {
                  final int mult = _bookingType == BookingType.hospitality ? _nightsCount : 1;
                  final double unitPrice = _parseMoney(_servicesList[i]["price"]!);
                  final String title = mult > 1
                      ? '${_servicesList[i]["name"]!} (x$mult Malam)'
                      : _servicesList[i]["name"]!;
                  final String priceStr = mult > 1
                      ? 'RM${_fmtMoney(unitPrice * mult)}'
                      : _servicesList[i]["price"]!;
                  return _buildReceiptRow(title, priceStr, isDark);
                }),
                ..._selectedAddons.map((i) => _buildReceiptRow(_addonsList[i]["name"]!, _addonsList[i]["price"]!.replaceAll('+', ''), isDark)),

                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2))
                ),

                _buildSummaryRow("Location", widget.shopName, HugeIcons.strokeRoundedStore01, isDark),
                const SizedBox(height: 12),
                _buildSummaryRow(_providerSummaryLabel, staff["name"]!, _providerSummaryIcon, isDark),
                const SizedBox(height: 12),
                _buildSummaryRow("Date", "${_dates[_selectedDateIndex]['day']}, ${_dates[_selectedDateIndex]['date']} ${_dates[_selectedDateIndex]['month']}", HugeIcons.strokeRoundedCalendar03, isDark),                const SizedBox(height: 12),
                _buildSummaryRow("Time", _times[_selectedTimeIndex], HugeIcons.strokeRoundedClock01, isDark),

                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2))
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("booking.estimated_duration".tr(), style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
                    Text("~$_totalTime mins", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text("booking.customer_info_notes".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.3)),
            ),
            child: Column(
              children: [
                _buildPremiumInput(
                  isDark: isDark,
                  label: "Nama Anda",
                  hint: "Masukkan nama penuh / panggilan",
                  icon: HugeIcons.strokeRoundedUser,
                  controller: _customerNameCtrl,
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 10),
                _buildPremiumInput(
                  isDark: isDark,
                  label: "No. Telefon (WhatsApp)",
                  hint: "Cth: 012-345 6789",
                  icon: HugeIcons.strokeRoundedCall02,
                  controller: _customerPhoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                if (_bookingType == BookingType.automotive || _bookingType == BookingType.service) ...[
                  const SizedBox(height: 10),
                  _buildPremiumInput(
                    isDark: isDark,
                    label: _bookingType == BookingType.automotive
                        ? "No. Plat & Model Kenderaan"
                        : "Alamat Rumah / Lokasi Servis",
                    hint: _bookingType == BookingType.automotive
                        ? "Cth: VAB 1234 (Honda City)"
                        : "Masukkan alamat penuh jika servis ke rumah",
                    icon: _bookingType == BookingType.automotive
                        ? HugeIcons.strokeRoundedCar01
                        : HugeIcons.strokeRoundedLocation01,
                    controller: _industryDetailCtrl,
                    keyboardType: TextInputType.text,
                  ),
                ],
                const SizedBox(height: 10),
                _buildPremiumInput(
                  isDark: isDark,
                  label: "Nota Khas / Permintaan (Pilihan)",
                  hint: _notesHintText,
                  icon: HugeIcons.strokeRoundedNote01,
                  controller: _bookingNotesCtrl,
                  keyboardType: TextInputType.text,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- VOUCHER SELECTION SECTION ---
          _buildBookingVoucherSection(isDark),

          const SizedBox(height: 12),

          Text("booking.payment_method".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),

          //  CLASSIC 3-METHOD LAYOUT (FIXED OVERFLOW)
          Column(
            children: List.generate(_paymentMethods.length, (i) {
              bool isSel = _selectedPaymentIndex == i;

              final String? badge = _paymentMethods[i]["badge"] as String?;
              final String subtitle = (_paymentMethods[i]["subtitle"] ?? '') as String;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSel ? Colors.blue.withValues(alpha: 0.08) : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSel ? Colors.blue : Colors.white.withValues(alpha: isDark ? 0.08 : 0.6), width: 1.5),
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPaymentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        HugeIcon(icon: _paymentMethods[i]["icon"], color: isSel ? Colors.blue : (isDark ? Colors.white60 : Colors.black54), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _paymentMethods[i]["name"],
                                      style: TextStyle(fontSize: 14.5, fontWeight: isSel ? FontWeight.bold : FontWeight.w600, color: isSel ? Colors.blue : (isDark ? Colors.white : Colors.black87)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (badge != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFED0058).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        badge,
                                        style: const TextStyle(color: Color(0xFFED0058), fontSize: 9, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.black54),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        HugeIcon(
                          icon: isSel ? HugeIcons.strokeRoundedCheckmarkCircle02 : HugeIcons.strokeRoundedCircle,
                          color: isSel ? Colors.blue : (isDark ? Colors.white30 : Colors.black26),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // Summary Breakdown with Voucher
          if (_voucherDiscount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("booking.service_subtotal".tr(), style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                Text("RM${_fmtMoney(_subtotal)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedTicket01, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "Diskaun Baucar ${_selectedVoucher != null ? '(${_selectedVoucher!['code']})' : ''}",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                Text("-RM${_fmtMoney(_voucherDiscount)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("booking.grand_total".tr(), style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54)),
              Text("RM$_totalPriceLabel", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.0, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }


  Widget _buildBookingVoucherSection(bool isDark) {
    if (_selectedVoucher != null && _voucherDiscount > 0) {
      final code = (_selectedVoucher!['code'] ?? '').toString().toUpperCase();
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedTicket01,
                color: Color(0xFF10B981),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Digunakan',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Jimat RM ${_fmtMoney(_voucherDiscount)} untuk tempahan ini',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _openBookingVoucherPicker,
              child: Text('common.change'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedVoucher = null;
                  _voucherDiscount = 0.0;
                  _userDismissedVoucher = true;
                });
                showGlassToast(context, 'Baucar dibatalkan');
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _openBookingVoucherPicker,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedDiscount01,
                color: Colors.blue,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Baucar & Diskaun Tempahan',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Pilih baucar atau masukkan kod promo',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pilih Baucar',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.blue, size: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildSummaryRow(String label, String val, dynamic icon, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(icon: icon, size: 16, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
        const SizedBox(width: 16),
        //  FIXED: Wrapped in Expanded to allow long shop names to drop to the next line safely
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

  //  FIXED: The success screen now shows the proper "View Order" button
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
                  child: const Center(child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Colors.greenAccent, size: 50)),
                ),
                const SizedBox(height: 32),
                Text("booking.submitted_title".tr(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text("booking.submitted_desc".tr(), style: TextStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.black54)),
                const SizedBox(height: 40),

                // Button to open the ticket immediately after booking
                _AnimatedPressable(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingTicketScreen(
                          shopId: widget.shopId,
                          shopName: widget.shopName,
                          category: _fullServiceSummary,
                          shopImage: widget.shopImage,
                          providerName: _staffs[_frontCardIndex]["name"]!,
                          date: "${_dates[_selectedDateIndex]['day']}, ${_dates[_selectedDateIndex]['date']} ${_dates[_selectedDateIndex]['month']}",
                          time: _times[_selectedTimeIndex],
                          totalPrice: "RM$_totalPriceLabel",
                          bookingId: _generatedBookingId,
                          status: 'pending',
                          paymentMethod: _lastPaymentMethod,
                          paymentStatus: _lastPaymentStatus,
                          bookingDbId: (_holdingRecordId != null && !_holdingRecordId!.startsWith('local_'))
                              ? _holdingRecordId
                              : null,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
                    decoration: BoxDecoration(color: isDark ? Colors.white : Colors.black87, borderRadius: BorderRadius.circular(20)),
                    child: Text("booking.view_order".tr(), style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 16),

                // Simple text button to go back
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text("booking.back_to_home".tr(), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w600)),
                )
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _buildSelectionTile(Map<String, String> item, int index, bool isDark, Set<int> stateSet, bool isMultiSelect) {
    bool isSelected = stateSet.contains(index);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isMultiSelect) {
            if (isSelected) {
              stateSet.remove(index);
            } else {
              stateSet.add(index);
            }
          } else {
            stateSet.clear(); stateSet.add(index);
          }
        });
        _refreshBookingVoucher();
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
            HugeIcon(
              icon: isSelected
                  ? (isMultiSelect ? HugeIcons.strokeRoundedCheckmarkSquare02 : HugeIcons.strokeRoundedCheckmarkCircle02)
                  : (isMultiSelect ? HugeIcons.strokeRoundedSquare : HugeIcons.strokeRoundedCircle),
              color: isSelected ? Colors.blue : (isDark ? Colors.white54 : Colors.black54),
              size: 20,
            ),
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
