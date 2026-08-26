// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get profile => 'Profil';

  @override
  String get preferences => 'Keutamaan';

  @override
  String get darkMode => 'Mod Gelap';

  @override
  String get language => 'Bahasa';

  @override
  String get currentLanguage => 'Bahasa Inggeris';

  @override
  String get account => 'Akaun';

  @override
  String get personalInformation => 'Maklumat Peribadi';

  @override
  String get paymentMethods => 'Kaedah Pembayaran';

  @override
  String get privacySecurity => 'Privasi & Keselamatan';

  @override
  String get logOut => 'Log Keluar';

  @override
  String get selectLanguage => 'Pilih Bahasa';

  @override
  String get english => 'Bahasa Inggeris';

  @override
  String get malay => 'Bahasa Melayu';

  @override
  String get searchHint => 'Cari';

  @override
  String get nearby => 'Berdekatan';

  @override
  String get statusOpenCaps => 'DIBUKA';

  @override
  String get statusClosingCaps => 'AKAN DITUTUP';

  @override
  String get statusClosedCaps => 'DITUTUP';

  @override
  String get statusOpenNow => 'Dibuka Sekarang';

  @override
  String get statusClosingSoon => 'Akan Ditutup';

  @override
  String get statusClosed => 'Ditutup';

  @override
  String closingIn(int minutes) {
    return 'DITUTUP DALAM ${minutes}M';
  }

  @override
  String get rating => 'Penilaian';

  @override
  String get reviews => 'Ulasan';

  @override
  String get away => 'Jauh';

  @override
  String get call => 'Hubungi';

  @override
  String get directions => 'Arah';

  @override
  String get operatingHours => 'Waktu Operasi';

  @override
  String get today => 'Hari Ini';

  @override
  String todayDay(String day) {
    return 'Hari Ini ($day)';
  }

  @override
  String get servicesAvailable => 'Perkhidmatan Tersedia';

  @override
  String get generalService => 'Perkhidmatan Umum';

  @override
  String get recentReviews => 'Ulasan Terkini';

  @override
  String get noReviewsYet => 'Belum ada ulasan.';

  @override
  String get user => 'Pengguna';

  @override
  String get rezrvNow => 'REZRV Sekarang';

  @override
  String resultsFor(String query) {
    return 'Hasil carian untuk \'$query\'';
  }

  @override
  String get noResultsFoundTitle => 'Tiada hasil dijumpai';

  @override
  String get noLocationsMatch =>
      'Tiada lokasi yang sepadan dengan carian anda.';

  @override
  String get noMatchesFound => 'Tiada padanan dijumpai';

  @override
  String get trySearchingDifferent => 'Cuba cari kedai atau perkhidmatan lain.';

  @override
  String get clear => 'Kosongkan';

  @override
  String get locating => 'Mengesan lokasi...';

  @override
  String get locationDisabled => 'Lokasi dilumpuhkan';

  @override
  String get permissionDenied => 'Kebenaran ditolak';

  @override
  String get permissionDeniedForever => 'Kebenaran ditolak selamanya';

  @override
  String get unknownCity => 'Bandar Tidak Diketahui';

  @override
  String get unknownState => 'Negeri Tidak Diketahui';

  @override
  String get locationUnavailable => 'Lokasi tidak tersedia';

  @override
  String hiUser(String firstName) {
    return 'Hi, $firstName';
  }

  @override
  String get promotions => 'Promosi';

  @override
  String get categories => 'Kategori';

  @override
  String get recommended => 'Disyorkan';

  @override
  String get seeAll => 'Lihat Semua';

  @override
  String get promoLabel => 'PROMO';

  @override
  String get claimButton => 'Tuntut';

  @override
  String get catHaircuts => 'Gunting Rambut';

  @override
  String get catShaving => 'Bercukur';

  @override
  String get catColoring => 'Mewarna';

  @override
  String get catStyling => 'Penggayaan';

  @override
  String get catFacial => 'Rawatan Wajah';

  @override
  String get catMassage => 'Urutan';

  @override
  String get catNails => 'Kuku';

  @override
  String get catMore => 'Lagi';

  @override
  String get unknownShop => 'Tidak Diketahui';

  @override
  String get generalCategory => 'Umum';

  @override
  String get myBarbrTitle => 'Barbr Saya';

  @override
  String get tabUpcoming => 'Akan Datang';

  @override
  String get tabHistory => 'Sejarah';

  @override
  String get noPastReservations => 'Tiada tempahan lepas atau yang dibatalkan.';

  @override
  String get noUpcomingReservations =>
      'Belum ada tempahan akan datang.\nTempah perkhidmatan untuk melihatnya di sini!';

  @override
  String get cancelBtn => 'Batal';

  @override
  String get viewTicketBtn => 'Lihat Tiket';

  @override
  String get statusCancelled => 'Dibatalkan';

  @override
  String get statusDone => 'Selesai';

  @override
  String get ticketOrderTitle => 'Pesanan';

  @override
  String get ticketProvider => 'Penyedia';

  @override
  String get ticketDate => 'Tarikh';

  @override
  String get ticketTime => 'Masa';

  @override
  String get ticketBookingId => 'ID Tempahan';

  @override
  String get ticketTotalPaid => 'Jumlah Dibayar';

  @override
  String get ticketScanHint => 'Imbas di kaunter semasa ketibaan';

  @override
  String get ticketCallOwner => 'Hubungi Pemilik';

  @override
  String get bkTitleComplete => 'Tempahan selesai!';

  @override
  String get bkTitleProvider => 'Pilih penyedia:';

  @override
  String get bkTitleServices => 'Pilih Perkhidmatan:';

  @override
  String get bkTitleCheckout => 'Daftar keluar & pembayaran:';

  @override
  String get bkApptDate => 'Tarikh Temu Janji';

  @override
  String get bkAvailTime => 'Masa Tersedia';

  @override
  String get bkMainService => 'Pilih Perkhidmatan Utama';

  @override
  String get bkAddons => 'Tambahan Ekstra';

  @override
  String get bkHealthSafety => 'Kesihatan & Keselamatan';

  @override
  String get bkAllergies => 'Alahan atau sensitiviti kulit?';

  @override
  String get bkSummary => 'Ringkasan Tempahan';

  @override
  String get bkLocation => 'Lokasi';

  @override
  String get bkProvider => 'Penyedia';

  @override
  String get bkDate => 'Tarikh';

  @override
  String get bkTime => 'Masa';

  @override
  String get bkEstDuration => 'Anggaran Tempoh';

  @override
  String bkMins(int time) {
    return '~$time min';
  }

  @override
  String get bkPaymentMethod => 'Kaedah Pembayaran';

  @override
  String get bkCreditCard => 'Kad Kredit / Debit';

  @override
  String get bkOnlineBanking => 'Perbankan Dalam Talian (FPX)';

  @override
  String get bkCash => 'Tunai di Kaunter';

  @override
  String get bkNoCards => 'Tiada kad disimpan. Sila tambah di Profil anda.';

  @override
  String get bkGrandTotal => 'Jumlah Keseluruhan';

  @override
  String get bkContinue => 'Teruskan';

  @override
  String bkConfirmPay(String price) {
    return 'Sahkan & Bayar $price';
  }

  @override
  String get bkCardHolder => 'Pemegang Kad';

  @override
  String get bkExpires => 'Tamat Tempoh';

  @override
  String get bkConfirmed => 'Tempahan Disahkan!';

  @override
  String get bkNotified => 'Penyedia anda telah dimaklumkan.';

  @override
  String get bkViewOrder => 'Lihat Pesanan';

  @override
  String get bkBackHome => 'Kembali ke Laman Utama';

  @override
  String get navHome => 'Utama';

  @override
  String get navExplore => 'Teroka';

  @override
  String get navMyBarbr => 'Barbr Saya';

  @override
  String get navSaved => 'Disimpan';

  @override
  String get shopDetailDummyAddress => '123 Jalan Utama, Pusat Bandar';

  @override
  String get shopDetailDummyHours => 'Dibuka Sekarang • Ditutup pada 10:00 PM';

  @override
  String get shopDetailAbout => 'Mengenai Kami';

  @override
  String get shopDetailAboutDesc =>
      'Alami perkhidmatan dandanan dan kesejahteraan premium dalam persekitaran yang santai. Pakar kami berdedikasi untuk membuatkan anda tampil dan berasa lebih yakin.';

  @override
  String get exploreCatBeauty => 'Kecantikan & Kesejahteraan';

  @override
  String get exploreCatBarber => 'Kedai Gunting Rambut';

  @override
  String get exploreCatHealth => 'Kesihatan & Klinik';

  @override
  String get exploreCatFood => 'Makanan & Minuman';

  @override
  String get exploreCatRestaurant => 'Restoran';

  @override
  String get exploreCatCafe => 'Kafe';

  @override
  String get exploreCatAuto => 'Auto & Pengangkutan';

  @override
  String get exploreCatWorkshop => 'Bengkel & Pembaikan';

  @override
  String get exploreCatGas => 'Stesen Minyak';

  @override
  String get exploreCatDaily => 'Keperluan Harian';

  @override
  String get exploreCatSupermarket => 'Pasaraya';

  @override
  String get exploreCatBanking => 'Perbankan';

  @override
  String get exploreCatCommunity => 'Komuniti';

  @override
  String get exploreCatSchool => 'Sekolah';

  @override
  String get exploreCatReligion => 'Agama';

  @override
  String searchAll(String category) {
    return 'Semua $category';
  }

  @override
  String get searchHeadersCategories => 'KATEGORI';

  @override
  String get searchHeadersShops => 'KEDAI & PERKHIDMATAN';

  @override
  String searchMatchProvides(String service) {
    return 'Menyediakan $service';
  }

  @override
  String get msgVia => 'Mesej melalui';

  @override
  String get msgWhatsApp => 'WhatsApp';

  @override
  String get msgTelegram => 'Telegram';

  @override
  String get msgSMS => 'Mesej SMS';

  @override
  String get btnViewProfile => 'Lihat Profil';

  @override
  String get piProfileUpdated => 'Profil berjaya dikemas kini!';

  @override
  String get piFullName => 'Nama Penuh';

  @override
  String get piFullNameHint => 'Masukkan nama penuh anda';

  @override
  String get piEmail => 'Alamat E-mel';

  @override
  String get piEmailHint => 'Masukkan e-mel anda';

  @override
  String get piPhone => 'Nombor Telefon';

  @override
  String get piPhoneHint => 'Masukkan nombor telefon anda';

  @override
  String get piDob => 'Tarikh Lahir';

  @override
  String get piDobHint => 'HH / BB / TTTT';

  @override
  String get piSaveChanges => 'Simpan Perubahan';

  @override
  String get savedTitle => 'Simpanan Saya';

  @override
  String get savedEmptyState => 'Anda belum menyimpan sebarang tempat lagi.';

  @override
  String get ticketCountdownPast => 'Temu Janji Bermula/Berlalu';

  @override
  String ticketCountdownStartsIn(String duration) {
    return 'Bermula dalam: $duration';
  }

  @override
  String get support => 'Sokongan';

  @override
  String get helpCenter => 'Pusat Bantuan';

  @override
  String get contactUs => 'Hubungi Kami';

  @override
  String get about => 'Tentang Kami';

  @override
  String get termsOfService => 'Syarat Perkhidmatan';

  @override
  String get privacyPolicy => 'Dasar Privasi';

  @override
  String get rateUs => 'Nilaikan Aplikasi';

  @override
  String get inviteFriends => 'Jemput Rakan';

  @override
  String get referralText => 'Dapat RM10 untuk setiap rujukan';

  @override
  String get madeIn => 'Dibuat dengan ❤️ di Malaysia';
}
