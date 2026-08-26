// ============================================================
// Ngam App — Model User
// ============================================================

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'customer' atau 'runner'
  final String? avatarUrl;
  final String? bio;
  final String? gender;
  final DateTime? birthDate;
  final String? address;
  final double? addressLat;
  final double? addressLng;
  final DateTime createdAt;
  final double balance;
  final String? qrCodeUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.bio,
    this.gender,
    this.birthDate,
    this.address,
    this.addressLat,
    this.addressLng,
    required this.createdAt,
    this.balance = 0.0,
    this.qrCodeUrl,
  });

  /// Create from Supabase JSON row
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'customer',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      gender: json['gender'] as String?,
      birthDate: json['birth_date'] != null ? DateTime.parse(json['birth_date'] as String) : null,
      address: json['address'] as String?,
      addressLat: json['address_lat'] != null ? (json['address_lat'] as num).toDouble() : null,
      addressLng: json['address_lng'] != null ? (json['address_lng'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      qrCodeUrl: json['qr_code_url'] as String?,
    );
  }

  /// Convert to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (bio != null) 'bio': bio,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birth_date': "${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}",
      if (address != null) 'address': address,
      'created_at': createdAt.toIso8601String(),
      'balance': balance,
      if (qrCodeUrl != null) 'qr_code_url': qrCodeUrl,
    };
  }

  /// Create a copy with modified fields
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? avatarUrl,
    String? bio,
    String? gender,
    DateTime? birthDate,
    String? address,
    DateTime? createdAt,
    double? balance,
    String? qrCodeUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      balance: balance ?? this.balance,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
    );
  }
}
