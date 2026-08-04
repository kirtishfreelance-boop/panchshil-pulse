class AppUser {
  const AppUser({
    required this.id,
    this.firstname,
    this.lastname,
    this.fullName,
    this.email,
    required this.mobile,
    this.countryCode = '+91',
    this.gender,
    this.companyName,
    this.designation,
    this.profileImage,
    this.siteId,
    this.registered = false,
    this.walletBalance = 0,
    this.loyaltyPoints = 0,
  });

  final int id;
  final String? firstname;
  final String? lastname;
  final String? fullName;
  final String? email;
  final String mobile;
  final String countryCode;
  final String? gender;
  final String? companyName;
  final String? designation;
  final String? profileImage;
  final int? siteId;
  final bool registered;
  final double walletBalance;
  final int loyaltyPoints;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return [firstname, lastname].whereType<String>().join(' ').trim();
  }

  /// Two-letter avatar fallback, e.g. "Aarav Mehta" -> "AM".
  String get initials {
    final parts = displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] as num).toInt(),
        firstname: json['firstname'] as String?,
        lastname: json['lastname'] as String?,
        fullName: json['full_name'] as String?,
        email: json['email'] as String?,
        mobile: json['mobile'] as String? ?? '',
        countryCode: json['country_code'] as String? ?? '+91',
        gender: json['gender'] as String?,
        companyName: json['company_name'] as String?,
        designation: json['designation'] as String?,
        profileImage: json['profile_image'] as String?,
        siteId: (json['site_id'] as num?)?.toInt(),
        registered: json['registered'] == true,
        walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0,
        loyaltyPoints: (json['loyalty_points'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstname': firstname,
        'lastname': lastname,
        'full_name': fullName,
        'email': email,
        'mobile': mobile,
        'country_code': countryCode,
        'gender': gender,
        'company_name': companyName,
        'designation': designation,
        'profile_image': profileImage,
        'site_id': siteId,
        'registered': registered,
        'wallet_balance': walletBalance,
        'loyalty_points': loyaltyPoints,
      };

  AppUser copyWith({int? siteId, double? walletBalance, int? loyaltyPoints}) => AppUser(
        id: id,
        firstname: firstname,
        lastname: lastname,
        fullName: fullName,
        email: email,
        mobile: mobile,
        countryCode: countryCode,
        gender: gender,
        companyName: companyName,
        designation: designation,
        profileImage: profileImage,
        siteId: siteId ?? this.siteId,
        registered: registered,
        walletBalance: walletBalance ?? this.walletBalance,
        loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      );
}
