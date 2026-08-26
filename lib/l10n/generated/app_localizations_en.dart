// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get profile => 'Profile';

  @override
  String get preferences => 'Preferences';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get language => 'Language';

  @override
  String get currentLanguage => 'English';

  @override
  String get account => 'Account';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get paymentMethods => 'Payment Methods';

  @override
  String get privacySecurity => 'Privacy & Security';

  @override
  String get logOut => 'Log Out';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get malay => 'Bahasa Melayu';

  @override
  String get searchHint => 'Search';

  @override
  String get nearby => 'Nearby';

  @override
  String get statusOpenCaps => 'OPEN';

  @override
  String get statusClosingCaps => 'CLOSING SOON';

  @override
  String get statusClosedCaps => 'CLOSED';

  @override
  String get statusOpenNow => 'Open Now';

  @override
  String get statusClosingSoon => 'Closing Soon';

  @override
  String get statusClosed => 'Closed';

  @override
  String closingIn(int minutes) {
    return 'CLOSING IN ${minutes}M';
  }

  @override
  String get rating => 'Rating';

  @override
  String get reviews => 'Reviews';

  @override
  String get away => 'Away';

  @override
  String get call => 'Call';

  @override
  String get directions => 'Directions';

  @override
  String get operatingHours => 'Operating Hours';

  @override
  String get today => 'Today';

  @override
  String todayDay(String day) {
    return 'Today ($day)';
  }

  @override
  String get servicesAvailable => 'Services Available';

  @override
  String get generalService => 'General Service';

  @override
  String get recentReviews => 'Recent Reviews';

  @override
  String get noReviewsYet => 'No reviews yet.';

  @override
  String get user => 'User';

  @override
  String get rezrvNow => 'Rezrv Now';

  @override
  String resultsFor(String query) {
    return 'Results for \'$query\'';
  }

  @override
  String get noResultsFoundTitle => 'No results found';

  @override
  String get noLocationsMatch => 'No locations match your search.';

  @override
  String get noMatchesFound => 'No matches found';

  @override
  String get trySearchingDifferent =>
      'Try searching for a different shop or service.';

  @override
  String get clear => 'Clear';

  @override
  String get locating => 'Locating...';

  @override
  String get locationDisabled => 'Location disabled';

  @override
  String get permissionDenied => 'Permission denied';

  @override
  String get permissionDeniedForever => 'Permission denied forever';

  @override
  String get unknownCity => 'Unknown City';

  @override
  String get unknownState => 'Unknown State';

  @override
  String get locationUnavailable => 'Location unavailable';

  @override
  String hiUser(String firstName) {
    return 'Hi, $firstName';
  }

  @override
  String get promotions => 'Promotions';

  @override
  String get categories => 'Categories';

  @override
  String get recommended => 'Recommended';

  @override
  String get seeAll => 'See All';

  @override
  String get promoLabel => 'PROMO';

  @override
  String get claimButton => 'Claim';

  @override
  String get catHaircuts => 'Haircuts';

  @override
  String get catShaving => 'Shaving';

  @override
  String get catColoring => 'Coloring';

  @override
  String get catStyling => 'Styling';

  @override
  String get catFacial => 'Facial';

  @override
  String get catMassage => 'Massage';

  @override
  String get catNails => 'Nails';

  @override
  String get catMore => 'More';

  @override
  String get unknownShop => 'Unknown';

  @override
  String get generalCategory => 'General';

  @override
  String get myBarbrTitle => 'My Barbr';

  @override
  String get tabUpcoming => 'Upcoming';

  @override
  String get tabHistory => 'History';

  @override
  String get noPastReservations => 'No past or cancelled reservations.';

  @override
  String get noUpcomingReservations =>
      'No upcoming reservations yet.\nBook a service to see it here!';

  @override
  String get cancelBtn => 'Cancel';

  @override
  String get viewTicketBtn => 'View Ticket';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusDone => 'Done';

  @override
  String get ticketOrderTitle => 'Order';

  @override
  String get ticketProvider => 'Provider';

  @override
  String get ticketDate => 'Date';

  @override
  String get ticketTime => 'Time';

  @override
  String get ticketBookingId => 'Booking ID';

  @override
  String get ticketTotalPaid => 'Total Paid';

  @override
  String get ticketScanHint => 'Scan at the counter upon arrival';

  @override
  String get ticketCallOwner => 'Call Owner';

  @override
  String get bkTitleComplete => 'Booking complete!';

  @override
  String get bkTitleProvider => 'Select provider:';

  @override
  String get bkTitleServices => 'Select Services:';

  @override
  String get bkTitleCheckout => 'Checkout & payment:';

  @override
  String get bkApptDate => 'Appointment Date';

  @override
  String get bkAvailTime => 'Available Time';

  @override
  String get bkMainService => 'Select Main Service';

  @override
  String get bkAddons => 'Extra Add-ons';

  @override
  String get bkHealthSafety => 'Health & Safety';

  @override
  String get bkAllergies => 'Skin allergies or sensitivities?';

  @override
  String get bkSummary => 'Booking Summary';

  @override
  String get bkLocation => 'Location';

  @override
  String get bkProvider => 'Provider';

  @override
  String get bkDate => 'Date';

  @override
  String get bkTime => 'Time';

  @override
  String get bkEstDuration => 'Estimated Duration';

  @override
  String bkMins(int time) {
    return '~$time mins';
  }

  @override
  String get bkPaymentMethod => 'Payment Method';

  @override
  String get bkCreditCard => 'Credit / Debit Card';

  @override
  String get bkOnlineBanking => 'Online Banking (FPX)';

  @override
  String get bkCash => 'Cash at Counter';

  @override
  String get bkNoCards => 'No cards saved. Please add one in your Profile.';

  @override
  String get bkGrandTotal => 'Grand Total';

  @override
  String get bkContinue => 'Continue';

  @override
  String bkConfirmPay(String price) {
    return 'Confirm & Pay $price';
  }

  @override
  String get bkCardHolder => 'Card Holder';

  @override
  String get bkExpires => 'Expires';

  @override
  String get bkConfirmed => 'Booking Confirmed!';

  @override
  String get bkNotified => 'Your provider has been notified.';

  @override
  String get bkViewOrder => 'View Order';

  @override
  String get bkBackHome => 'Back to Home';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navMyBarbr => 'My Barbr';

  @override
  String get navSaved => 'Saved';

  @override
  String get shopDetailDummyAddress => '123 Main Street, City Center';

  @override
  String get shopDetailDummyHours => 'Open Now • Closes at 10:00 PM';

  @override
  String get shopDetailAbout => 'About';

  @override
  String get shopDetailAboutDesc =>
      'Experience premium grooming and wellness services in a relaxing environment. Our professionals are dedicated to making you look and feel your absolute best.';

  @override
  String get exploreCatBeauty => 'Beauty & Wellness';

  @override
  String get exploreCatBarber => 'Barber Shop';

  @override
  String get exploreCatHealth => 'Health & Clinic';

  @override
  String get exploreCatFood => 'Food & Drinks';

  @override
  String get exploreCatRestaurant => 'Restaurant';

  @override
  String get exploreCatCafe => 'Cafe';

  @override
  String get exploreCatAuto => 'Auto & Transport';

  @override
  String get exploreCatWorkshop => 'Workshop & Repair';

  @override
  String get exploreCatGas => 'Gas Station';

  @override
  String get exploreCatDaily => 'Daily Needs';

  @override
  String get exploreCatSupermarket => 'Supermarket';

  @override
  String get exploreCatBanking => 'Banking';

  @override
  String get exploreCatCommunity => 'Community';

  @override
  String get exploreCatSchool => 'School';

  @override
  String get exploreCatReligion => 'Religion';

  @override
  String searchAll(String category) {
    return 'All $category';
  }

  @override
  String get searchHeadersCategories => 'CATEGORIES';

  @override
  String get searchHeadersShops => 'SHOPS & SERVICES';

  @override
  String searchMatchProvides(String service) {
    return 'Provides $service';
  }

  @override
  String get msgVia => 'Message via';

  @override
  String get msgWhatsApp => 'WhatsApp';

  @override
  String get msgTelegram => 'Telegram';

  @override
  String get msgSMS => 'SMS Message';

  @override
  String get btnViewProfile => 'View Profile';

  @override
  String get piProfileUpdated => 'Profile updated successfully!';

  @override
  String get piFullName => 'Full Name';

  @override
  String get piFullNameHint => 'Enter your full name';

  @override
  String get piEmail => 'Email Address';

  @override
  String get piEmailHint => 'Enter your email';

  @override
  String get piPhone => 'Phone Number';

  @override
  String get piPhoneHint => 'Enter your phone number';

  @override
  String get piDob => 'Date of Birth';

  @override
  String get piDobHint => 'DD / MM / YYYY';

  @override
  String get piSaveChanges => 'Save Changes';

  @override
  String get savedTitle => 'My Saved';

  @override
  String get savedEmptyState => 'You haven\'t saved any spots yet.';

  @override
  String get ticketCountdownPast => 'Appointment Started/Passed';

  @override
  String ticketCountdownStartsIn(String duration) {
    return 'Starts in: $duration';
  }

  @override
  String get support => 'Support';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get about => 'About';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get rateUs => 'Rate the App';

  @override
  String get inviteFriends => 'Invite Friends';

  @override
  String get referralText => 'Get RM10 for every referral';

  @override
  String get madeIn => 'Made with ❤️ in Malaysia';
}
