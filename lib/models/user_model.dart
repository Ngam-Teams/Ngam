// ============================================================
// Ngam App — Model User
// ============================================================

class UserModel {
  final String id;
  final String role; // 'customer', 'runner', 'business', 'console'
  final DateTime createdAt;
  final DateTime updatedAt;

  // User attributes
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userBio;
  final String? userGender;
  final DateTime? userBirthDate;
  final String? userAddress;
  final double? userAddressLat;
  final double? userAddressLng;
  final String? userQrCodeUrl;
  final String? userAvatarUrl;
  final String? userFcmToken;
  final double userBalance;
  final bool userIsVerifiedRunner;

  // Business attributes
  final String? businessName;
  final String? businessEmail;
  final String? businessPhone;
  final String? businessAddress;
  final String? businessRegistrationNumber;
  final String? businessLogoUrl;
  final double businessBalance;

  // Console attributes
  final String? consoleName;
  final String? consoleEmail;
  final String? consoleRole;

  UserModel({
    required this.id,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userBio,
    this.userGender,
    this.userBirthDate,
    this.userAddress,
    this.userAddressLat,
    this.userAddressLng,
    this.userQrCodeUrl,
    this.userAvatarUrl,
    this.userFcmToken,
    this.userBalance = 0.0,
    this.userIsVerifiedRunner = false,
    this.businessName,
    this.businessEmail,
    this.businessPhone,
    this.businessAddress,
    this.businessRegistrationNumber,
    this.businessLogoUrl,
    this.businessBalance = 0.0,
    this.consoleName,
    this.consoleEmail,
    this.consoleRole,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'customer',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
      userPhone: json['user_phone'] as String?,
      userBio: json['user_bio'] as String?,
      userGender: json['user_gender'] as String?,
      userBirthDate: json['user_birth_date'] != null ? DateTime.parse(json['user_birth_date'] as String) : null,
      userAddress: json['user_address'] as String?,
      userAddressLat: json['user_address_lat'] != null ? (json['user_address_lat'] as num).toDouble() : null,
      userAddressLng: json['user_address_lng'] != null ? (json['user_address_lng'] as num).toDouble() : null,
      userQrCodeUrl: json['user_qr_code_url'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
      userFcmToken: json['user_fcm_token'] as String?,
      userBalance: (json['user_balance'] as num?)?.toDouble() ?? 0.0,
      userIsVerifiedRunner: json['user_is_verified_runner'] as bool? ?? false,
      businessName: json['business_name'] as String?,
      businessEmail: json['business_email'] as String?,
      businessPhone: json['business_phone'] as String?,
      businessAddress: json['business_address'] as String?,
      businessRegistrationNumber: json['business_registration_number'] as String?,
      businessLogoUrl: json['business_logo_url'] as String?,
      businessBalance: (json['business_balance'] as num?)?.toDouble() ?? 0.0,
      consoleName: json['console_name'] as String?,
      consoleEmail: json['console_email'] as String?,
      consoleRole: json['console_role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (userName != null) 'user_name': userName,
      if (userEmail != null) 'user_email': userEmail,
      if (userPhone != null) 'user_phone': userPhone,
      if (userBio != null) 'user_bio': userBio,
      if (userGender != null) 'user_gender': userGender,
      if (userBirthDate != null) 'user_birth_date': "${userBirthDate!.year}-${userBirthDate!.month.toString().padLeft(2, '0')}-${userBirthDate!.day.toString().padLeft(2, '0')}",
      if (userAddress != null) 'user_address': userAddress,
      if (userAddressLat != null) 'user_address_lat': userAddressLat,
      if (userAddressLng != null) 'user_address_lng': userAddressLng,
      if (userQrCodeUrl != null) 'user_qr_code_url': userQrCodeUrl,
      if (userAvatarUrl != null) 'user_avatar_url': userAvatarUrl,
      if (userFcmToken != null) 'user_fcm_token': userFcmToken,
      'user_balance': userBalance,
      'user_is_verified_runner': userIsVerifiedRunner,
      if (businessName != null) 'business_name': businessName,
      if (businessEmail != null) 'business_email': businessEmail,
      if (businessPhone != null) 'business_phone': businessPhone,
      if (businessAddress != null) 'business_address': businessAddress,
      if (businessRegistrationNumber != null) 'business_registration_number': businessRegistrationNumber,
      if (businessLogoUrl != null) 'business_logo_url': businessLogoUrl,
      'business_balance': businessBalance,
      if (consoleName != null) 'console_name': consoleName,
      if (consoleEmail != null) 'console_email': consoleEmail,
      if (consoleRole != null) 'console_role': consoleRole,
    };
  }

  UserModel copyWith({
    String? id,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? userBio,
    String? userGender,
    DateTime? userBirthDate,
    String? userAddress,
    double? userAddressLat,
    double? userAddressLng,
    String? userQrCodeUrl,
    String? userAvatarUrl,
    String? userFcmToken,
    double? userBalance,
    bool? userIsVerifiedRunner,
    String? businessName,
    String? businessEmail,
    String? businessPhone,
    String? businessAddress,
    String? businessRegistrationNumber,
    String? businessLogoUrl,
    double? businessBalance,
    String? consoleName,
    String? consoleEmail,
    String? consoleRole,
  }) {
    return UserModel(
      id: id ?? this.id,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      userBio: userBio ?? this.userBio,
      userGender: userGender ?? this.userGender,
      userBirthDate: userBirthDate ?? this.userBirthDate,
      userAddress: userAddress ?? this.userAddress,
      userAddressLat: userAddressLat ?? this.userAddressLat,
      userAddressLng: userAddressLng ?? this.userAddressLng,
      userQrCodeUrl: userQrCodeUrl ?? this.userQrCodeUrl,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      userFcmToken: userFcmToken ?? this.userFcmToken,
      userBalance: userBalance ?? this.userBalance,
      userIsVerifiedRunner: userIsVerifiedRunner ?? this.userIsVerifiedRunner,
      businessName: businessName ?? this.businessName,
      businessEmail: businessEmail ?? this.businessEmail,
      businessPhone: businessPhone ?? this.businessPhone,
      businessAddress: businessAddress ?? this.businessAddress,
      businessRegistrationNumber: businessRegistrationNumber ?? this.businessRegistrationNumber,
      businessLogoUrl: businessLogoUrl ?? this.businessLogoUrl,
      businessBalance: businessBalance ?? this.businessBalance,
      consoleName: consoleName ?? this.consoleName,
      consoleEmail: consoleEmail ?? this.consoleEmail,
      consoleRole: consoleRole ?? this.consoleRole,
    );
  }
}
