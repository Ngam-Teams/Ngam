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
  String todayDay(Object day) {
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
  String get rezrvNow => 'Tempah Sekarang';

  @override
  String resultsFor(Object query) {
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
  String hiUser(Object firstName) {
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
  String get myBarbrTitle => 'Tempahan Saya';

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
  String bkMins(Object time) {
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
  String bkConfirmPay(Object price) {
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
  String get navMyBarbr => 'Tempahan';

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
  String searchAll(Object category) {
    return 'Semua $category';
  }

  @override
  String get searchHeadersCategories => 'KATEGORI';

  @override
  String get searchHeadersShops => 'KEDAI & PERKHIDMATAN';

  @override
  String searchMatchProvides(Object service) {
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
  String get btnViewProfile => 'Lihat Kedai';

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
  String ticketCountdownStartsIn(Object duration) {
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
  String get madeIn => 'Dibuat dengan bangga di Malaysia';

  @override
  String get bookNow => 'Tempah Sekarang';

  @override
  String get authLogout => 'Log Keluar';

  @override
  String get authWelcomeBack => 'Selamat Kembali!';

  @override
  String get authWelcomeSubtitle => 'Log masuk untuk meneruskan';

  @override
  String get authEmail => 'Alamat E-mel';

  @override
  String get authPassword => 'Kata Laluan';

  @override
  String get authLogin => 'Log Masuk';

  @override
  String get authNoAccount => 'Tiada akaun? ';

  @override
  String get authRegisterHere => 'Daftar di sini';

  @override
  String get authCreateAccount => 'Cipta Akaun';

  @override
  String get authRegisterSubtitle => 'Sertai komuniti Ngam hari ini';

  @override
  String get authFullName => 'Nama Penuh';

  @override
  String get authPhone => 'Nombor Telefon';

  @override
  String get authRoleSelect => 'Saya mahu:';

  @override
  String get authRoleCustomer => 'Upah Orang';

  @override
  String get authRoleRunner => 'Cari Duit (Runner)';

  @override
  String get authRegister => 'Daftar Akaun';

  @override
  String get authHaveAccount => 'Sudah mempunyai akaun? ';

  @override
  String get authLoginHere => 'Log masuk di sini';

  @override
  String get authPleaseEnterEmail => 'Sila masukkan e-mel anda';

  @override
  String get authValidEmail => 'Sila masukkan e-mel yang sah';

  @override
  String get authPleaseEnterPassword => 'Sila masukkan kata laluan anda';

  @override
  String get authPleaseEnterName => 'Sila masukkan nama anda';

  @override
  String get authPleaseEnterPhone => 'Sila masukkan nombor telefon';

  @override
  String get authPasswordMinLength =>
      'Kata laluan mestilah sekurang-kurangnya 6 aksara';

  @override
  String get authConfirmPassword => 'Sahkan Kata Laluan';

  @override
  String get authPasswordsDoNotMatch => 'Kata laluan tidak sepadan';

  @override
  String get authForgotPassword => 'Lupa Kata Laluan?';

  @override
  String get authOrContinueWith => 'Atau teruskan dengan';

  @override
  String get authGoogleSignin => 'Google';

  @override
  String get authAppleSignin => 'Apple';

  @override
  String get navMyTasks => 'Tugasan';

  @override
  String get navChat => 'Mesej';

  @override
  String get navProfile => 'Profil';

  @override
  String customerGreeting(Object arg0) {
    return 'Hai, $arg0';
  }

  @override
  String get customerWhatDoYouNeed => 'Apa yang anda perlukan hari ini?';

  @override
  String get customerSearchHint => 'Cari tugasan atau servis...';

  @override
  String get customerQuickCategories => 'Kategori Pantas';

  @override
  String get customerNearbyRunners => 'Runner Berhampiran Anda';

  @override
  String get customerRecentTasks => 'Tugasan Terkini';

  @override
  String get customerViewAll => 'Lihat Semua';

  @override
  String get customerPostNewTask => 'Minta Bantuan Baru';

  @override
  String get customerTaskTitle => 'Tajuk Tugasan';

  @override
  String get customerTaskDesc => 'Terangkan apa yang anda perlukan...';

  @override
  String get customerBounty => 'Upah (RM)';

  @override
  String get customerLocation => 'Lokasi';

  @override
  String get customerPostTask => 'Terbitkan Tugasan';

  @override
  String customerAvailableServices(Object arg0) {
    return 'Servis Tersedia ($arg0)';
  }

  @override
  String get customerNoServices => 'Tiada servis tersedia buat masa ini.';

  @override
  String get customerRunnersWillPost =>
      'Runner akan menawarkan servis tidak lama lagi.';

  @override
  String get customerServiceOrdered => 'Berjaya menempah servis!';

  @override
  String get customerOrderService => 'Tempah Servis';

  @override
  String get postTaskTitleRunner => 'Tawar Servis';

  @override
  String get postTaskTitleCustomer => 'Minta Bantuan Baru';

  @override
  String get postTaskServiceTitleLabel => 'Tajuk Servis';

  @override
  String get postTaskServiceTitleHint => 'cth., Saya akan print 10 muka surat';

  @override
  String get postTaskTaskTitleHint => 'cth., Print assignment 10 muka surat';

  @override
  String get postTaskErrTitle => 'Sila masukkan tajuk';

  @override
  String get postTaskServiceDescLabel => 'Penerangan Servis';

  @override
  String get postTaskTaskDescLabel => 'Penerangan Tugasan';

  @override
  String get postTaskServiceDescHint => 'Terangkan apa yang anda boleh buat...';

  @override
  String get postTaskErrDesc => 'Sila masukkan penerangan';

  @override
  String get postTaskCategory => 'Kategori';

  @override
  String get postTaskLocationLabel => 'Lokasi / Tempat Letak';

  @override
  String get postTaskLocationHint => 'cth., Blok C, Perpustakaan';

  @override
  String get postTaskErrLocation => 'Sila masukkan lokasi';

  @override
  String get postTaskPinLocation => 'Pin Lokasi Tepat';

  @override
  String get postTaskPriceRunner => 'Harga (RM)';

  @override
  String postTaskMinRm(Object arg0) {
    return 'Min: RM $arg0';
  }

  @override
  String get postTaskErrBounty => 'Sila masukkan jumlah';

  @override
  String get postTaskErrValidNumber => 'Sila masukkan nombor yang sah';

  @override
  String postTaskMinBountyInfo(Object arg0, Object arg1) {
    return 'Upah minimum untuk $arg0: RM $arg1';
  }

  @override
  String get postTaskPosting => 'Menerbitkan...';

  @override
  String get postTaskSubmitService => 'Hantar Servis →';

  @override
  String get postTaskSubmitTask => 'Hantar Tugasan →';

  @override
  String get postTaskServiceVisible =>
      'Servis ini akan dipaparkan kepada pemesan';

  @override
  String get postTaskTaskVisible => 'Tugasan akan dipaparkan dalam senarai';

  @override
  String postTaskLocationPinned(Object arg0, Object arg1) {
    return 'Lokasi ditetapkan: $arg0, $arg1';
  }

  @override
  String get postTaskSubmittedTitle => 'Tugasan Dihantar!';

  @override
  String get postTaskTaskLive => 'Tugasan anda kini LIVE!';

  @override
  String get postTaskRunnersCanSee =>
      'Runner berdekatan boleh melihat tugasan anda';

  @override
  String get postTaskStatusOpen => 'Status: BUKA';

  @override
  String get postTaskTrackStatus => 'Jejak Status →';

  @override
  String get postTaskBackHome => 'Kembali ke Laman Utama';

  @override
  String myTasksTasksPosted(Object arg0) {
    return '$arg0 tugasan diterbitkan';
  }

  @override
  String get myTasksPostTask => 'Minta Bantuan';

  @override
  String get myTasksNoTasks => 'Tiada tugasan';

  @override
  String get myTasksPostFirstTask => 'Terbitkan tugasan pertama anda sekarang!';

  @override
  String get orderStatusTitle => 'Butiran Tugasan';

  @override
  String orderStatusTaskId(Object arg0) {
    return 'ID Tugasan: #GIG-$arg0';
  }

  @override
  String get orderStatusStatusLabel => 'Status';

  @override
  String orderStatusRunnerAssigned(Object arg0) {
    return 'Runner: $arg0';
  }

  @override
  String get orderStatusAssigned => 'Ditetapkan';

  @override
  String orderStatusErrChat(Object arg0) {
    return 'Ralat membuka chat: $arg0';
  }

  @override
  String get orderStatusRateReview => 'Nilai & Ulas Runner';

  @override
  String get orderStatusReviewSubmitted => 'Ulasan dihantar';

  @override
  String get runnerFindGigs => 'Cari Kerja';

  @override
  String runnerNearbyTasks(Object arg0) {
    return 'Berhampiran ($arg0 tugas)';
  }

  @override
  String get runnerNoGigs => 'Tiada kerja buat masa ini';

  @override
  String get runnerCheckBack => 'Sila semak semula nanti';

  @override
  String get runnerTaskDetail => 'Butiran Tugasan';

  @override
  String runnerPostedTime(Object arg0) {
    return 'Diterbitkan $arg0';
  }

  @override
  String get runnerBountyOffered => 'Upah Ditawarkan';

  @override
  String get runnerAcceptTask => 'Terima Tugas';

  @override
  String get runnerChatCustomer => 'Mesej Pemesan';

  @override
  String get runnerMarkComplete => 'Tandakan Selesai';

  @override
  String get runnerConfirmAcceptance => 'Sahkan Penerimaan';

  @override
  String get runnerAboutToAccept => 'Anda akan menerima:';

  @override
  String get runnerWarningLocked =>
      'Setelah diterima, tugasan akan DIKUNCI.\nIa akan dikeluarkan daripada senarai awam.';

  @override
  String get runnerStatusInProgress =>
      'Status tugasan akan ditukar kepada SEDANG BERJALAN.';

  @override
  String get runnerCancel => 'Batal';

  @override
  String get runnerConfirm => 'Sahkan';

  @override
  String get runnerRunnerView => 'Paparan Runner';

  @override
  String get runnerActiveJob => 'Tugasan Aktif:';

  @override
  String get runnerInProgress => 'SEDANG BERJALAN';

  @override
  String get runnerUploadProof => 'Muat Naik Bukti (pilihan)';

  @override
  String get runnerPhotoUploadSoon => 'Fungsi muat naik gambar akan datang!';

  @override
  String get runnerTapUpload => 'Ketik untuk muat naik gambar';

  @override
  String get runnerNotesRequester => 'Nota untuk Pemesan';

  @override
  String get runnerNotesHint => 'Sebarang mesej untuk pelanggan...';

  @override
  String get runnerTaskCompleted => 'Tugasan Selesai!';

  @override
  String get runnerRequesterNotified => 'Pemesan akan dimaklumkan serta-merta.';

  @override
  String get runnerDone => 'Selesai';

  @override
  String get runnerMyJobsTitle => 'Tugasan';

  @override
  String get runnerCustomerTasks => 'Tugas Pelanggan';

  @override
  String get runnerMyServices => 'Servis Saya';

  @override
  String runnerJobsCount(Object arg0) {
    return '$arg0 tugasan';
  }

  @override
  String get runnerPostJob => 'Minta Bantuan';

  @override
  String get runnerNoJobsYet => 'Tiada tugasan';

  @override
  String get runnerAcceptFirstGig => 'Terima tugasan pertama anda sekarang!';

  @override
  String get runnerServiceTakenDown => 'Servis berjaya diturunkan';

  @override
  String get runnerTakeDown => 'Turunkan';

  @override
  String get profileCompleted => 'Selesai';

  @override
  String get profileRating => 'Penilaian';

  @override
  String get profileAccount => 'AKAUN';

  @override
  String get profileAccountDetails => 'Butiran Akaun';

  @override
  String get profilePaymentMethods => 'Kaedah Pembayaran';

  @override
  String get profilePrivacySecurity => 'Privasi & Keselamatan';

  @override
  String get profilePreferences => 'PILIHAN';

  @override
  String get profileLanguage => 'Bahasa';

  @override
  String get profileRoleAccess => 'Akses Peranan';

  @override
  String get profileStatistics => 'Statistik';

  @override
  String get profileTasksPosted => 'Tugasan Diterbit';

  @override
  String get profileDarkMode => 'Mod Gelap';

  @override
  String get profileChooseLanguage => 'Pilih Bahasa';

  @override
  String get profileInviteFriends => 'Jemput Rakan';

  @override
  String get profileInviteFriendsDesc => 'Dapatkan RM5 untuk setiap rujukan!';

  @override
  String get profileSupport => 'SOKONGAN';

  @override
  String get profileHelpCenter => 'Pusat Bantuan';

  @override
  String get profileContactUs => 'Hubungi Kami';

  @override
  String get profileAbout => 'TENTANG';

  @override
  String get profileTerms => 'Terma Perkhidmatan';

  @override
  String get profilePrivacy => 'Dasar Privasi';

  @override
  String get profileRateApp => 'Nilaikan Aplikasi';

  @override
  String get profileLogout => 'Log Keluar';

  @override
  String get profileMadeWithLove => 'Dibuat dengan bangga di Malaysia';

  @override
  String get profileLogoutSuccess => 'Berjaya log keluar!';

  @override
  String profileLanguageChanged(Object arg0) {
    return 'Bahasa ditukar kepada $arg0';
  }

  @override
  String get profileNgamRank => 'Pangkat Ngam (Runner)';

  @override
  String get profileNewRating => 'Baru';

  @override
  String get walletTitle => 'Dompet & Pembayaran';

  @override
  String get walletSwipeHint => 'Leret ke atas atau bawah untuk melihat kad';

  @override
  String get walletBalance => 'Baki';

  @override
  String get walletNgamPay => 'NGAM PAY';

  @override
  String get walletPlatinum => 'PLATINUM';

  @override
  String get walletPrimary => 'UTAMA';

  @override
  String get walletValid => 'SAH';

  @override
  String get walletThru => 'HINGGA';

  @override
  String get walletBankAccount => 'AKAUN BANK';

  @override
  String get walletDuitnowQr => 'DuitNow QR';

  @override
  String get walletShowToReceive => 'Tunjukkan untuk terima bayaran';

  @override
  String get walletRecentTransactions => 'Transaksi Terkini';

  @override
  String get walletTopUp => 'Tambah Nilai';

  @override
  String get walletWithdraw => 'Pengeluaran';

  @override
  String get walletSetPrimary => 'Tetap Utama';

  @override
  String get walletRemove => 'Buang';

  @override
  String get walletAddPaymentMethod => 'Tambah Kaedah Bayaran';

  @override
  String get walletCancel => 'Batal';

  @override
  String get walletAddCreditDebit => 'Tambah Kad Kredit/Debit';

  @override
  String get walletSaveCard => 'Simpan Kad';

  @override
  String get walletLinkBankAccount => 'Pautkan Akaun Bank';

  @override
  String get walletSelectBank => 'PILIH BANK';

  @override
  String get walletLinkAccount => 'Pautkan Akaun';

  @override
  String get walletCustomersScanQr =>
      'Pelanggan akan imbas QR anda untuk bayar';

  @override
  String get walletYourQrCode => 'KOD QR ANDA';

  @override
  String get walletTapUploadQr => 'Ketik untuk muat naik kod QR anda';

  @override
  String get walletFromAnyBank => 'Dari mana-mana aplikasi DuitNow bank';

  @override
  String get walletUploadQrFirst =>
      'Sila muat naik kod QR anda terlebih dahulu';

  @override
  String get walletSaveDuitnowQr => 'Simpan DuitNow QR';

  @override
  String get walletTaskCompletedTx => 'Tugasan Selesai';

  @override
  String get walletWithdrawalTx => 'Pengeluaran';

  @override
  String get walletTopUpTx => 'Tambah Nilai';

  @override
  String get walletPaidForTaskTx => 'Bayaran Tugasan';

  @override
  String get paymentCardNumber => 'Nombor Kad';

  @override
  String get paymentExpiryDate => 'Tarikh Tamat';

  @override
  String get paymentCvv => 'CVV';

  @override
  String get paymentCardholderName => 'Nama Pemegang Kad';

  @override
  String get paymentAccountNumber => 'Nombor Akaun';

  @override
  String get chatMessages => 'Mesej';

  @override
  String get chatSearchConversations => 'Cari perbualan...';

  @override
  String get chatRecent => 'TERKINI';

  @override
  String get chatNoConversations => 'Tiada perbualan lagi.';

  @override
  String get chatNoMatchingConversations => 'Tiada perbualan sepadan.';

  @override
  String get chatDeleteChat => 'Padam Perbualan?';

  @override
  String get chatDeleteChatDesc =>
      'Ini akan memadam perbualan secara kekal untuk anda berdua.';

  @override
  String get chatDelete => 'Padam';

  @override
  String get chatToday => 'Hari Ini';

  @override
  String get chatYesterday => 'Semalam';

  @override
  String get chatCamera => 'Kamera';

  @override
  String get chatGallery => 'Galeri';

  @override
  String get chatFile => 'Fail';

  @override
  String get chatTaskCard => 'Kad Tugasan';

  @override
  String get chatSendQuote => 'Hantar Sebut Harga';

  @override
  String get chatCounterOffer => 'Tawaran Balas';

  @override
  String get chatRequestLocation => 'Minta Lokasi';

  @override
  String get chatTypeMessage => 'Taip mesej...';

  @override
  String get chatStartChat => 'Mulakan perbualan';

  @override
  String get chatOnline => 'Dalam Talian';

  @override
  String get chatOffline => 'Luar Talian';

  @override
  String get chatTyping => 'sedang menaip...';

  @override
  String get chatSend => 'Hantar';

  @override
  String get chatAttachment => 'Lampiran';

  @override
  String get chatPhoto => 'Gambar';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatDocument => 'Dokumen';

  @override
  String get chatLocation => 'Lokasi';

  @override
  String get chatQuoteAmount => 'Jumlah Sebutan';

  @override
  String get chatEnterAmount => 'Masukkan jumlah (RM)';

  @override
  String get chatSendQuoteBtn => 'Hantar Sebut Harga';

  @override
  String get chatCounterOfferBtn => 'Hantar Tawaran Balas';

  @override
  String get chatAccept => 'Terima';

  @override
  String get chatDecline => 'Tolak';

  @override
  String get chatLocationShared => 'Lokasi Dikongsi';

  @override
  String get chatViewMap => 'Lihat di Peta';

  @override
  String get chatTaskInfo => 'Maklumat Tugasan';

  @override
  String get chatBounty => 'Upah';

  @override
  String get chatStatus => 'Status';

  @override
  String get chatLocationRequested => 'Lokasi Diminta';

  @override
  String get chatShareLocationDesc =>
      'Kongsi lokasi anda untuk membantu mengira jarak perjalanan.';

  @override
  String get chatShareLocation => 'Kongsi Lokasi';

  @override
  String get privacyTitle => 'Privasi & Keselamatan';

  @override
  String get privacyAppLock => 'Kunci Apl';

  @override
  String get privacyAppLockDesc =>
      'Gunakan biometrik atau PIN untuk mengunci apl';

  @override
  String get privacyHideAppSwitcher => 'Sembunyikan di Penukar Apl';

  @override
  String get privacyLocationServices => 'Perkhidmatan Lokasi';

  @override
  String get privacyTwoFactorAuth => 'Pengesahan Dua Faktor';

  @override
  String get privacyEnable2fa => 'Dayakan 2FA?';

  @override
  String get privacyDataPrivacy => 'DATA & PRIVASI';

  @override
  String get privacySystemPermissions => 'Kebenaran Sistem';

  @override
  String get privacyManagePermissions => 'Urus Kamera, Galeri, dan GPS';

  @override
  String get privacyClearCache => 'Kosongkan Cache Apl?';

  @override
  String get privacyFreeStorage =>
      'Kosongkan fail sementara untuk melancarkan aplikasi. Data anda kekal selamat.';

  @override
  String get privacyActiveSessions => 'SESI AKTIF';

  @override
  String get privacyThisDevice => 'PERANTI INI';

  @override
  String get privacyActiveNow => 'Aktif Sekarang';

  @override
  String get privacyLogOutAll => 'Log keluar dari semua peranti';

  @override
  String get privacyInstantlySecure => 'Lindungi akaun anda dengan serta-merta';

  @override
  String get privacyEnableAppLock => 'Dayakan Kunci Apl';

  @override
  String get privacyAppLockInfo =>
      'Apl anda akan dikunci dengan biometrik atau PIN peranti setiap kali anda menukar apl.';

  @override
  String get privacyNotNow => 'Bukan Sekarang';

  @override
  String get privacyEnable => 'Dayakan';

  @override
  String get privacyAuthEnableLock => 'Sahkan untuk mendayakan Kunci Apl';

  @override
  String get privacyAuthDisableLock => 'Sahkan untuk menyahdayakan Kunci Apl';

  @override
  String get privacyEnable2faDesc =>
      'Tambah lapisan keselamatan tambahan pada akaun anda. Anda perlu mengesahkan identiti anda apabila log masuk dari peranti baharu.';

  @override
  String get privacyDisable2fa => 'Nyahdayakan Pengesahan Dua Faktor';

  @override
  String get privacyDisable2faDesc =>
      'Akaun anda hanya akan bergantung pada kata laluan anda untuk keselamatan.';

  @override
  String get privacyCacheCleared => 'Cache berjaya dikosongkan';

  @override
  String get privacyLogOutAllTitle => 'Lindungi Akaun?';

  @override
  String get privacyLogOutAllDesc =>
      'Ini akan log keluar anda dari semua peranti lain serta-merta. Anda akan kekal log masuk di telefon ini.';

  @override
  String get privacyLogOutAllBtn => 'Log Keluar Semua';

  @override
  String get privacyActiveSessionsInfo => 'Maklumat Peranti';

  @override
  String get privacyLastLogin => 'Log Masuk Terakhir';

  @override
  String get privacyDevice => 'Peranti';

  @override
  String get privacyIpAddress => 'Alamat IP';

  @override
  String get supportDone => 'Selesai';

  @override
  String get supportHelpCenter => 'Pusat Bantuan';

  @override
  String get supportGreeting => 'Hi\nBagaimana kami boleh bantu?';

  @override
  String get supportSearchHint => 'Cari soalan...';

  @override
  String get supportFaqTitle => 'SOALAN LAZIM';

  @override
  String supportNoResults(Object arg0) {
    return 'Tiada soalan dijumpai untuk \"$arg0\"';
  }

  @override
  String get supportContactUs => 'Hubungi Kami';

  @override
  String get supportContactSubtitle => 'Pasukan kami sedia membantu anda.';

  @override
  String get supportChatSupport => 'Chat Sokongan';

  @override
  String get supportChatSubtitle => 'Kami di sini untuk membantu.';

  @override
  String get supportStartChat => 'Mula Chat';

  @override
  String get supportEmailUs => 'E-mel Kami';

  @override
  String get supportEmailSubtitle => 'Hantar e-mel bila-bila masa.';

  @override
  String get supportCallUs => 'Hubungi Kami';

  @override
  String get supportCallSubtitle => 'Isnin-Jumaat, 9am–5pm.';

  @override
  String get supportFollowUs => 'IKUTI KAMI';

  @override
  String get supportFaq1Q => 'Bagaimana cara posting task?';

  @override
  String get supportFaq1A =>
      'Tekan butang \"+\" di bawah, isi butiran task seperti kategori, lokasi, dan tawaran harga. Kemudian submit dan tunggu runner ambil task anda.';

  @override
  String get supportFaq2Q => 'Bagaimana cara menjadi Runner?';

  @override
  String get supportFaq2A =>
      'Tukar peranan anda kepada \"Runner\" dari profil. Anda kemudian boleh cari task yang tersedia dalam feed dan menerima task yang bersesuaian.';

  @override
  String get supportFaq3Q => 'Bagaimana pembayaran berfungsi?';

  @override
  String get supportFaq3A =>
      'Pembayaran dibuat terus antara Pemesan dan Runner selepas task selesai. Kami cadangkan menggunakan DuitNow atau pemindahan bank.';

  @override
  String get supportFaq4Q => 'Bolehkah saya batalkan task?';

  @override
  String get supportFaq4A =>
      'Ya, anda boleh batalkan task dari halaman \"My Tasks\" selagi task belum diterima oleh runner.';

  @override
  String get supportFaq5Q => 'Apa yang berlaku jika runner tidak hadir?';

  @override
  String get supportFaq5A =>
      'Hubungi kami melalui \"Hubungi Kami\" dan kami akan bantu selesaikan isu tersebut dalam masa 24 jam.';

  @override
  String get supportFaq6Q => 'Adakah runner Ngam boleh dipercayai?';

  @override
  String get supportFaq6A =>
      'Semua runner kami perlu melalui proses verifikasi identiti yang ketat sebelum akaun mereka diaktifkan demi keselamatan anda.';

  @override
  String get supportFaq7Q => 'Bolehkah saya berhubung dengan runner?';

  @override
  String get supportFaq7A =>
      'Ya, anda boleh menggunakan fungsi chat di dalam aplikasi untuk berkomunikasi dengan runner sebaik sahaja mereka menerima task anda.';

  @override
  String get supportFaq8Q => 'Macam mana kalau harga barang berubah?';

  @override
  String get supportFaq8A =>
      'Anda boleh berbincang dengan runner melalui chat. Runner akan memaklumkan harga sebenar berserta resit untuk pengesahan anda.';

  @override
  String get supportFaq9Q => 'Bagaimana cara untuk memberi rating?';

  @override
  String get supportFaq9A =>
      'Selepas task ditandakan sebagai selesai, satu pop-up akan muncul membenarkan anda untuk memberi rating dan ulasan kepada runner.';

  @override
  String get supportFaq10Q => 'Adakah maklumat lokasi saya selamat?';

  @override
  String get supportFaq10A =>
      'Ya, maklumat peribadi dan lokasi tepat anda hanya akan dikongsi dengan runner yang telah sah menerima task anda sahaja.';

  @override
  String get supportFaq11Q => 'Berapa lamakah masa untuk task disiapkan?';

  @override
  String get supportFaq11A =>
      'Masa bergantung kepada jenis task dan jarak lokasi. Anda boleh melihat anggaran masa atau bertanya terus kepada runner.';

  @override
  String get supportFaq12Q => 'Apa jadi jika barang saya rosak?';

  @override
  String get supportFaq12A =>
      'Sila ambil gambar kerosakan dan hubungi khidmat pelanggan kami dalam masa 24 jam untuk bantuan pampasan.';

  @override
  String get supportFaq13Q => 'Bolehkah saya tip runner?';

  @override
  String get supportFaq13A =>
      'Tentu sekali! Anda boleh memberikan tip tunai terus kepada runner atau menyertakan jumlah tip di dalam tawaran harga asal task anda.';

  @override
  String get supportFaq14Q => 'Adakah terdapat had berat untuk barang?';

  @override
  String get supportFaq14A =>
      'Kami mencadangkan berat maksimum 15kg bagi task penghantaran motosikal. Untuk barang yang lebih besar, sila nyatakan dengan jelas di deskripsi.';

  @override
  String get supportFaq15Q =>
      'Bolehkah saya tukar lokasi selepas runner terima task?';

  @override
  String get supportFaq15A =>
      'Perubahan lokasi selepas task diterima tertakluk kepada persetujuan runner. Kos tambahan mungkin dikenakan.';

  @override
  String get aboutLikeNgam => 'Suka Ngam?';

  @override
  String get aboutRateSubtitle => 'Bagi bintang untuk bantu kami berkembang.';

  @override
  String get aboutFeedbackHint => 'Kongsikan pendapat anda tentang Ngam...';

  @override
  String get aboutSubmitFeedback => 'Hantar Maklum Balas';

  @override
  String get aboutThankYou => 'Terima kasih atas maklum balas anda!';

  @override
  String get accountTitle => 'Butiran Akaun';

  @override
  String get accountPublicProfile => 'PROFIL AWAM';

  @override
  String get accountShippingDetails => 'BUTIRAN PENGHANTARAN';

  @override
  String get accountSecurity => 'KESELAMATAN';

  @override
  String get accountSaveChanges => 'Simpan Perubahan';

  @override
  String get accountFullName => 'Nama Penuh';

  @override
  String get accountEmailReadonly => 'Alamat E-mel (Baca Sahaja)';

  @override
  String get accountPhone => 'Nombor Telefon';

  @override
  String get accountDob => 'Tarikh Lahir';

  @override
  String get accountAddress => 'Alamat Penghantaran Utama';

  @override
  String get accountCurrentPassword => 'Kata Laluan Semasa';

  @override
  String get accountNewPassword => 'Kata Laluan Baru';

  @override
  String get reviewTitle => 'Nilai & Ulas';

  @override
  String get reviewHowWas => 'Bagaimana pengalaman anda?';

  @override
  String get reviewTapToRate => 'Ketik bintang untuk menilai';

  @override
  String get reviewLeaveComment => 'Tinggalkan komen (pilihan)';

  @override
  String get reviewCommentHint => 'Ceritakan pengalaman anda...';

  @override
  String get reviewSubmit => 'Hantar Ulasan';

  @override
  String get reviewSubmitting => 'Menghantar...';

  @override
  String get reviewSelectRating => 'Sila pilih penilaian';

  @override
  String get reviewFailed => 'Gagal menghantar ulasan';

  @override
  String get verificationTitle => 'Jadi Runner';

  @override
  String get verificationSubtitle =>
      'Lengkapkan pengesahan untuk mula menjana pendapatan';

  @override
  String get verificationFullName => 'Nama Penuh (Seperti IC)';

  @override
  String get verificationIcNumber => 'Nombor IC';

  @override
  String get verificationVehicleType => 'Jenis Kenderaan';

  @override
  String get verificationUploadIc => 'Muat Naik Gambar IC';

  @override
  String get verificationUploadSelfie => 'Muat Naik Selfie dengan IC';

  @override
  String get verificationSubmit => 'Hantar Pengesahan';

  @override
  String get verificationPending => 'Pengesahan Dalam Proses';

  @override
  String get verificationApproved => 'Runner Disahkan';

  @override
  String get statsTitle => 'Statistik & Pendapatan';

  @override
  String get statsTotalEarnings => 'Jumlah Pendapatan';

  @override
  String get statsCompletedTasks => 'Tugasan Selesai';

  @override
  String get statsAvgRating => 'Purata Penilaian';

  @override
  String get statsWeekly => 'Mingguan';

  @override
  String get statsMonthly => 'Bulanan';

  @override
  String get statsAllTime => 'Sepanjang Masa';

  @override
  String get statsEarningsChart => 'Carta Pendapatan';

  @override
  String get statsNoEarnings => 'Tiada data pendapatan.';

  @override
  String get statsNoTaskData => 'Tiada data tugasan.';

  @override
  String get statsTasksByStatus => 'Tugasan Mengikut Status';

  @override
  String get statsEarningsByCategory => 'Pendapatan Mengikut Kategori';

  @override
  String get statsRecentActivity => 'Aktiviti Terkini';

  @override
  String get rankBronze => 'Runner Gangsa';

  @override
  String get rankSilver => 'Runner Perak';

  @override
  String get rankGold => 'Runner Emas';

  @override
  String get rankPlatinum => 'Runner Platinum';

  @override
  String rankXpToNext(Object arg0) {
    return '$arg0 XP ke pangkat seterusnya';
  }

  @override
  String rankTasksProgress(Object arg0, Object arg1) {
    return '$arg0 / $arg1 Tugasan';
  }

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonConfirm => 'Sahkan';

  @override
  String get commonSave => 'Simpan';

  @override
  String get commonDelete => 'Padam';

  @override
  String get commonEdit => 'Sunting';

  @override
  String get commonClose => 'Tutup';

  @override
  String get commonLoading => 'Memuatkan...';

  @override
  String get commonError => 'Ralat';

  @override
  String get commonSuccess => 'Berjaya';

  @override
  String get commonRetry => 'Cuba Semula';

  @override
  String get commonNoData => 'Tiada data';

  @override
  String get commonLogOut => 'Log Keluar';

  @override
  String get taskDetailNavigate => 'Navigasi ke Lokasi';

  @override
  String get taskDetailManageService => 'Urus Servis';

  @override
  String get taskDetailAdjustBounty => 'Ubah Ganjaran';

  @override
  String get taskDetailDeleteService => 'Padam Servis';

  @override
  String get taskDetailDeleteServiceTitle => 'Padam Servis?';

  @override
  String get taskDetailDeleteServiceDesc =>
      'Adakah anda pasti mahu memadam servis ini secara kekal?';

  @override
  String get taskDetailCancel => 'Batal';

  @override
  String get taskDetailDelete => 'Padam';

  @override
  String get taskDetailSave => 'Simpan';

  @override
  String taskDetailErrorChat(Object arg0) {
    return 'Ralat memulakan perbualan: $arg0';
  }

  @override
  String get navFeed => 'Ngam Feed';

  @override
  String get navInbox => 'Mesej';

  @override
  String get navDiscover => 'Terokai Peta';

  @override
  String get expandSidebar => 'Kembangkan Sidebar';

  @override
  String get collapseSidebar => 'Kecilkan Sidebar';

  @override
  String get lightMode => 'Mod Cerah';

  @override
  String get switchLanguage => 'Tukar Bahasa';

  @override
  String homeGreeting(Object name) {
    return 'Hai, $name';
  }

  @override
  String get homeSearchPlaceholder => 'Cari servis, kedai, barangan...';

  @override
  String homeCurrentLocation(Object location) {
    return 'Lokasi semasa: $location';
  }

  @override
  String homeLocationDetected(Object location) {
    return 'Lokasi dikesan: $location';
  }

  @override
  String get homeNearbyStores => 'Kedai Berdekatan';

  @override
  String get homeSeeAll => 'Lihat Semua';

  @override
  String get homePopularOffers => 'Tawaran Hebat';

  @override
  String get homeTrendingPort => 'Port Viral';

  @override
  String get homeQuickCategories => 'Kategori Pantas';

  @override
  String get homeLiveQueue => 'Giliran Saya';

  @override
  String get homeStampsCard => 'Ganjaran Setem';

  @override
  String get homeFlashPromo => 'Flash RM10';

  @override
  String get homeFlashDesc => 'Potong Rambut';

  @override
  String get homeViralCafe => 'Port Viral';

  @override
  String get homeViralDesc => 'Kopi & Roti';

  @override
  String get homeDetailing => 'Nano Detailing';

  @override
  String get homeDetailingDesc => 'Diskaun 30%';

  @override
  String get homeDailyCoupon => 'Daily Promo';

  @override
  String get homeDailyCouponDesc => 'Kupon RM5';

  @override
  String get homeSpaRelax => 'Spa & Relaks';

  @override
  String get homeSpaRelaxDesc => 'Slot Petang';

  @override
  String get catBarber => 'Gunting Rambut';

  @override
  String get catCarwash => 'Cuci Kereta';

  @override
  String get catCafe => 'Kafe & Port Chill';

  @override
  String get catWorkshop => 'Bengkel & Servis';

  @override
  String get catSalon => 'Salun & Spa';

  @override
  String get catHealth => 'Klinik & Kesihatan';

  @override
  String get feedForYou => 'Untuk Anda';

  @override
  String get feedFollowing => 'Mengikuti';

  @override
  String get feedBookNow => 'Tempah Sekarang';

  @override
  String get feedVisitStore => 'Lawati Kedai';

  @override
  String get storeCatalog => 'Katalog';

  @override
  String get storeMenu => 'Menu';

  @override
  String get storeReviews => 'Ulasan';

  @override
  String get storeInfo => 'Maklumat';

  @override
  String get storeAllItems => 'Semua Barangan';

  @override
  String get storeBookQueue => 'Tempah / Giliran';

  @override
  String get bookingCancelTitle => 'Batal Tempahan';

  @override
  String get bookingDisputeTitle => 'Aduan Pertikaian';

  @override
  String get bookingRefundNote =>
      'Baki bayaran akan dikreditkan kembali ke Ngam Wallet anda.';

  @override
  String get profileStampCards => 'Kad Cop Ganjaran (Stamps)';

  @override
  String get profileLiveQueue => 'Tiket Giliran Walk-In (Live Queue)';

  @override
  String get profileCheckUpdates => 'Semak Kemas Kini Aplikasi';

  @override
  String get profileGuestUser => 'Tetamu (Guest)';

  @override
  String get profileGuestSubtitle =>
      'Log masuk untuk mengurus pesanan dan ganjaran anda.';

  @override
  String get profileLoginRegister => 'Log Masuk / Daftar';

  @override
  String get profileSaved => 'Disimpan';

  @override
  String get profileSavedShops => 'Kedai Disimpan';

  @override
  String get profileSavedPosts => 'Hantaran Disimpan';
}
