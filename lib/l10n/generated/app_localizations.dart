import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ms.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ms'),
  ];

  /// The title shown in the AppBar
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @currentLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get currentLanguage;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethods;

  /// No description provided for @privacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurity;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @malay.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Melayu'**
  String get malay;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @statusOpenCaps.
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get statusOpenCaps;

  /// No description provided for @statusClosingCaps.
  ///
  /// In en, this message translates to:
  /// **'CLOSING SOON'**
  String get statusClosingCaps;

  /// No description provided for @statusClosedCaps.
  ///
  /// In en, this message translates to:
  /// **'CLOSED'**
  String get statusClosedCaps;

  /// No description provided for @statusOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open Now'**
  String get statusOpenNow;

  /// No description provided for @statusClosingSoon.
  ///
  /// In en, this message translates to:
  /// **'Closing Soon'**
  String get statusClosingSoon;

  /// No description provided for @statusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get statusClosed;

  /// Countdown for when a shop is closing soon
  ///
  /// In en, this message translates to:
  /// **'CLOSING IN {minutes}M'**
  String closingIn(int minutes);

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @away.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get away;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @operatingHours.
  ///
  /// In en, this message translates to:
  /// **'Operating Hours'**
  String get operatingHours;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @todayDay.
  ///
  /// In en, this message translates to:
  /// **'Today ({day})'**
  String todayDay(Object day);

  /// No description provided for @servicesAvailable.
  ///
  /// In en, this message translates to:
  /// **'Services Available'**
  String get servicesAvailable;

  /// No description provided for @generalService.
  ///
  /// In en, this message translates to:
  /// **'General Service'**
  String get generalService;

  /// No description provided for @recentReviews.
  ///
  /// In en, this message translates to:
  /// **'Recent Reviews'**
  String get recentReviews;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get noReviewsYet;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @rezrvNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get rezrvNow;

  /// No description provided for @resultsFor.
  ///
  /// In en, this message translates to:
  /// **'Results for \'{query}\''**
  String resultsFor(Object query);

  /// No description provided for @noResultsFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFoundTitle;

  /// No description provided for @noLocationsMatch.
  ///
  /// In en, this message translates to:
  /// **'No locations match your search.'**
  String get noLocationsMatch;

  /// No description provided for @noMatchesFound.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get noMatchesFound;

  /// No description provided for @trySearchingDifferent.
  ///
  /// In en, this message translates to:
  /// **'Try searching for a different shop or service.'**
  String get trySearchingDifferent;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get locating;

  /// No description provided for @locationDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location disabled'**
  String get locationDisabled;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get permissionDenied;

  /// No description provided for @permissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Permission denied forever'**
  String get permissionDeniedForever;

  /// No description provided for @unknownCity.
  ///
  /// In en, this message translates to:
  /// **'Unknown City'**
  String get unknownCity;

  /// No description provided for @unknownState.
  ///
  /// In en, this message translates to:
  /// **'Unknown State'**
  String get unknownState;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationUnavailable;

  /// No description provided for @hiUser.
  ///
  /// In en, this message translates to:
  /// **'Hi, {firstName}'**
  String hiUser(Object firstName);

  /// No description provided for @promotions.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get promotions;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @promoLabel.
  ///
  /// In en, this message translates to:
  /// **'PROMO'**
  String get promoLabel;

  /// No description provided for @claimButton.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claimButton;

  /// No description provided for @catHaircuts.
  ///
  /// In en, this message translates to:
  /// **'Haircuts'**
  String get catHaircuts;

  /// No description provided for @catShaving.
  ///
  /// In en, this message translates to:
  /// **'Shaving'**
  String get catShaving;

  /// No description provided for @catColoring.
  ///
  /// In en, this message translates to:
  /// **'Coloring'**
  String get catColoring;

  /// No description provided for @catStyling.
  ///
  /// In en, this message translates to:
  /// **'Styling'**
  String get catStyling;

  /// No description provided for @catFacial.
  ///
  /// In en, this message translates to:
  /// **'Facial'**
  String get catFacial;

  /// No description provided for @catMassage.
  ///
  /// In en, this message translates to:
  /// **'Massage'**
  String get catMassage;

  /// No description provided for @catNails.
  ///
  /// In en, this message translates to:
  /// **'Nails'**
  String get catNails;

  /// No description provided for @catMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get catMore;

  /// No description provided for @unknownShop.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownShop;

  /// No description provided for @generalCategory.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalCategory;

  /// No description provided for @myBarbrTitle.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get myBarbrTitle;

  /// No description provided for @tabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tabUpcoming;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @noPastReservations.
  ///
  /// In en, this message translates to:
  /// **'No past or cancelled bookings.'**
  String get noPastReservations;

  /// No description provided for @noUpcomingReservations.
  ///
  /// In en, this message translates to:
  /// **'No upcoming bookings yet.\nBook a service to see it here!'**
  String get noUpcomingReservations;

  /// No description provided for @cancelBtn.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelBtn;

  /// No description provided for @viewTicketBtn.
  ///
  /// In en, this message translates to:
  /// **'View Ticket'**
  String get viewTicketBtn;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @ticketOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get ticketOrderTitle;

  /// No description provided for @ticketProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get ticketProvider;

  /// No description provided for @ticketDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get ticketDate;

  /// No description provided for @ticketTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get ticketTime;

  /// No description provided for @ticketBookingId.
  ///
  /// In en, this message translates to:
  /// **'Booking ID'**
  String get ticketBookingId;

  /// No description provided for @ticketTotalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get ticketTotalPaid;

  /// No description provided for @ticketScanHint.
  ///
  /// In en, this message translates to:
  /// **'Scan at the counter upon arrival'**
  String get ticketScanHint;

  /// No description provided for @ticketCallOwner.
  ///
  /// In en, this message translates to:
  /// **'Call Owner'**
  String get ticketCallOwner;

  /// No description provided for @bkTitleComplete.
  ///
  /// In en, this message translates to:
  /// **'Booking complete!'**
  String get bkTitleComplete;

  /// No description provided for @bkTitleProvider.
  ///
  /// In en, this message translates to:
  /// **'Select provider:'**
  String get bkTitleProvider;

  /// No description provided for @bkTitleServices.
  ///
  /// In en, this message translates to:
  /// **'Select Services:'**
  String get bkTitleServices;

  /// No description provided for @bkTitleCheckout.
  ///
  /// In en, this message translates to:
  /// **'Checkout & payment:'**
  String get bkTitleCheckout;

  /// No description provided for @bkApptDate.
  ///
  /// In en, this message translates to:
  /// **'Appointment Date'**
  String get bkApptDate;

  /// No description provided for @bkAvailTime.
  ///
  /// In en, this message translates to:
  /// **'Available Time'**
  String get bkAvailTime;

  /// No description provided for @bkMainService.
  ///
  /// In en, this message translates to:
  /// **'Select Main Service'**
  String get bkMainService;

  /// No description provided for @bkAddons.
  ///
  /// In en, this message translates to:
  /// **'Extra Add-ons'**
  String get bkAddons;

  /// No description provided for @bkHealthSafety.
  ///
  /// In en, this message translates to:
  /// **'Health & Safety'**
  String get bkHealthSafety;

  /// No description provided for @bkAllergies.
  ///
  /// In en, this message translates to:
  /// **'Skin allergies or sensitivities?'**
  String get bkAllergies;

  /// No description provided for @bkSummary.
  ///
  /// In en, this message translates to:
  /// **'Booking Summary'**
  String get bkSummary;

  /// No description provided for @bkLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get bkLocation;

  /// No description provided for @bkProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get bkProvider;

  /// No description provided for @bkDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get bkDate;

  /// No description provided for @bkTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get bkTime;

  /// No description provided for @bkEstDuration.
  ///
  /// In en, this message translates to:
  /// **'Estimated Duration'**
  String get bkEstDuration;

  /// No description provided for @bkMins.
  ///
  /// In en, this message translates to:
  /// **'~{time} mins'**
  String bkMins(Object time);

  /// No description provided for @bkPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get bkPaymentMethod;

  /// No description provided for @bkCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit / Debit Card'**
  String get bkCreditCard;

  /// No description provided for @bkOnlineBanking.
  ///
  /// In en, this message translates to:
  /// **'Online Banking (FPX)'**
  String get bkOnlineBanking;

  /// No description provided for @bkCash.
  ///
  /// In en, this message translates to:
  /// **'Cash at Counter'**
  String get bkCash;

  /// No description provided for @bkNoCards.
  ///
  /// In en, this message translates to:
  /// **'No cards saved. Please add one in your Profile.'**
  String get bkNoCards;

  /// No description provided for @bkGrandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get bkGrandTotal;

  /// No description provided for @bkContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get bkContinue;

  /// No description provided for @bkConfirmPay.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Pay {price}'**
  String bkConfirmPay(Object price);

  /// No description provided for @bkCardHolder.
  ///
  /// In en, this message translates to:
  /// **'Card Holder'**
  String get bkCardHolder;

  /// No description provided for @bkExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get bkExpires;

  /// No description provided for @bkConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking Confirmed!'**
  String get bkConfirmed;

  /// No description provided for @bkNotified.
  ///
  /// In en, this message translates to:
  /// **'Your provider has been notified.'**
  String get bkNotified;

  /// No description provided for @bkViewOrder.
  ///
  /// In en, this message translates to:
  /// **'View Order'**
  String get bkViewOrder;

  /// No description provided for @bkBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get bkBackHome;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navMyBarbr.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get navMyBarbr;

  /// No description provided for @navSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get navSaved;

  /// No description provided for @shopDetailDummyAddress.
  ///
  /// In en, this message translates to:
  /// **'123 Main Street, City Center'**
  String get shopDetailDummyAddress;

  /// No description provided for @shopDetailDummyHours.
  ///
  /// In en, this message translates to:
  /// **'Open Now • Closes at 10:00 PM'**
  String get shopDetailDummyHours;

  /// No description provided for @shopDetailAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get shopDetailAbout;

  /// No description provided for @shopDetailAboutDesc.
  ///
  /// In en, this message translates to:
  /// **'Experience premium grooming and wellness services in a relaxing environment. Our professionals are dedicated to making you look and feel your absolute best.'**
  String get shopDetailAboutDesc;

  /// No description provided for @exploreCatBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty & Wellness'**
  String get exploreCatBeauty;

  /// No description provided for @exploreCatBarber.
  ///
  /// In en, this message translates to:
  /// **'Barber Shop'**
  String get exploreCatBarber;

  /// No description provided for @exploreCatHealth.
  ///
  /// In en, this message translates to:
  /// **'Health & Clinic'**
  String get exploreCatHealth;

  /// No description provided for @exploreCatFood.
  ///
  /// In en, this message translates to:
  /// **'Food & Drinks'**
  String get exploreCatFood;

  /// No description provided for @exploreCatRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get exploreCatRestaurant;

  /// No description provided for @exploreCatCafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe'**
  String get exploreCatCafe;

  /// No description provided for @exploreCatAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto & Transport'**
  String get exploreCatAuto;

  /// No description provided for @exploreCatWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop & Repair'**
  String get exploreCatWorkshop;

  /// No description provided for @exploreCatGas.
  ///
  /// In en, this message translates to:
  /// **'Gas Station'**
  String get exploreCatGas;

  /// No description provided for @exploreCatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily Needs'**
  String get exploreCatDaily;

  /// No description provided for @exploreCatSupermarket.
  ///
  /// In en, this message translates to:
  /// **'Supermarket'**
  String get exploreCatSupermarket;

  /// No description provided for @exploreCatBanking.
  ///
  /// In en, this message translates to:
  /// **'Banking'**
  String get exploreCatBanking;

  /// No description provided for @exploreCatCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get exploreCatCommunity;

  /// No description provided for @exploreCatSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get exploreCatSchool;

  /// No description provided for @exploreCatReligion.
  ///
  /// In en, this message translates to:
  /// **'Religion'**
  String get exploreCatReligion;

  /// No description provided for @searchAll.
  ///
  /// In en, this message translates to:
  /// **'All {category}'**
  String searchAll(Object category);

  /// No description provided for @searchHeadersCategories.
  ///
  /// In en, this message translates to:
  /// **'CATEGORIES'**
  String get searchHeadersCategories;

  /// No description provided for @searchHeadersShops.
  ///
  /// In en, this message translates to:
  /// **'SHOPS & SERVICES'**
  String get searchHeadersShops;

  /// No description provided for @searchMatchProvides.
  ///
  /// In en, this message translates to:
  /// **'Provides {service}'**
  String searchMatchProvides(Object service);

  /// No description provided for @msgVia.
  ///
  /// In en, this message translates to:
  /// **'Message via'**
  String get msgVia;

  /// No description provided for @msgWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get msgWhatsApp;

  /// No description provided for @msgTelegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get msgTelegram;

  /// No description provided for @msgSMS.
  ///
  /// In en, this message translates to:
  /// **'SMS Message'**
  String get msgSMS;

  /// No description provided for @btnViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Store'**
  String get btnViewProfile;

  /// No description provided for @piProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get piProfileUpdated;

  /// No description provided for @piFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get piFullName;

  /// No description provided for @piFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get piFullNameHint;

  /// No description provided for @piEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get piEmail;

  /// No description provided for @piEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get piEmailHint;

  /// No description provided for @piPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get piPhone;

  /// No description provided for @piPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get piPhoneHint;

  /// No description provided for @piDob.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get piDob;

  /// No description provided for @piDobHint.
  ///
  /// In en, this message translates to:
  /// **'DD / MM / YYYY'**
  String get piDobHint;

  /// No description provided for @piSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get piSaveChanges;

  /// No description provided for @savedTitle.
  ///
  /// In en, this message translates to:
  /// **'My Saved'**
  String get savedTitle;

  /// No description provided for @savedEmptyState.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t saved any spots yet.'**
  String get savedEmptyState;

  /// No description provided for @ticketCountdownPast.
  ///
  /// In en, this message translates to:
  /// **'Appointment Started/Passed'**
  String get ticketCountdownPast;

  /// No description provided for @ticketCountdownStartsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in: {duration}'**
  String ticketCountdownStartsIn(Object duration);

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @rateUs.
  ///
  /// In en, this message translates to:
  /// **'Rate the App'**
  String get rateUs;

  /// No description provided for @inviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends'**
  String get inviteFriends;

  /// No description provided for @referralText.
  ///
  /// In en, this message translates to:
  /// **'Get RM10 for every referral'**
  String get referralText;

  /// No description provided for @madeIn.
  ///
  /// In en, this message translates to:
  /// **'Made with pride in Malaysia'**
  String get madeIn;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @authLogout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get authLogout;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get authWelcomeBack;

  /// No description provided for @authWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue using Ngam'**
  String get authWelcomeSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authLogin;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authNoAccount;

  /// No description provided for @authRegisterHere.
  ///
  /// In en, this message translates to:
  /// **'Register here'**
  String get authRegisterHere;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join Ngam community today'**
  String get authRegisterSubtitle;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Legal Name'**
  String get authFullName;

  /// No description provided for @authPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get authPhone;

  /// No description provided for @authRoleSelect.
  ///
  /// In en, this message translates to:
  /// **'I want to:'**
  String get authRoleSelect;

  /// No description provided for @authRoleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Post Tasks'**
  String get authRoleCustomer;

  /// No description provided for @authRoleRunner.
  ///
  /// In en, this message translates to:
  /// **'Earn as Runner'**
  String get authRoleRunner;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authRegister;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authHaveAccount;

  /// No description provided for @authLoginHere.
  ///
  /// In en, this message translates to:
  /// **'Sign in here'**
  String get authLoginHere;

  /// No description provided for @authPleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authPleaseEnterEmail;

  /// No description provided for @authValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get authValidEmail;

  /// No description provided for @authPleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authPleaseEnterPassword;

  /// No description provided for @authPleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authPleaseEnterName;

  /// No description provided for @authPleaseEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get authPleaseEnterPhone;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordMinLength;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPassword;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get authForgotPassword;

  /// No description provided for @authOrContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get authOrContinueWith;

  /// No description provided for @authGoogleSignin.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get authGoogleSignin;

  /// No description provided for @authAppleSignin.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get authAppleSignin;

  /// No description provided for @navMyTasks.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get navMyTasks;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @customerGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {arg0}'**
  String customerGreeting(Object arg0);

  /// No description provided for @customerWhatDoYouNeed.
  ///
  /// In en, this message translates to:
  /// **'What do you need done today?'**
  String get customerWhatDoYouNeed;

  /// No description provided for @customerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for tasks or services...'**
  String get customerSearchHint;

  /// No description provided for @customerQuickCategories.
  ///
  /// In en, this message translates to:
  /// **'Quick Categories'**
  String get customerQuickCategories;

  /// No description provided for @customerNearbyRunners.
  ///
  /// In en, this message translates to:
  /// **'Nearby Runners Ready'**
  String get customerNearbyRunners;

  /// No description provided for @customerRecentTasks.
  ///
  /// In en, this message translates to:
  /// **'Your Recent Tasks'**
  String get customerRecentTasks;

  /// No description provided for @customerViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get customerViewAll;

  /// No description provided for @customerPostNewTask.
  ///
  /// In en, this message translates to:
  /// **'Post a New Task'**
  String get customerPostNewTask;

  /// No description provided for @customerTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get customerTaskTitle;

  /// No description provided for @customerTaskDesc.
  ///
  /// In en, this message translates to:
  /// **'Describe what you need done...'**
  String get customerTaskDesc;

  /// No description provided for @customerBounty.
  ///
  /// In en, this message translates to:
  /// **'Bounty Amount (RM)'**
  String get customerBounty;

  /// No description provided for @customerLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get customerLocation;

  /// No description provided for @customerPostTask.
  ///
  /// In en, this message translates to:
  /// **'Post Task Now'**
  String get customerPostTask;

  /// No description provided for @customerAvailableServices.
  ///
  /// In en, this message translates to:
  /// **'Available Services ({arg0})'**
  String customerAvailableServices(Object arg0);

  /// No description provided for @customerNoServices.
  ///
  /// In en, this message translates to:
  /// **'No services available right now.'**
  String get customerNoServices;

  /// No description provided for @customerRunnersWillPost.
  ///
  /// In en, this message translates to:
  /// **'Runners will post new services soon.'**
  String get customerRunnersWillPost;

  /// No description provided for @customerServiceOrdered.
  ///
  /// In en, this message translates to:
  /// **'Service ordered successfully!'**
  String get customerServiceOrdered;

  /// No description provided for @customerOrderService.
  ///
  /// In en, this message translates to:
  /// **'Order Service'**
  String get customerOrderService;

  /// No description provided for @postTaskTitleRunner.
  ///
  /// In en, this message translates to:
  /// **'Post a Service'**
  String get postTaskTitleRunner;

  /// No description provided for @postTaskTitleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Post New Task'**
  String get postTaskTitleCustomer;

  /// No description provided for @postTaskServiceTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Title'**
  String get postTaskServiceTitleLabel;

  /// No description provided for @postTaskServiceTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., I will print 10 pages'**
  String get postTaskServiceTitleHint;

  /// No description provided for @postTaskTaskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Print assignment 10 pages'**
  String get postTaskTaskTitleHint;

  /// No description provided for @postTaskErrTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get postTaskErrTitle;

  /// No description provided for @postTaskServiceDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Service Description'**
  String get postTaskServiceDescLabel;

  /// No description provided for @postTaskTaskDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Task Description'**
  String get postTaskTaskDescLabel;

  /// No description provided for @postTaskServiceDescHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what you can do...'**
  String get postTaskServiceDescHint;

  /// No description provided for @postTaskErrDesc.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get postTaskErrDesc;

  /// No description provided for @postTaskCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get postTaskCategory;

  /// No description provided for @postTaskLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location / Drop-off Name'**
  String get postTaskLocationLabel;

  /// No description provided for @postTaskLocationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Block C, Campus Library'**
  String get postTaskLocationHint;

  /// No description provided for @postTaskErrLocation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a location name'**
  String get postTaskErrLocation;

  /// No description provided for @postTaskPinLocation.
  ///
  /// In en, this message translates to:
  /// **'Pin Exact Location'**
  String get postTaskPinLocation;

  /// No description provided for @postTaskPriceRunner.
  ///
  /// In en, this message translates to:
  /// **'Price (RM)'**
  String get postTaskPriceRunner;

  /// No description provided for @postTaskMinRm.
  ///
  /// In en, this message translates to:
  /// **'Min: RM {arg0}'**
  String postTaskMinRm(Object arg0);

  /// No description provided for @postTaskErrBounty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a bounty amount'**
  String get postTaskErrBounty;

  /// No description provided for @postTaskErrValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get postTaskErrValidNumber;

  /// No description provided for @postTaskMinBountyInfo.
  ///
  /// In en, this message translates to:
  /// **'Minimum bounty for {arg0}: RM {arg1}'**
  String postTaskMinBountyInfo(Object arg0, Object arg1);

  /// No description provided for @postTaskPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting...'**
  String get postTaskPosting;

  /// No description provided for @postTaskSubmitService.
  ///
  /// In en, this message translates to:
  /// **'Submit Service →'**
  String get postTaskSubmitService;

  /// No description provided for @postTaskSubmitTask.
  ///
  /// In en, this message translates to:
  /// **'Submit Task →'**
  String get postTaskSubmitTask;

  /// No description provided for @postTaskServiceVisible.
  ///
  /// In en, this message translates to:
  /// **'Service will be visible to customers'**
  String get postTaskServiceVisible;

  /// No description provided for @postTaskTaskVisible.
  ///
  /// In en, this message translates to:
  /// **'Task will appear in the live feed once submitted'**
  String get postTaskTaskVisible;

  /// No description provided for @postTaskLocationPinned.
  ///
  /// In en, this message translates to:
  /// **'Location pinned: {arg0}, {arg1}'**
  String postTaskLocationPinned(Object arg0, Object arg1);

  /// No description provided for @postTaskSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Submitted!'**
  String get postTaskSubmittedTitle;

  /// No description provided for @postTaskTaskLive.
  ///
  /// In en, this message translates to:
  /// **'Task is now LIVE!'**
  String get postTaskTaskLive;

  /// No description provided for @postTaskRunnersCanSee.
  ///
  /// In en, this message translates to:
  /// **'Runners nearby can see your task in the feed'**
  String get postTaskRunnersCanSee;

  /// No description provided for @postTaskStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Status: OPEN'**
  String get postTaskStatusOpen;

  /// No description provided for @postTaskTrackStatus.
  ///
  /// In en, this message translates to:
  /// **'Track Status →'**
  String get postTaskTrackStatus;

  /// No description provided for @postTaskBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get postTaskBackHome;

  /// No description provided for @myTasksTasksPosted.
  ///
  /// In en, this message translates to:
  /// **'{arg0} tasks posted'**
  String myTasksTasksPosted(Object arg0);

  /// No description provided for @myTasksPostTask.
  ///
  /// In en, this message translates to:
  /// **'Post Task'**
  String get myTasksPostTask;

  /// No description provided for @myTasksNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get myTasksNoTasks;

  /// No description provided for @myTasksPostFirstTask.
  ///
  /// In en, this message translates to:
  /// **'Post your first task to get started!'**
  String get myTasksPostFirstTask;

  /// No description provided for @orderStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get orderStatusTitle;

  /// No description provided for @orderStatusTaskId.
  ///
  /// In en, this message translates to:
  /// **'Task ID: #GIG-{arg0}'**
  String orderStatusTaskId(Object arg0);

  /// No description provided for @orderStatusStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get orderStatusStatusLabel;

  /// No description provided for @orderStatusRunnerAssigned.
  ///
  /// In en, this message translates to:
  /// **'Runner: {arg0}'**
  String orderStatusRunnerAssigned(Object arg0);

  /// No description provided for @orderStatusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get orderStatusAssigned;

  /// No description provided for @orderStatusErrChat.
  ///
  /// In en, this message translates to:
  /// **'Error opening chat: {arg0}'**
  String orderStatusErrChat(Object arg0);

  /// No description provided for @orderStatusRateReview.
  ///
  /// In en, this message translates to:
  /// **'Rate & Review Runner'**
  String get orderStatusRateReview;

  /// No description provided for @orderStatusReviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get orderStatusReviewSubmitted;

  /// No description provided for @runnerFindGigs.
  ///
  /// In en, this message translates to:
  /// **'Find Gigs'**
  String get runnerFindGigs;

  /// No description provided for @runnerNearbyTasks.
  ///
  /// In en, this message translates to:
  /// **'Nearby ({arg0} tasks)'**
  String runnerNearbyTasks(Object arg0);

  /// No description provided for @runnerNoGigs.
  ///
  /// In en, this message translates to:
  /// **'No gigs available'**
  String get runnerNoGigs;

  /// No description provided for @runnerCheckBack.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new tasks'**
  String get runnerCheckBack;

  /// No description provided for @runnerTaskDetail.
  ///
  /// In en, this message translates to:
  /// **'Task Detail'**
  String get runnerTaskDetail;

  /// No description provided for @runnerPostedTime.
  ///
  /// In en, this message translates to:
  /// **'Posted {arg0}'**
  String runnerPostedTime(Object arg0);

  /// No description provided for @runnerBountyOffered.
  ///
  /// In en, this message translates to:
  /// **'Bounty Offered'**
  String get runnerBountyOffered;

  /// No description provided for @runnerAcceptTask.
  ///
  /// In en, this message translates to:
  /// **'Accept Task'**
  String get runnerAcceptTask;

  /// No description provided for @runnerChatCustomer.
  ///
  /// In en, this message translates to:
  /// **'Chat with Customer'**
  String get runnerChatCustomer;

  /// No description provided for @runnerMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark as Complete'**
  String get runnerMarkComplete;

  /// No description provided for @runnerConfirmAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Confirm Acceptance'**
  String get runnerConfirmAcceptance;

  /// No description provided for @runnerAboutToAccept.
  ///
  /// In en, this message translates to:
  /// **'You are about to accept:'**
  String get runnerAboutToAccept;

  /// No description provided for @runnerWarningLocked.
  ///
  /// In en, this message translates to:
  /// **'Once accepted, task is LOCKED.\nIt will be removed from the public feed.'**
  String get runnerWarningLocked;

  /// No description provided for @runnerStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'Task status will change to IN-PROGRESS in the database.'**
  String get runnerStatusInProgress;

  /// No description provided for @runnerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get runnerCancel;

  /// No description provided for @runnerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get runnerConfirm;

  /// No description provided for @runnerRunnerView.
  ///
  /// In en, this message translates to:
  /// **'Runner View'**
  String get runnerRunnerView;

  /// No description provided for @runnerActiveJob.
  ///
  /// In en, this message translates to:
  /// **'Active Job:'**
  String get runnerActiveJob;

  /// No description provided for @runnerInProgress.
  ///
  /// In en, this message translates to:
  /// **'IN-PROGRESS'**
  String get runnerInProgress;

  /// No description provided for @runnerUploadProof.
  ///
  /// In en, this message translates to:
  /// **'Upload Proof (optional)'**
  String get runnerUploadProof;

  /// No description provided for @runnerPhotoUploadSoon.
  ///
  /// In en, this message translates to:
  /// **'Photo upload coming soon!'**
  String get runnerPhotoUploadSoon;

  /// No description provided for @runnerTapUpload.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload photo'**
  String get runnerTapUpload;

  /// No description provided for @runnerNotesRequester.
  ///
  /// In en, this message translates to:
  /// **'Notes for Requester'**
  String get runnerNotesRequester;

  /// No description provided for @runnerNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Any message for the customer...'**
  String get runnerNotesHint;

  /// No description provided for @runnerTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task Completed!'**
  String get runnerTaskCompleted;

  /// No description provided for @runnerRequesterNotified.
  ///
  /// In en, this message translates to:
  /// **'Requester will be notified instantly.'**
  String get runnerRequesterNotified;

  /// No description provided for @runnerDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get runnerDone;

  /// No description provided for @runnerMyJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get runnerMyJobsTitle;

  /// No description provided for @runnerCustomerTasks.
  ///
  /// In en, this message translates to:
  /// **'Customer Tasks'**
  String get runnerCustomerTasks;

  /// No description provided for @runnerMyServices.
  ///
  /// In en, this message translates to:
  /// **'My Services'**
  String get runnerMyServices;

  /// No description provided for @runnerJobsCount.
  ///
  /// In en, this message translates to:
  /// **'{arg0} jobs'**
  String runnerJobsCount(Object arg0);

  /// No description provided for @runnerPostJob.
  ///
  /// In en, this message translates to:
  /// **'Post Job'**
  String get runnerPostJob;

  /// No description provided for @runnerNoJobsYet.
  ///
  /// In en, this message translates to:
  /// **'No jobs yet'**
  String get runnerNoJobsYet;

  /// No description provided for @runnerAcceptFirstGig.
  ///
  /// In en, this message translates to:
  /// **'Accept your first gig to get started!'**
  String get runnerAcceptFirstGig;

  /// No description provided for @runnerServiceTakenDown.
  ///
  /// In en, this message translates to:
  /// **'Service taken down'**
  String get runnerServiceTakenDown;

  /// No description provided for @runnerTakeDown.
  ///
  /// In en, this message translates to:
  /// **'Take Down'**
  String get runnerTakeDown;

  /// No description provided for @profileCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get profileCompleted;

  /// No description provided for @profileRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get profileRating;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileAccount;

  /// No description provided for @profileAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get profileAccountDetails;

  /// No description provided for @profilePaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get profilePaymentMethods;

  /// No description provided for @profilePrivacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get profilePrivacySecurity;

  /// No description provided for @profilePreferences.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get profilePreferences;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileRoleAccess.
  ///
  /// In en, this message translates to:
  /// **'Role Access'**
  String get profileRoleAccess;

  /// No description provided for @profileStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get profileStatistics;

  /// No description provided for @profileTasksPosted.
  ///
  /// In en, this message translates to:
  /// **'Tasks Posted'**
  String get profileTasksPosted;

  /// No description provided for @profileDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get profileDarkMode;

  /// No description provided for @profileChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get profileChooseLanguage;

  /// No description provided for @profileInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends'**
  String get profileInviteFriends;

  /// No description provided for @profileInviteFriendsDesc.
  ///
  /// In en, this message translates to:
  /// **'Get RM5 for every referral!'**
  String get profileInviteFriendsDesc;

  /// No description provided for @profileSupport.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get profileSupport;

  /// No description provided for @profileHelpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get profileHelpCenter;

  /// No description provided for @profileContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get profileContactUs;

  /// No description provided for @profileAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get profileAbout;

  /// No description provided for @profileTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get profileTerms;

  /// No description provided for @profilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profilePrivacy;

  /// No description provided for @profileRateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get profileRateApp;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogout;

  /// No description provided for @profileMadeWithLove.
  ///
  /// In en, this message translates to:
  /// **'Made with pride in Malaysia'**
  String get profileMadeWithLove;

  /// No description provided for @profileLogoutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully logged out!'**
  String get profileLogoutSuccess;

  /// No description provided for @profileLanguageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed to {arg0}'**
  String profileLanguageChanged(Object arg0);

  /// No description provided for @profileNgamRank.
  ///
  /// In en, this message translates to:
  /// **'Ngam Rank (Runner)'**
  String get profileNgamRank;

  /// No description provided for @profileNewRating.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get profileNewRating;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet & Payments'**
  String get walletTitle;

  /// No description provided for @walletSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe up or down to view cards'**
  String get walletSwipeHint;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get walletBalance;

  /// No description provided for @walletNgamPay.
  ///
  /// In en, this message translates to:
  /// **'NGAM PAY'**
  String get walletNgamPay;

  /// No description provided for @walletPlatinum.
  ///
  /// In en, this message translates to:
  /// **'PLATINUM'**
  String get walletPlatinum;

  /// No description provided for @walletPrimary.
  ///
  /// In en, this message translates to:
  /// **'PRIMARY'**
  String get walletPrimary;

  /// No description provided for @walletValid.
  ///
  /// In en, this message translates to:
  /// **'VALID'**
  String get walletValid;

  /// No description provided for @walletThru.
  ///
  /// In en, this message translates to:
  /// **'THRU'**
  String get walletThru;

  /// No description provided for @walletBankAccount.
  ///
  /// In en, this message translates to:
  /// **'BANK ACCOUNT'**
  String get walletBankAccount;

  /// No description provided for @walletDuitnowQr.
  ///
  /// In en, this message translates to:
  /// **'DuitNow QR'**
  String get walletDuitnowQr;

  /// No description provided for @walletShowToReceive.
  ///
  /// In en, this message translates to:
  /// **'Show to receive payment'**
  String get walletShowToReceive;

  /// No description provided for @walletRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get walletRecentTransactions;

  /// No description provided for @walletTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get walletTopUp;

  /// No description provided for @walletWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get walletWithdraw;

  /// No description provided for @walletSetPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set Primary'**
  String get walletSetPrimary;

  /// No description provided for @walletRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get walletRemove;

  /// No description provided for @walletAddPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Add Payment Method'**
  String get walletAddPaymentMethod;

  /// No description provided for @walletCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get walletCancel;

  /// No description provided for @walletAddCreditDebit.
  ///
  /// In en, this message translates to:
  /// **'Add Credit/Debit Card'**
  String get walletAddCreditDebit;

  /// No description provided for @walletSaveCard.
  ///
  /// In en, this message translates to:
  /// **'Save Card'**
  String get walletSaveCard;

  /// No description provided for @walletLinkBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Link Bank Account'**
  String get walletLinkBankAccount;

  /// No description provided for @walletSelectBank.
  ///
  /// In en, this message translates to:
  /// **'SELECT BANK'**
  String get walletSelectBank;

  /// No description provided for @walletLinkAccount.
  ///
  /// In en, this message translates to:
  /// **'Link Account'**
  String get walletLinkAccount;

  /// No description provided for @walletCustomersScanQr.
  ///
  /// In en, this message translates to:
  /// **'Customers will scan your QR to pay you'**
  String get walletCustomersScanQr;

  /// No description provided for @walletYourQrCode.
  ///
  /// In en, this message translates to:
  /// **'YOUR QR CODE'**
  String get walletYourQrCode;

  /// No description provided for @walletTapUploadQr.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload your QR code'**
  String get walletTapUploadQr;

  /// No description provided for @walletFromAnyBank.
  ///
  /// In en, this message translates to:
  /// **'From any bank\'s DuitNow app'**
  String get walletFromAnyBank;

  /// No description provided for @walletUploadQrFirst.
  ///
  /// In en, this message translates to:
  /// **'Please upload your QR code first'**
  String get walletUploadQrFirst;

  /// No description provided for @walletSaveDuitnowQr.
  ///
  /// In en, this message translates to:
  /// **'Save DuitNow QR'**
  String get walletSaveDuitnowQr;

  /// No description provided for @walletTaskCompletedTx.
  ///
  /// In en, this message translates to:
  /// **'Task Completed'**
  String get walletTaskCompletedTx;

  /// No description provided for @walletWithdrawalTx.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get walletWithdrawalTx;

  /// No description provided for @walletTopUpTx.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get walletTopUpTx;

  /// No description provided for @walletPaidForTaskTx.
  ///
  /// In en, this message translates to:
  /// **'Paid for Task'**
  String get walletPaidForTaskTx;

  /// No description provided for @paymentCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get paymentCardNumber;

  /// No description provided for @paymentExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get paymentExpiryDate;

  /// No description provided for @paymentCvv.
  ///
  /// In en, this message translates to:
  /// **'CVV'**
  String get paymentCvv;

  /// No description provided for @paymentCardholderName.
  ///
  /// In en, this message translates to:
  /// **'Cardholder Name'**
  String get paymentCardholderName;

  /// No description provided for @paymentAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get paymentAccountNumber;

  /// No description provided for @chatMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatMessages;

  /// No description provided for @chatSearchConversations.
  ///
  /// In en, this message translates to:
  /// **'Search conversations...'**
  String get chatSearchConversations;

  /// No description provided for @chatRecent.
  ///
  /// In en, this message translates to:
  /// **'RECENT'**
  String get chatRecent;

  /// No description provided for @chatNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get chatNoConversations;

  /// No description provided for @chatNoMatchingConversations.
  ///
  /// In en, this message translates to:
  /// **'No matching conversations.'**
  String get chatNoMatchingConversations;

  /// No description provided for @chatDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete Chat?'**
  String get chatDeleteChat;

  /// No description provided for @chatDeleteChatDesc.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the conversation for both of you.'**
  String get chatDeleteChatDesc;

  /// No description provided for @chatDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDelete;

  /// No description provided for @chatToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatYesterday;

  /// No description provided for @chatCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatCamera;

  /// No description provided for @chatGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chatGallery;

  /// No description provided for @chatFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFile;

  /// No description provided for @chatTaskCard.
  ///
  /// In en, this message translates to:
  /// **'Task Card'**
  String get chatTaskCard;

  /// No description provided for @chatSendQuote.
  ///
  /// In en, this message translates to:
  /// **'Send Quote'**
  String get chatSendQuote;

  /// No description provided for @chatCounterOffer.
  ///
  /// In en, this message translates to:
  /// **'Counter-Offer'**
  String get chatCounterOffer;

  /// No description provided for @chatRequestLocation.
  ///
  /// In en, this message translates to:
  /// **'Request Location'**
  String get chatRequestLocation;

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type message...'**
  String get chatTypeMessage;

  /// No description provided for @chatStartChat.
  ///
  /// In en, this message translates to:
  /// **'Start chat'**
  String get chatStartChat;

  /// No description provided for @chatOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chatOnline;

  /// No description provided for @chatOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chatOffline;

  /// No description provided for @chatTyping.
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get chatTyping;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get chatAttachment;

  /// No description provided for @chatPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatPhoto;

  /// No description provided for @chatVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get chatVideo;

  /// No description provided for @chatDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get chatDocument;

  /// No description provided for @chatLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get chatLocation;

  /// No description provided for @chatQuoteAmount.
  ///
  /// In en, this message translates to:
  /// **'Quote Amount'**
  String get chatQuoteAmount;

  /// No description provided for @chatEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount (RM)'**
  String get chatEnterAmount;

  /// No description provided for @chatSendQuoteBtn.
  ///
  /// In en, this message translates to:
  /// **'Send Quote'**
  String get chatSendQuoteBtn;

  /// No description provided for @chatCounterOfferBtn.
  ///
  /// In en, this message translates to:
  /// **'Send Counter'**
  String get chatCounterOfferBtn;

  /// No description provided for @chatAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get chatAccept;

  /// No description provided for @chatDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get chatDecline;

  /// No description provided for @chatLocationShared.
  ///
  /// In en, this message translates to:
  /// **'Location Shared'**
  String get chatLocationShared;

  /// No description provided for @chatViewMap.
  ///
  /// In en, this message translates to:
  /// **'View Map'**
  String get chatViewMap;

  /// No description provided for @chatTaskInfo.
  ///
  /// In en, this message translates to:
  /// **'Task Info'**
  String get chatTaskInfo;

  /// No description provided for @chatBounty.
  ///
  /// In en, this message translates to:
  /// **'Bounty'**
  String get chatBounty;

  /// No description provided for @chatStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get chatStatus;

  /// No description provided for @chatLocationRequested.
  ///
  /// In en, this message translates to:
  /// **'Location Requested'**
  String get chatLocationRequested;

  /// No description provided for @chatShareLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'Share your location to help calculate travel distance.'**
  String get chatShareLocationDesc;

  /// No description provided for @chatShareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share Location'**
  String get chatShareLocation;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacyTitle;

  /// No description provided for @privacyAppLock.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get privacyAppLock;

  /// No description provided for @privacyAppLockDesc.
  ///
  /// In en, this message translates to:
  /// **'Use biometric or PIN to lock the app'**
  String get privacyAppLockDesc;

  /// No description provided for @privacyHideAppSwitcher.
  ///
  /// In en, this message translates to:
  /// **'Hide in App Switcher'**
  String get privacyHideAppSwitcher;

  /// No description provided for @privacyLocationServices.
  ///
  /// In en, this message translates to:
  /// **'Location Services'**
  String get privacyLocationServices;

  /// No description provided for @privacyTwoFactorAuth.
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication'**
  String get privacyTwoFactorAuth;

  /// No description provided for @privacyEnable2fa.
  ///
  /// In en, this message translates to:
  /// **'Enable 2FA?'**
  String get privacyEnable2fa;

  /// No description provided for @privacyDataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'DATA & PRIVACY'**
  String get privacyDataPrivacy;

  /// No description provided for @privacySystemPermissions.
  ///
  /// In en, this message translates to:
  /// **'System Permissions'**
  String get privacySystemPermissions;

  /// No description provided for @privacyManagePermissions.
  ///
  /// In en, this message translates to:
  /// **'Manage Camera, Gallery, and GPS'**
  String get privacyManagePermissions;

  /// No description provided for @privacyClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear App Cache?'**
  String get privacyClearCache;

  /// No description provided for @privacyFreeStorage.
  ///
  /// In en, this message translates to:
  /// **'Clear temporary files to free up space. Your data is safe.'**
  String get privacyFreeStorage;

  /// No description provided for @privacyActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE SESSIONS'**
  String get privacyActiveSessions;

  /// No description provided for @privacyThisDevice.
  ///
  /// In en, this message translates to:
  /// **'THIS DEVICE'**
  String get privacyThisDevice;

  /// No description provided for @privacyActiveNow.
  ///
  /// In en, this message translates to:
  /// **'Active Now'**
  String get privacyActiveNow;

  /// No description provided for @privacyLogOutAll.
  ///
  /// In en, this message translates to:
  /// **'Log out of all devices'**
  String get privacyLogOutAll;

  /// No description provided for @privacyInstantlySecure.
  ///
  /// In en, this message translates to:
  /// **'Instantly secure your account'**
  String get privacyInstantlySecure;

  /// No description provided for @privacyEnableAppLock.
  ///
  /// In en, this message translates to:
  /// **'Enable App Lock'**
  String get privacyEnableAppLock;

  /// No description provided for @privacyAppLockInfo.
  ///
  /// In en, this message translates to:
  /// **'Your app will be locked with biometric or device PIN every time you switch away.'**
  String get privacyAppLockInfo;

  /// No description provided for @privacyNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get privacyNotNow;

  /// No description provided for @privacyEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get privacyEnable;

  /// No description provided for @privacyAuthEnableLock.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to enable App Lock'**
  String get privacyAuthEnableLock;

  /// No description provided for @privacyAuthDisableLock.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to disable App Lock'**
  String get privacyAuthDisableLock;

  /// No description provided for @privacyEnable2faDesc.
  ///
  /// In en, this message translates to:
  /// **'Add an extra layer of security to your account. You will need to verify your identity when logging in from a new device.'**
  String get privacyEnable2faDesc;

  /// No description provided for @privacyDisable2fa.
  ///
  /// In en, this message translates to:
  /// **'Disable Two-Factor Authentication'**
  String get privacyDisable2fa;

  /// No description provided for @privacyDisable2faDesc.
  ///
  /// In en, this message translates to:
  /// **'Your account will only rely on your password for security.'**
  String get privacyDisable2faDesc;

  /// No description provided for @privacyCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get privacyCacheCleared;

  /// No description provided for @privacyLogOutAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure Account?'**
  String get privacyLogOutAllTitle;

  /// No description provided for @privacyLogOutAllDesc.
  ///
  /// In en, this message translates to:
  /// **'This will instantly log you out of all other devices. You will stay logged in on this phone.'**
  String get privacyLogOutAllDesc;

  /// No description provided for @privacyLogOutAllBtn.
  ///
  /// In en, this message translates to:
  /// **'Log Out All'**
  String get privacyLogOutAllBtn;

  /// No description provided for @privacyActiveSessionsInfo.
  ///
  /// In en, this message translates to:
  /// **'Device Details'**
  String get privacyActiveSessionsInfo;

  /// No description provided for @privacyLastLogin.
  ///
  /// In en, this message translates to:
  /// **'Last Login'**
  String get privacyLastLogin;

  /// No description provided for @privacyDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get privacyDevice;

  /// No description provided for @privacyIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get privacyIpAddress;

  /// No description provided for @supportDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get supportDone;

  /// No description provided for @supportHelpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get supportHelpCenter;

  /// No description provided for @supportGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi\nHow can we help?'**
  String get supportGreeting;

  /// No description provided for @supportSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search questions...'**
  String get supportSearchHint;

  /// No description provided for @supportFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get supportFaqTitle;

  /// No description provided for @supportNoResults.
  ///
  /// In en, this message translates to:
  /// **'No questions found for \"{arg0}\"'**
  String supportNoResults(Object arg0);

  /// No description provided for @supportContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get supportContactUs;

  /// No description provided for @supportContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Our team is ready to help you.'**
  String get supportContactSubtitle;

  /// No description provided for @supportChatSupport.
  ///
  /// In en, this message translates to:
  /// **'Chat Support'**
  String get supportChatSupport;

  /// No description provided for @supportChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re here to help.'**
  String get supportChatSubtitle;

  /// No description provided for @supportStartChat.
  ///
  /// In en, this message translates to:
  /// **'Start Chat'**
  String get supportStartChat;

  /// No description provided for @supportEmailUs.
  ///
  /// In en, this message translates to:
  /// **'Email Us'**
  String get supportEmailUs;

  /// No description provided for @supportEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send an email anytime.'**
  String get supportEmailSubtitle;

  /// No description provided for @supportCallUs.
  ///
  /// In en, this message translates to:
  /// **'Call Us'**
  String get supportCallUs;

  /// No description provided for @supportCallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mon-Fri, 9am–5pm.'**
  String get supportCallSubtitle;

  /// No description provided for @supportFollowUs.
  ///
  /// In en, this message translates to:
  /// **'FOLLOW US'**
  String get supportFollowUs;

  /// No description provided for @supportFaq1Q.
  ///
  /// In en, this message translates to:
  /// **'How do I post a task?'**
  String get supportFaq1Q;

  /// No description provided for @supportFaq1A.
  ///
  /// In en, this message translates to:
  /// **'Tap the \"+\" button below, fill in the task details like category, location, and price offer. Then submit and wait for a runner to pick up your task.'**
  String get supportFaq1A;

  /// No description provided for @supportFaq2Q.
  ///
  /// In en, this message translates to:
  /// **'How do I become a Runner?'**
  String get supportFaq2Q;

  /// No description provided for @supportFaq2A.
  ///
  /// In en, this message translates to:
  /// **'Switch your role to \"Runner\" from your profile. You can then find available tasks in the feed and accept suitable ones.'**
  String get supportFaq2A;

  /// No description provided for @supportFaq3Q.
  ///
  /// In en, this message translates to:
  /// **'How does payment work?'**
  String get supportFaq3Q;

  /// No description provided for @supportFaq3A.
  ///
  /// In en, this message translates to:
  /// **'Payment is made directly between the Customer and Runner after task completion. We recommend using DuitNow or bank transfer.'**
  String get supportFaq3A;

  /// No description provided for @supportFaq4Q.
  ///
  /// In en, this message translates to:
  /// **'Can I cancel a task?'**
  String get supportFaq4Q;

  /// No description provided for @supportFaq4A.
  ///
  /// In en, this message translates to:
  /// **'Yes, you can cancel from the \"My Tasks\" page as long as no runner has accepted it yet.'**
  String get supportFaq4A;

  /// No description provided for @supportFaq5Q.
  ///
  /// In en, this message translates to:
  /// **'What if the runner doesn\'t show up?'**
  String get supportFaq5Q;

  /// No description provided for @supportFaq5A.
  ///
  /// In en, this message translates to:
  /// **'Contact us through \"Contact Us\" and we will help resolve the issue within 24 hours.'**
  String get supportFaq5A;

  /// No description provided for @supportFaq6Q.
  ///
  /// In en, this message translates to:
  /// **'Can Ngam runners be trusted?'**
  String get supportFaq6Q;

  /// No description provided for @supportFaq6A.
  ///
  /// In en, this message translates to:
  /// **'All our runners must go through a strict identity verification process before their accounts are activated for your safety.'**
  String get supportFaq6A;

  /// No description provided for @supportFaq7Q.
  ///
  /// In en, this message translates to:
  /// **'Can I communicate with the runner?'**
  String get supportFaq7Q;

  /// No description provided for @supportFaq7A.
  ///
  /// In en, this message translates to:
  /// **'Yes, you can use the in-app chat to communicate with the runner once they accept your task.'**
  String get supportFaq7A;

  /// No description provided for @supportFaq8Q.
  ///
  /// In en, this message translates to:
  /// **'What if the item price changes?'**
  String get supportFaq8Q;

  /// No description provided for @supportFaq8A.
  ///
  /// In en, this message translates to:
  /// **'You can discuss with the runner through chat. The runner will inform you of the actual price with a receipt for verification.'**
  String get supportFaq8A;

  /// No description provided for @supportFaq9Q.
  ///
  /// In en, this message translates to:
  /// **'How do I give a rating?'**
  String get supportFaq9Q;

  /// No description provided for @supportFaq9A.
  ///
  /// In en, this message translates to:
  /// **'After the task is marked as complete, a pop-up will appear allowing you to rate and review the runner.'**
  String get supportFaq9A;

  /// No description provided for @supportFaq10Q.
  ///
  /// In en, this message translates to:
  /// **'Is my location information safe?'**
  String get supportFaq10Q;

  /// No description provided for @supportFaq10A.
  ///
  /// In en, this message translates to:
  /// **'Yes, your personal and exact location information will only be shared with the runner who has accepted your task.'**
  String get supportFaq10A;

  /// No description provided for @supportFaq11Q.
  ///
  /// In en, this message translates to:
  /// **'How long does it take to complete a task?'**
  String get supportFaq11Q;

  /// No description provided for @supportFaq11A.
  ///
  /// In en, this message translates to:
  /// **'It depends on the type of task and distance. You can view the estimated time or ask the runner directly.'**
  String get supportFaq11A;

  /// No description provided for @supportFaq12Q.
  ///
  /// In en, this message translates to:
  /// **'What if my item is damaged?'**
  String get supportFaq12Q;

  /// No description provided for @supportFaq12A.
  ///
  /// In en, this message translates to:
  /// **'Please take a photo of the damage and contact our customer support within 24 hours for compensation assistance.'**
  String get supportFaq12A;

  /// No description provided for @supportFaq13Q.
  ///
  /// In en, this message translates to:
  /// **'Can I tip the runner?'**
  String get supportFaq13Q;

  /// No description provided for @supportFaq13A.
  ///
  /// In en, this message translates to:
  /// **'Of course! You can give a cash tip directly to the runner or include the tip amount in your original task price offer.'**
  String get supportFaq13A;

  /// No description provided for @supportFaq14Q.
  ///
  /// In en, this message translates to:
  /// **'Is there a weight limit for items?'**
  String get supportFaq14Q;

  /// No description provided for @supportFaq14A.
  ///
  /// In en, this message translates to:
  /// **'We recommend a maximum weight of 15kg for motorcycle delivery tasks. For larger items, please state clearly in the description.'**
  String get supportFaq14A;

  /// No description provided for @supportFaq15Q.
  ///
  /// In en, this message translates to:
  /// **'Can I change location after runner accepts?'**
  String get supportFaq15Q;

  /// No description provided for @supportFaq15A.
  ///
  /// In en, this message translates to:
  /// **'Location changes after task acceptance are subject to runner agreement. Additional costs may apply.'**
  String get supportFaq15A;

  /// No description provided for @aboutLikeNgam.
  ///
  /// In en, this message translates to:
  /// **'Like Ngam?'**
  String get aboutLikeNgam;

  /// No description provided for @aboutRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Give us stars to help us grow.'**
  String get aboutRateSubtitle;

  /// No description provided for @aboutFeedbackHint.
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts about Ngam...'**
  String get aboutFeedbackHint;

  /// No description provided for @aboutSubmitFeedback.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get aboutSubmitFeedback;

  /// No description provided for @aboutThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get aboutThankYou;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get accountTitle;

  /// No description provided for @accountPublicProfile.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC PROFILE'**
  String get accountPublicProfile;

  /// No description provided for @accountShippingDetails.
  ///
  /// In en, this message translates to:
  /// **'SHIPPING DETAILS'**
  String get accountShippingDetails;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'SECURITY'**
  String get accountSecurity;

  /// No description provided for @accountSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get accountSaveChanges;

  /// No description provided for @accountFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get accountFullName;

  /// No description provided for @accountEmailReadonly.
  ///
  /// In en, this message translates to:
  /// **'Email Address (Read Only)'**
  String get accountEmailReadonly;

  /// No description provided for @accountPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get accountPhone;

  /// No description provided for @accountDob.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get accountDob;

  /// No description provided for @accountAddress.
  ///
  /// In en, this message translates to:
  /// **'Primary Delivery Address'**
  String get accountAddress;

  /// No description provided for @accountCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get accountCurrentPassword;

  /// No description provided for @accountNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get accountNewPassword;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate & Review'**
  String get reviewTitle;

  /// No description provided for @reviewHowWas.
  ///
  /// In en, this message translates to:
  /// **'How was your experience?'**
  String get reviewHowWas;

  /// No description provided for @reviewTapToRate.
  ///
  /// In en, this message translates to:
  /// **'Tap a star to rate'**
  String get reviewTapToRate;

  /// No description provided for @reviewLeaveComment.
  ///
  /// In en, this message translates to:
  /// **'Leave a comment (optional)'**
  String get reviewLeaveComment;

  /// No description provided for @reviewCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your experience...'**
  String get reviewCommentHint;

  /// No description provided for @reviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get reviewSubmit;

  /// No description provided for @reviewSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get reviewSubmitting;

  /// No description provided for @reviewSelectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select a rating'**
  String get reviewSelectRating;

  /// No description provided for @reviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit review'**
  String get reviewFailed;

  /// No description provided for @verificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Become a Runner'**
  String get verificationTitle;

  /// No description provided for @verificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete verification to start earning'**
  String get verificationSubtitle;

  /// No description provided for @verificationFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Legal Name'**
  String get verificationFullName;

  /// No description provided for @verificationIcNumber.
  ///
  /// In en, this message translates to:
  /// **'IC Number'**
  String get verificationIcNumber;

  /// No description provided for @verificationVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get verificationVehicleType;

  /// No description provided for @verificationUploadIc.
  ///
  /// In en, this message translates to:
  /// **'Upload IC Photo'**
  String get verificationUploadIc;

  /// No description provided for @verificationUploadSelfie.
  ///
  /// In en, this message translates to:
  /// **'Upload Selfie with IC'**
  String get verificationUploadSelfie;

  /// No description provided for @verificationSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Verification'**
  String get verificationSubmit;

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification Pending'**
  String get verificationPending;

  /// No description provided for @verificationApproved.
  ///
  /// In en, this message translates to:
  /// **'Verified Runner'**
  String get verificationApproved;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats & Earnings'**
  String get statsTitle;

  /// No description provided for @statsTotalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get statsTotalEarnings;

  /// No description provided for @statsCompletedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed Tasks'**
  String get statsCompletedTasks;

  /// No description provided for @statsAvgRating.
  ///
  /// In en, this message translates to:
  /// **'Average Rating'**
  String get statsAvgRating;

  /// No description provided for @statsWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get statsWeekly;

  /// No description provided for @statsMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get statsMonthly;

  /// No description provided for @statsAllTime.
  ///
  /// In en, this message translates to:
  /// **'All-Time'**
  String get statsAllTime;

  /// No description provided for @statsEarningsChart.
  ///
  /// In en, this message translates to:
  /// **'Earnings Chart'**
  String get statsEarningsChart;

  /// No description provided for @statsNoEarnings.
  ///
  /// In en, this message translates to:
  /// **'No earnings data.'**
  String get statsNoEarnings;

  /// No description provided for @statsNoTaskData.
  ///
  /// In en, this message translates to:
  /// **'No task data.'**
  String get statsNoTaskData;

  /// No description provided for @statsTasksByStatus.
  ///
  /// In en, this message translates to:
  /// **'Tasks by Status'**
  String get statsTasksByStatus;

  /// No description provided for @statsEarningsByCategory.
  ///
  /// In en, this message translates to:
  /// **'Earnings by Category'**
  String get statsEarningsByCategory;

  /// No description provided for @statsRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get statsRecentActivity;

  /// No description provided for @rankBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze Runner'**
  String get rankBronze;

  /// No description provided for @rankSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver Runner'**
  String get rankSilver;

  /// No description provided for @rankGold.
  ///
  /// In en, this message translates to:
  /// **'Gold Runner'**
  String get rankGold;

  /// No description provided for @rankPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum Runner'**
  String get rankPlatinum;

  /// No description provided for @rankXpToNext.
  ///
  /// In en, this message translates to:
  /// **'{arg0} XP to next rank'**
  String rankXpToNext(Object arg0);

  /// No description provided for @rankTasksProgress.
  ///
  /// In en, this message translates to:
  /// **'{arg0} / {arg1} Tasks'**
  String rankTasksProgress(Object arg0, Object arg1);

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get commonNoData;

  /// No description provided for @commonLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get commonLogOut;

  /// No description provided for @taskDetailNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate to Location'**
  String get taskDetailNavigate;

  /// No description provided for @taskDetailManageService.
  ///
  /// In en, this message translates to:
  /// **'Manage Service'**
  String get taskDetailManageService;

  /// No description provided for @taskDetailAdjustBounty.
  ///
  /// In en, this message translates to:
  /// **'Adjust Bounty'**
  String get taskDetailAdjustBounty;

  /// No description provided for @taskDetailDeleteService.
  ///
  /// In en, this message translates to:
  /// **'Delete Service'**
  String get taskDetailDeleteService;

  /// No description provided for @taskDetailDeleteServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Service?'**
  String get taskDetailDeleteServiceTitle;

  /// No description provided for @taskDetailDeleteServiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete this service?'**
  String get taskDetailDeleteServiceDesc;

  /// No description provided for @taskDetailCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get taskDetailCancel;

  /// No description provided for @taskDetailDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get taskDetailDelete;

  /// No description provided for @taskDetailSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get taskDetailSave;

  /// No description provided for @taskDetailErrorChat.
  ///
  /// In en, this message translates to:
  /// **'Error starting chat: {arg0}'**
  String taskDetailErrorChat(Object arg0);

  /// No description provided for @navFeed.
  ///
  /// In en, this message translates to:
  /// **'Ngam Feed'**
  String get navFeed;

  /// No description provided for @navInbox.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navInbox;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @expandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand Sidebar'**
  String get expandSidebar;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse Sidebar'**
  String get collapseSidebar;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @switchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switch Language'**
  String get switchLanguage;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreeting(Object name);

  /// No description provided for @homeSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search services, stores, items...'**
  String get homeSearchPlaceholder;

  /// No description provided for @homeCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location: {location}'**
  String homeCurrentLocation(Object location);

  /// No description provided for @homeLocationDetected.
  ///
  /// In en, this message translates to:
  /// **'Location detected: {location}'**
  String homeLocationDetected(Object location);

  /// No description provided for @homeNearbyStores.
  ///
  /// In en, this message translates to:
  /// **'Nearby Stores'**
  String get homeNearbyStores;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get homeSeeAll;

  /// No description provided for @homePopularOffers.
  ///
  /// In en, this message translates to:
  /// **'Hot Deals'**
  String get homePopularOffers;

  /// No description provided for @homeTrendingPort.
  ///
  /// In en, this message translates to:
  /// **'Trending Spots'**
  String get homeTrendingPort;

  /// No description provided for @homeQuickCategories.
  ///
  /// In en, this message translates to:
  /// **'Quick Categories'**
  String get homeQuickCategories;

  /// No description provided for @homeLiveQueue.
  ///
  /// In en, this message translates to:
  /// **'My Queue'**
  String get homeLiveQueue;

  /// No description provided for @homeStampsCard.
  ///
  /// In en, this message translates to:
  /// **'Stamp Rewards'**
  String get homeStampsCard;

  /// No description provided for @homeFlashPromo.
  ///
  /// In en, this message translates to:
  /// **'Flash RM10'**
  String get homeFlashPromo;

  /// No description provided for @homeFlashDesc.
  ///
  /// In en, this message translates to:
  /// **'Haircut Promo'**
  String get homeFlashDesc;

  /// No description provided for @homeViralCafe.
  ///
  /// In en, this message translates to:
  /// **'Viral Spot'**
  String get homeViralCafe;

  /// No description provided for @homeViralDesc.
  ///
  /// In en, this message translates to:
  /// **'Coffee & Bakery'**
  String get homeViralDesc;

  /// No description provided for @homeDetailing.
  ///
  /// In en, this message translates to:
  /// **'Nano Detailing'**
  String get homeDetailing;

  /// No description provided for @homeDetailingDesc.
  ///
  /// In en, this message translates to:
  /// **'30% Discount'**
  String get homeDetailingDesc;

  /// No description provided for @homeDailyCoupon.
  ///
  /// In en, this message translates to:
  /// **'Daily Promo'**
  String get homeDailyCoupon;

  /// No description provided for @homeDailyCouponDesc.
  ///
  /// In en, this message translates to:
  /// **'RM5 Coupon'**
  String get homeDailyCouponDesc;

  /// No description provided for @homeSpaRelax.
  ///
  /// In en, this message translates to:
  /// **'Spa & Relax'**
  String get homeSpaRelax;

  /// No description provided for @homeSpaRelaxDesc.
  ///
  /// In en, this message translates to:
  /// **'Afternoon Slot'**
  String get homeSpaRelaxDesc;

  /// No description provided for @catBarber.
  ///
  /// In en, this message translates to:
  /// **'Haircut'**
  String get catBarber;

  /// No description provided for @catCarwash.
  ///
  /// In en, this message translates to:
  /// **'Car Wash'**
  String get catCarwash;

  /// No description provided for @catCafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe & Chill'**
  String get catCafe;

  /// No description provided for @catWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get catWorkshop;

  /// No description provided for @catSalon.
  ///
  /// In en, this message translates to:
  /// **'Salon & Spa'**
  String get catSalon;

  /// No description provided for @catHealth.
  ///
  /// In en, this message translates to:
  /// **'Clinic & Health'**
  String get catHealth;

  /// No description provided for @feedForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get feedForYou;

  /// No description provided for @feedFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get feedFollowing;

  /// No description provided for @feedBookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get feedBookNow;

  /// No description provided for @feedVisitStore.
  ///
  /// In en, this message translates to:
  /// **'Visit Store'**
  String get feedVisitStore;

  /// No description provided for @storeCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get storeCatalog;

  /// No description provided for @storeMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get storeMenu;

  /// No description provided for @storeReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get storeReviews;

  /// No description provided for @storeInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get storeInfo;

  /// No description provided for @storeAllItems.
  ///
  /// In en, this message translates to:
  /// **'All Items'**
  String get storeAllItems;

  /// No description provided for @storeBookQueue.
  ///
  /// In en, this message translates to:
  /// **'Book / Queue'**
  String get storeBookQueue;

  /// No description provided for @bookingCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get bookingCancelTitle;

  /// No description provided for @bookingDisputeTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Dispute'**
  String get bookingDisputeTitle;

  /// No description provided for @bookingRefundNote.
  ///
  /// In en, this message translates to:
  /// **'Refund will be credited to your Ngam Wallet.'**
  String get bookingRefundNote;

  /// No description provided for @profileStampCards.
  ///
  /// In en, this message translates to:
  /// **'Reward Stamp Cards'**
  String get profileStampCards;

  /// No description provided for @profileLiveQueue.
  ///
  /// In en, this message translates to:
  /// **'Walk-In Queue Ticket (Live Queue)'**
  String get profileLiveQueue;

  /// No description provided for @profileCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for App Updates'**
  String get profileCheckUpdates;

  /// No description provided for @profileGuestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get profileGuestUser;

  /// No description provided for @profileGuestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your bookings and rewards.'**
  String get profileGuestSubtitle;

  /// No description provided for @profileLoginRegister.
  ///
  /// In en, this message translates to:
  /// **'Sign In / Register'**
  String get profileLoginRegister;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get profileSaved;

  /// No description provided for @profileSavedShops.
  ///
  /// In en, this message translates to:
  /// **'Saved Shops'**
  String get profileSavedShops;

  /// No description provided for @profileSavedPosts.
  ///
  /// In en, this message translates to:
  /// **'Saved Posts'**
  String get profileSavedPosts;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ms'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ms':
      return AppLocalizationsMs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
