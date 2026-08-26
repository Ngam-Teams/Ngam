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

  /// Shows 'Today' along with the day of the week
  ///
  /// In en, this message translates to:
  /// **'Today ({day})'**
  String todayDay(String day);

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
  /// **'Rezrv Now'**
  String get rezrvNow;

  /// Carousel title shown when search results are found
  ///
  /// In en, this message translates to:
  /// **'Results for \'{query}\''**
  String resultsFor(String query);

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

  /// Greeting on the home screen
  ///
  /// In en, this message translates to:
  /// **'Hi, {firstName}'**
  String hiUser(String firstName);

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
  /// **'My Barbr'**
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
  /// **'No past or cancelled reservations.'**
  String get noPastReservations;

  /// No description provided for @noUpcomingReservations.
  ///
  /// In en, this message translates to:
  /// **'No upcoming reservations yet.\nBook a service to see it here!'**
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
  String bkMins(int time);

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
  String bkConfirmPay(String price);

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
  /// **'My Barbr'**
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
  String searchAll(String category);

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
  String searchMatchProvides(String service);

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
  /// **'View Profile'**
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
  String ticketCountdownStartsIn(String duration);

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
  /// **'Made with ❤️ in Malaysia'**
  String get madeIn;
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
