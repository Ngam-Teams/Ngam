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
  String todayDay(Object day) {
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
  String get rezrvNow => 'Book Now';

  @override
  String resultsFor(Object query) {
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
  String hiUser(Object firstName) {
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
  String get myBarbrTitle => 'My Bookings';

  @override
  String get tabUpcoming => 'Upcoming';

  @override
  String get tabHistory => 'History';

  @override
  String get noPastReservations => 'No past or cancelled bookings.';

  @override
  String get noUpcomingReservations =>
      'No upcoming bookings yet.\nBook a service to see it here!';

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
  String bkMins(Object time) {
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
  String bkConfirmPay(Object price) {
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
  String get navMyBarbr => 'Bookings';

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
  String searchAll(Object category) {
    return 'All $category';
  }

  @override
  String get searchHeadersCategories => 'CATEGORIES';

  @override
  String get searchHeadersShops => 'SHOPS & SERVICES';

  @override
  String searchMatchProvides(Object service) {
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
  String get btnViewProfile => 'View Store';

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
  String ticketCountdownStartsIn(Object duration) {
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
  String get madeIn => 'Made with pride in Malaysia';

  @override
  String get bookNow => 'Book Now';

  @override
  String get authLogout => 'Log Out';

  @override
  String get authWelcomeBack => 'Welcome Back!';

  @override
  String get authWelcomeSubtitle => 'Sign in to continue using Ngam';

  @override
  String get authEmail => 'Email Address';

  @override
  String get authPassword => 'Password';

  @override
  String get authLogin => 'Sign In';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authRegisterHere => 'Register here';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authRegisterSubtitle => 'Join Ngam community today';

  @override
  String get authFullName => 'Full Legal Name';

  @override
  String get authPhone => 'Phone Number';

  @override
  String get authRoleSelect => 'I want to:';

  @override
  String get authRoleCustomer => 'Post Tasks';

  @override
  String get authRoleRunner => 'Earn as Runner';

  @override
  String get authRegister => 'Sign Up';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authLoginHere => 'Sign in here';

  @override
  String get authPleaseEnterEmail => 'Please enter your email';

  @override
  String get authValidEmail => 'Please enter a valid email';

  @override
  String get authPleaseEnterPassword => 'Please enter your password';

  @override
  String get authPleaseEnterName => 'Please enter your name';

  @override
  String get authPleaseEnterPhone => 'Please enter your phone number';

  @override
  String get authPasswordMinLength => 'Password must be at least 6 characters';

  @override
  String get authConfirmPassword => 'Confirm Password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get authForgotPassword => 'Forgot Password?';

  @override
  String get authOrContinueWith => 'Or continue with';

  @override
  String get authGoogleSignin => 'Google';

  @override
  String get authAppleSignin => 'Apple';

  @override
  String get navMyTasks => 'My Tasks';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profile';

  @override
  String customerGreeting(Object arg0) {
    return 'Hi, $arg0';
  }

  @override
  String get customerWhatDoYouNeed => 'What do you need done today?';

  @override
  String get customerSearchHint => 'Search for tasks or services...';

  @override
  String get customerQuickCategories => 'Quick Categories';

  @override
  String get customerNearbyRunners => 'Nearby Runners Ready';

  @override
  String get customerRecentTasks => 'Your Recent Tasks';

  @override
  String get customerViewAll => 'View All';

  @override
  String get customerPostNewTask => 'Post a New Task';

  @override
  String get customerTaskTitle => 'Task Title';

  @override
  String get customerTaskDesc => 'Describe what you need done...';

  @override
  String get customerBounty => 'Bounty Amount (RM)';

  @override
  String get customerLocation => 'Location';

  @override
  String get customerPostTask => 'Post Task Now';

  @override
  String customerAvailableServices(Object arg0) {
    return 'Available Services ($arg0)';
  }

  @override
  String get customerNoServices => 'No services available right now.';

  @override
  String get customerRunnersWillPost => 'Runners will post new services soon.';

  @override
  String get customerServiceOrdered => 'Service ordered successfully!';

  @override
  String get customerOrderService => 'Order Service';

  @override
  String get postTaskTitleRunner => 'Post a Service';

  @override
  String get postTaskTitleCustomer => 'Post New Task';

  @override
  String get postTaskServiceTitleLabel => 'Service Title';

  @override
  String get postTaskServiceTitleHint => 'e.g., I will print 10 pages';

  @override
  String get postTaskTaskTitleHint => 'e.g., Print assignment 10 pages';

  @override
  String get postTaskErrTitle => 'Please enter a title';

  @override
  String get postTaskServiceDescLabel => 'Service Description';

  @override
  String get postTaskTaskDescLabel => 'Task Description';

  @override
  String get postTaskServiceDescHint => 'Describe what you can do...';

  @override
  String get postTaskErrDesc => 'Please enter a description';

  @override
  String get postTaskCategory => 'Category';

  @override
  String get postTaskLocationLabel => 'Location / Drop-off Name';

  @override
  String get postTaskLocationHint => 'e.g., Block C, Campus Library';

  @override
  String get postTaskErrLocation => 'Please enter a location name';

  @override
  String get postTaskPinLocation => 'Pin Exact Location';

  @override
  String get postTaskPriceRunner => 'Price (RM)';

  @override
  String postTaskMinRm(Object arg0) {
    return 'Min: RM $arg0';
  }

  @override
  String get postTaskErrBounty => 'Please enter a bounty amount';

  @override
  String get postTaskErrValidNumber => 'Please enter a valid number';

  @override
  String postTaskMinBountyInfo(Object arg0, Object arg1) {
    return 'Minimum bounty for $arg0: RM $arg1';
  }

  @override
  String get postTaskPosting => 'Posting...';

  @override
  String get postTaskSubmitService => 'Submit Service →';

  @override
  String get postTaskSubmitTask => 'Submit Task →';

  @override
  String get postTaskServiceVisible => 'Service will be visible to customers';

  @override
  String get postTaskTaskVisible =>
      'Task will appear in the live feed once submitted';

  @override
  String postTaskLocationPinned(Object arg0, Object arg1) {
    return 'Location pinned: $arg0, $arg1';
  }

  @override
  String get postTaskSubmittedTitle => 'Task Submitted!';

  @override
  String get postTaskTaskLive => 'Task is now LIVE!';

  @override
  String get postTaskRunnersCanSee =>
      'Runners nearby can see your task in the feed';

  @override
  String get postTaskStatusOpen => 'Status: OPEN';

  @override
  String get postTaskTrackStatus => 'Track Status →';

  @override
  String get postTaskBackHome => 'Back to Home';

  @override
  String myTasksTasksPosted(Object arg0) {
    return '$arg0 tasks posted';
  }

  @override
  String get myTasksPostTask => 'Post Task';

  @override
  String get myTasksNoTasks => 'No tasks yet';

  @override
  String get myTasksPostFirstTask => 'Post your first task to get started!';

  @override
  String get orderStatusTitle => 'Task Details';

  @override
  String orderStatusTaskId(Object arg0) {
    return 'Task ID: #GIG-$arg0';
  }

  @override
  String get orderStatusStatusLabel => 'Status';

  @override
  String orderStatusRunnerAssigned(Object arg0) {
    return 'Runner: $arg0';
  }

  @override
  String get orderStatusAssigned => 'Assigned';

  @override
  String orderStatusErrChat(Object arg0) {
    return 'Error opening chat: $arg0';
  }

  @override
  String get orderStatusRateReview => 'Rate & Review Runner';

  @override
  String get orderStatusReviewSubmitted => 'Review submitted';

  @override
  String get runnerFindGigs => 'Find Gigs';

  @override
  String runnerNearbyTasks(Object arg0) {
    return 'Nearby ($arg0 tasks)';
  }

  @override
  String get runnerNoGigs => 'No gigs available';

  @override
  String get runnerCheckBack => 'Check back later for new tasks';

  @override
  String get runnerTaskDetail => 'Task Detail';

  @override
  String runnerPostedTime(Object arg0) {
    return 'Posted $arg0';
  }

  @override
  String get runnerBountyOffered => 'Bounty Offered';

  @override
  String get runnerAcceptTask => 'Accept Task';

  @override
  String get runnerChatCustomer => 'Chat with Customer';

  @override
  String get runnerMarkComplete => 'Mark as Complete';

  @override
  String get runnerConfirmAcceptance => 'Confirm Acceptance';

  @override
  String get runnerAboutToAccept => 'You are about to accept:';

  @override
  String get runnerWarningLocked =>
      'Once accepted, task is LOCKED.\nIt will be removed from the public feed.';

  @override
  String get runnerStatusInProgress =>
      'Task status will change to IN-PROGRESS in the database.';

  @override
  String get runnerCancel => 'Cancel';

  @override
  String get runnerConfirm => 'Confirm';

  @override
  String get runnerRunnerView => 'Runner View';

  @override
  String get runnerActiveJob => 'Active Job:';

  @override
  String get runnerInProgress => 'IN-PROGRESS';

  @override
  String get runnerUploadProof => 'Upload Proof (optional)';

  @override
  String get runnerPhotoUploadSoon => 'Photo upload coming soon!';

  @override
  String get runnerTapUpload => 'Tap to upload photo';

  @override
  String get runnerNotesRequester => 'Notes for Requester';

  @override
  String get runnerNotesHint => 'Any message for the customer...';

  @override
  String get runnerTaskCompleted => 'Task Completed!';

  @override
  String get runnerRequesterNotified => 'Requester will be notified instantly.';

  @override
  String get runnerDone => 'Done';

  @override
  String get runnerMyJobsTitle => 'Jobs';

  @override
  String get runnerCustomerTasks => 'Customer Tasks';

  @override
  String get runnerMyServices => 'My Services';

  @override
  String runnerJobsCount(Object arg0) {
    return '$arg0 jobs';
  }

  @override
  String get runnerPostJob => 'Post Job';

  @override
  String get runnerNoJobsYet => 'No jobs yet';

  @override
  String get runnerAcceptFirstGig => 'Accept your first gig to get started!';

  @override
  String get runnerServiceTakenDown => 'Service taken down';

  @override
  String get runnerTakeDown => 'Take Down';

  @override
  String get profileCompleted => 'Completed';

  @override
  String get profileRating => 'Rating';

  @override
  String get profileAccount => 'ACCOUNT';

  @override
  String get profileAccountDetails => 'Account Details';

  @override
  String get profilePaymentMethods => 'Payment Methods';

  @override
  String get profilePrivacySecurity => 'Privacy & Security';

  @override
  String get profilePreferences => 'PREFERENCES';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileRoleAccess => 'Role Access';

  @override
  String get profileStatistics => 'Statistics';

  @override
  String get profileTasksPosted => 'Tasks Posted';

  @override
  String get profileDarkMode => 'Dark Mode';

  @override
  String get profileChooseLanguage => 'Choose Language';

  @override
  String get profileInviteFriends => 'Invite Friends';

  @override
  String get profileInviteFriendsDesc => 'Get RM5 for every referral!';

  @override
  String get profileSupport => 'SUPPORT';

  @override
  String get profileHelpCenter => 'Help Center';

  @override
  String get profileContactUs => 'Contact Us';

  @override
  String get profileAbout => 'ABOUT';

  @override
  String get profileTerms => 'Terms of Service';

  @override
  String get profilePrivacy => 'Privacy Policy';

  @override
  String get profileRateApp => 'Rate App';

  @override
  String get profileLogout => 'Log Out';

  @override
  String get profileMadeWithLove => 'Made with pride in Malaysia';

  @override
  String get profileLogoutSuccess => 'Successfully logged out!';

  @override
  String profileLanguageChanged(Object arg0) {
    return 'Language changed to $arg0';
  }

  @override
  String get profileNgamRank => 'Ngam Rank (Runner)';

  @override
  String get profileNewRating => 'New';

  @override
  String get walletTitle => 'Wallet & Payments';

  @override
  String get walletSwipeHint => 'Swipe up or down to view cards';

  @override
  String get walletBalance => 'Balance';

  @override
  String get walletNgamPay => 'NGAM PAY';

  @override
  String get walletPlatinum => 'PLATINUM';

  @override
  String get walletPrimary => 'PRIMARY';

  @override
  String get walletValid => 'VALID';

  @override
  String get walletThru => 'THRU';

  @override
  String get walletBankAccount => 'BANK ACCOUNT';

  @override
  String get walletDuitnowQr => 'DuitNow QR';

  @override
  String get walletShowToReceive => 'Show to receive payment';

  @override
  String get walletRecentTransactions => 'Recent Transactions';

  @override
  String get walletTopUp => 'Top Up';

  @override
  String get walletWithdraw => 'Withdraw';

  @override
  String get walletSetPrimary => 'Set Primary';

  @override
  String get walletRemove => 'Remove';

  @override
  String get walletAddPaymentMethod => 'Add Payment Method';

  @override
  String get walletCancel => 'Cancel';

  @override
  String get walletAddCreditDebit => 'Add Credit/Debit Card';

  @override
  String get walletSaveCard => 'Save Card';

  @override
  String get walletLinkBankAccount => 'Link Bank Account';

  @override
  String get walletSelectBank => 'SELECT BANK';

  @override
  String get walletLinkAccount => 'Link Account';

  @override
  String get walletCustomersScanQr => 'Customers will scan your QR to pay you';

  @override
  String get walletYourQrCode => 'YOUR QR CODE';

  @override
  String get walletTapUploadQr => 'Tap to upload your QR code';

  @override
  String get walletFromAnyBank => 'From any bank\'s DuitNow app';

  @override
  String get walletUploadQrFirst => 'Please upload your QR code first';

  @override
  String get walletSaveDuitnowQr => 'Save DuitNow QR';

  @override
  String get walletTaskCompletedTx => 'Task Completed';

  @override
  String get walletWithdrawalTx => 'Withdrawal';

  @override
  String get walletTopUpTx => 'Top Up';

  @override
  String get walletPaidForTaskTx => 'Paid for Task';

  @override
  String get paymentCardNumber => 'Card Number';

  @override
  String get paymentExpiryDate => 'Expiry Date';

  @override
  String get paymentCvv => 'CVV';

  @override
  String get paymentCardholderName => 'Cardholder Name';

  @override
  String get paymentAccountNumber => 'Account Number';

  @override
  String get chatMessages => 'Messages';

  @override
  String get chatSearchConversations => 'Search conversations...';

  @override
  String get chatRecent => 'RECENT';

  @override
  String get chatNoConversations => 'No conversations yet.';

  @override
  String get chatNoMatchingConversations => 'No matching conversations.';

  @override
  String get chatDeleteChat => 'Delete Chat?';

  @override
  String get chatDeleteChatDesc =>
      'This will permanently delete the conversation for both of you.';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatCamera => 'Camera';

  @override
  String get chatGallery => 'Gallery';

  @override
  String get chatFile => 'File';

  @override
  String get chatTaskCard => 'Task Card';

  @override
  String get chatSendQuote => 'Send Quote';

  @override
  String get chatCounterOffer => 'Counter-Offer';

  @override
  String get chatRequestLocation => 'Request Location';

  @override
  String get chatTypeMessage => 'Type message...';

  @override
  String get chatStartChat => 'Start chat';

  @override
  String get chatOnline => 'Online';

  @override
  String get chatOffline => 'Offline';

  @override
  String get chatTyping => 'typing...';

  @override
  String get chatSend => 'Send';

  @override
  String get chatAttachment => 'Attachment';

  @override
  String get chatPhoto => 'Photo';

  @override
  String get chatVideo => 'Video';

  @override
  String get chatDocument => 'Document';

  @override
  String get chatLocation => 'Location';

  @override
  String get chatQuoteAmount => 'Quote Amount';

  @override
  String get chatEnterAmount => 'Enter amount (RM)';

  @override
  String get chatSendQuoteBtn => 'Send Quote';

  @override
  String get chatCounterOfferBtn => 'Send Counter';

  @override
  String get chatAccept => 'Accept';

  @override
  String get chatDecline => 'Decline';

  @override
  String get chatLocationShared => 'Location Shared';

  @override
  String get chatViewMap => 'View Map';

  @override
  String get chatTaskInfo => 'Task Info';

  @override
  String get chatBounty => 'Bounty';

  @override
  String get chatStatus => 'Status';

  @override
  String get chatLocationRequested => 'Location Requested';

  @override
  String get chatShareLocationDesc =>
      'Share your location to help calculate travel distance.';

  @override
  String get chatShareLocation => 'Share Location';

  @override
  String get privacyTitle => 'Privacy & Security';

  @override
  String get privacyAppLock => 'App Lock';

  @override
  String get privacyAppLockDesc => 'Use biometric or PIN to lock the app';

  @override
  String get privacyHideAppSwitcher => 'Hide in App Switcher';

  @override
  String get privacyLocationServices => 'Location Services';

  @override
  String get privacyTwoFactorAuth => 'Two-Factor Authentication';

  @override
  String get privacyEnable2fa => 'Enable 2FA?';

  @override
  String get privacyDataPrivacy => 'DATA & PRIVACY';

  @override
  String get privacySystemPermissions => 'System Permissions';

  @override
  String get privacyManagePermissions => 'Manage Camera, Gallery, and GPS';

  @override
  String get privacyClearCache => 'Clear App Cache?';

  @override
  String get privacyFreeStorage =>
      'Clear temporary files to free up space. Your data is safe.';

  @override
  String get privacyActiveSessions => 'ACTIVE SESSIONS';

  @override
  String get privacyThisDevice => 'THIS DEVICE';

  @override
  String get privacyActiveNow => 'Active Now';

  @override
  String get privacyLogOutAll => 'Log out of all devices';

  @override
  String get privacyInstantlySecure => 'Instantly secure your account';

  @override
  String get privacyEnableAppLock => 'Enable App Lock';

  @override
  String get privacyAppLockInfo =>
      'Your app will be locked with biometric or device PIN every time you switch away.';

  @override
  String get privacyNotNow => 'Not Now';

  @override
  String get privacyEnable => 'Enable';

  @override
  String get privacyAuthEnableLock => 'Authenticate to enable App Lock';

  @override
  String get privacyAuthDisableLock => 'Authenticate to disable App Lock';

  @override
  String get privacyEnable2faDesc =>
      'Add an extra layer of security to your account. You will need to verify your identity when logging in from a new device.';

  @override
  String get privacyDisable2fa => 'Disable Two-Factor Authentication';

  @override
  String get privacyDisable2faDesc =>
      'Your account will only rely on your password for security.';

  @override
  String get privacyCacheCleared => 'Cache cleared successfully';

  @override
  String get privacyLogOutAllTitle => 'Secure Account?';

  @override
  String get privacyLogOutAllDesc =>
      'This will instantly log you out of all other devices. You will stay logged in on this phone.';

  @override
  String get privacyLogOutAllBtn => 'Log Out All';

  @override
  String get privacyActiveSessionsInfo => 'Device Details';

  @override
  String get privacyLastLogin => 'Last Login';

  @override
  String get privacyDevice => 'Device';

  @override
  String get privacyIpAddress => 'IP Address';

  @override
  String get supportDone => 'Done';

  @override
  String get supportHelpCenter => 'Help Center';

  @override
  String get supportGreeting => 'Hi\nHow can we help?';

  @override
  String get supportSearchHint => 'Search questions...';

  @override
  String get supportFaqTitle => 'FAQ';

  @override
  String supportNoResults(Object arg0) {
    return 'No questions found for \"$arg0\"';
  }

  @override
  String get supportContactUs => 'Contact Us';

  @override
  String get supportContactSubtitle => 'Our team is ready to help you.';

  @override
  String get supportChatSupport => 'Chat Support';

  @override
  String get supportChatSubtitle => 'We\'re here to help.';

  @override
  String get supportStartChat => 'Start Chat';

  @override
  String get supportEmailUs => 'Email Us';

  @override
  String get supportEmailSubtitle => 'Send an email anytime.';

  @override
  String get supportCallUs => 'Call Us';

  @override
  String get supportCallSubtitle => 'Mon-Fri, 9am–5pm.';

  @override
  String get supportFollowUs => 'FOLLOW US';

  @override
  String get supportFaq1Q => 'How do I post a task?';

  @override
  String get supportFaq1A =>
      'Tap the \"+\" button below, fill in the task details like category, location, and price offer. Then submit and wait for a runner to pick up your task.';

  @override
  String get supportFaq2Q => 'How do I become a Runner?';

  @override
  String get supportFaq2A =>
      'Switch your role to \"Runner\" from your profile. You can then find available tasks in the feed and accept suitable ones.';

  @override
  String get supportFaq3Q => 'How does payment work?';

  @override
  String get supportFaq3A =>
      'Payment is made directly between the Customer and Runner after task completion. We recommend using DuitNow or bank transfer.';

  @override
  String get supportFaq4Q => 'Can I cancel a task?';

  @override
  String get supportFaq4A =>
      'Yes, you can cancel from the \"My Tasks\" page as long as no runner has accepted it yet.';

  @override
  String get supportFaq5Q => 'What if the runner doesn\'t show up?';

  @override
  String get supportFaq5A =>
      'Contact us through \"Contact Us\" and we will help resolve the issue within 24 hours.';

  @override
  String get supportFaq6Q => 'Can Ngam runners be trusted?';

  @override
  String get supportFaq6A =>
      'All our runners must go through a strict identity verification process before their accounts are activated for your safety.';

  @override
  String get supportFaq7Q => 'Can I communicate with the runner?';

  @override
  String get supportFaq7A =>
      'Yes, you can use the in-app chat to communicate with the runner once they accept your task.';

  @override
  String get supportFaq8Q => 'What if the item price changes?';

  @override
  String get supportFaq8A =>
      'You can discuss with the runner through chat. The runner will inform you of the actual price with a receipt for verification.';

  @override
  String get supportFaq9Q => 'How do I give a rating?';

  @override
  String get supportFaq9A =>
      'After the task is marked as complete, a pop-up will appear allowing you to rate and review the runner.';

  @override
  String get supportFaq10Q => 'Is my location information safe?';

  @override
  String get supportFaq10A =>
      'Yes, your personal and exact location information will only be shared with the runner who has accepted your task.';

  @override
  String get supportFaq11Q => 'How long does it take to complete a task?';

  @override
  String get supportFaq11A =>
      'It depends on the type of task and distance. You can view the estimated time or ask the runner directly.';

  @override
  String get supportFaq12Q => 'What if my item is damaged?';

  @override
  String get supportFaq12A =>
      'Please take a photo of the damage and contact our customer support within 24 hours for compensation assistance.';

  @override
  String get supportFaq13Q => 'Can I tip the runner?';

  @override
  String get supportFaq13A =>
      'Of course! You can give a cash tip directly to the runner or include the tip amount in your original task price offer.';

  @override
  String get supportFaq14Q => 'Is there a weight limit for items?';

  @override
  String get supportFaq14A =>
      'We recommend a maximum weight of 15kg for motorcycle delivery tasks. For larger items, please state clearly in the description.';

  @override
  String get supportFaq15Q => 'Can I change location after runner accepts?';

  @override
  String get supportFaq15A =>
      'Location changes after task acceptance are subject to runner agreement. Additional costs may apply.';

  @override
  String get aboutLikeNgam => 'Like Ngam?';

  @override
  String get aboutRateSubtitle => 'Give us stars to help us grow.';

  @override
  String get aboutFeedbackHint => 'Share your thoughts about Ngam...';

  @override
  String get aboutSubmitFeedback => 'Submit Feedback';

  @override
  String get aboutThankYou => 'Thank you for your feedback!';

  @override
  String get accountTitle => 'Account Details';

  @override
  String get accountPublicProfile => 'PUBLIC PROFILE';

  @override
  String get accountShippingDetails => 'SHIPPING DETAILS';

  @override
  String get accountSecurity => 'SECURITY';

  @override
  String get accountSaveChanges => 'Save Changes';

  @override
  String get accountFullName => 'Full Name';

  @override
  String get accountEmailReadonly => 'Email Address (Read Only)';

  @override
  String get accountPhone => 'Phone Number';

  @override
  String get accountDob => 'Date of Birth';

  @override
  String get accountAddress => 'Primary Delivery Address';

  @override
  String get accountCurrentPassword => 'Current Password';

  @override
  String get accountNewPassword => 'New Password';

  @override
  String get reviewTitle => 'Rate & Review';

  @override
  String get reviewHowWas => 'How was your experience?';

  @override
  String get reviewTapToRate => 'Tap a star to rate';

  @override
  String get reviewLeaveComment => 'Leave a comment (optional)';

  @override
  String get reviewCommentHint => 'Tell us about your experience...';

  @override
  String get reviewSubmit => 'Submit Review';

  @override
  String get reviewSubmitting => 'Submitting...';

  @override
  String get reviewSelectRating => 'Please select a rating';

  @override
  String get reviewFailed => 'Failed to submit review';

  @override
  String get verificationTitle => 'Become a Runner';

  @override
  String get verificationSubtitle => 'Complete verification to start earning';

  @override
  String get verificationFullName => 'Full Legal Name';

  @override
  String get verificationIcNumber => 'IC Number';

  @override
  String get verificationVehicleType => 'Vehicle Type';

  @override
  String get verificationUploadIc => 'Upload IC Photo';

  @override
  String get verificationUploadSelfie => 'Upload Selfie with IC';

  @override
  String get verificationSubmit => 'Submit Verification';

  @override
  String get verificationPending => 'Verification Pending';

  @override
  String get verificationApproved => 'Verified Runner';

  @override
  String get statsTitle => 'Stats & Earnings';

  @override
  String get statsTotalEarnings => 'Total Earnings';

  @override
  String get statsCompletedTasks => 'Completed Tasks';

  @override
  String get statsAvgRating => 'Average Rating';

  @override
  String get statsWeekly => 'Weekly';

  @override
  String get statsMonthly => 'Monthly';

  @override
  String get statsAllTime => 'All-Time';

  @override
  String get statsEarningsChart => 'Earnings Chart';

  @override
  String get statsNoEarnings => 'No earnings data.';

  @override
  String get statsNoTaskData => 'No task data.';

  @override
  String get statsTasksByStatus => 'Tasks by Status';

  @override
  String get statsEarningsByCategory => 'Earnings by Category';

  @override
  String get statsRecentActivity => 'Recent Activity';

  @override
  String get rankBronze => 'Bronze Runner';

  @override
  String get rankSilver => 'Silver Runner';

  @override
  String get rankGold => 'Gold Runner';

  @override
  String get rankPlatinum => 'Platinum Runner';

  @override
  String rankXpToNext(Object arg0) {
    return '$arg0 XP to next rank';
  }

  @override
  String rankTasksProgress(Object arg0, Object arg1) {
    return '$arg0 / $arg1 Tasks';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonNoData => 'No data available';

  @override
  String get commonLogOut => 'Log Out';

  @override
  String get taskDetailNavigate => 'Navigate to Location';

  @override
  String get taskDetailManageService => 'Manage Service';

  @override
  String get taskDetailAdjustBounty => 'Adjust Bounty';

  @override
  String get taskDetailDeleteService => 'Delete Service';

  @override
  String get taskDetailDeleteServiceTitle => 'Delete Service?';

  @override
  String get taskDetailDeleteServiceDesc =>
      'Are you sure you want to permanently delete this service?';

  @override
  String get taskDetailCancel => 'Cancel';

  @override
  String get taskDetailDelete => 'Delete';

  @override
  String get taskDetailSave => 'Save';

  @override
  String taskDetailErrorChat(Object arg0) {
    return 'Error starting chat: $arg0';
  }

  @override
  String get navFeed => 'Ngam Feed';

  @override
  String get navInbox => 'Messages';

  @override
  String get navDiscover => 'Discover';

  @override
  String get expandSidebar => 'Expand Sidebar';

  @override
  String get collapseSidebar => 'Collapse Sidebar';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get switchLanguage => 'Switch Language';

  @override
  String homeGreeting(Object name) {
    return 'Hi, $name';
  }

  @override
  String get homeSearchPlaceholder => 'Search services, stores, items...';

  @override
  String homeCurrentLocation(Object location) {
    return 'Current location: $location';
  }

  @override
  String homeLocationDetected(Object location) {
    return 'Location detected: $location';
  }

  @override
  String get homeNearbyStores => 'Nearby Stores';

  @override
  String get homeSeeAll => 'See All';

  @override
  String get homePopularOffers => 'Hot Deals';

  @override
  String get homeTrendingPort => 'Trending Spots';

  @override
  String get homeQuickCategories => 'Quick Categories';

  @override
  String get homeLiveQueue => 'My Queue';

  @override
  String get homeStampsCard => 'Stamp Rewards';

  @override
  String get homeFlashPromo => 'Flash RM10';

  @override
  String get homeFlashDesc => 'Haircut Promo';

  @override
  String get homeViralCafe => 'Viral Spot';

  @override
  String get homeViralDesc => 'Coffee & Bakery';

  @override
  String get homeDetailing => 'Nano Detailing';

  @override
  String get homeDetailingDesc => '30% Discount';

  @override
  String get homeDailyCoupon => 'Daily Promo';

  @override
  String get homeDailyCouponDesc => 'RM5 Coupon';

  @override
  String get homeSpaRelax => 'Spa & Relax';

  @override
  String get homeSpaRelaxDesc => 'Afternoon Slot';

  @override
  String get catBarber => 'Haircut';

  @override
  String get catCarwash => 'Car Wash';

  @override
  String get catCafe => 'Cafe & Chill';

  @override
  String get catWorkshop => 'Workshop';

  @override
  String get catSalon => 'Salon & Spa';

  @override
  String get catHealth => 'Clinic & Health';

  @override
  String get feedForYou => 'For You';

  @override
  String get feedFollowing => 'Following';

  @override
  String get feedBookNow => 'Book Now';

  @override
  String get feedVisitStore => 'Visit Store';

  @override
  String get storeCatalog => 'Catalog';

  @override
  String get storeMenu => 'Menu';

  @override
  String get storeReviews => 'Reviews';

  @override
  String get storeInfo => 'Info';

  @override
  String get storeAllItems => 'All Items';

  @override
  String get storeBookQueue => 'Book / Queue';

  @override
  String get bookingCancelTitle => 'Cancel Booking';

  @override
  String get bookingDisputeTitle => 'Report Dispute';

  @override
  String get bookingRefundNote =>
      'Refund will be credited to your Ngam Wallet.';

  @override
  String get profileStampCards => 'Reward Stamp Cards';

  @override
  String get profileLiveQueue => 'Walk-In Queue Ticket (Live Queue)';

  @override
  String get profileCheckUpdates => 'Check for App Updates';

  @override
  String get profileGuestUser => 'Guest User';

  @override
  String get profileGuestSubtitle =>
      'Sign in to manage your bookings and rewards.';

  @override
  String get profileLoginRegister => 'Sign In / Register';

  @override
  String get profileSaved => 'Saved';

  @override
  String get profileSavedShops => 'Saved Shops';

  @override
  String get profileSavedPosts => 'Saved Posts';
}
