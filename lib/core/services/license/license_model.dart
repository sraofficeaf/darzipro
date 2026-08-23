class LicenseModel {
  final String plan;         // 'free' | 'pro' | 'business'
  final String licenseKey;   // DARZI-XXXX-XXXX-XXXX
  final bool isActive;
  final DateTime? expiresAt;
  final String shopName;
  final String email;
  final DateTime? activatedAt;

  const LicenseModel({
    required this.plan,
    required this.licenseKey,
    required this.isActive,
    this.expiresAt,
    required this.shopName,
    required this.email,
    this.activatedAt,
  });

  bool get isBasic => plan == 'mobile_only' || plan == 'basic';
  bool get isProfessional => plan == 'full_access' || plan == 'pro';
  bool get isEnterprise => plan == 'full_access_3yr' || plan == 'business';

  bool get isFree => false; // All plans in Darzi Pro are paid lifetime tiers
  bool get isPro => isProfessional || isEnterprise || isActive;
  bool get isBusiness => isEnterprise;
  bool get isCloudEnabled => true; // All Darzi Pro plans have Cloud Database Storage enabled

  int get daysRemaining {
    if (expiresAt == null) return 0;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  bool get isExpiringSoon => daysRemaining <= 7 && daysRemaining > 0;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  // Save to Hive
  Map<String, dynamic> toHive() => {
    'plan': plan,
    'licenseKey': licenseKey,
    'isActive': isActive,
    'expiresAt': expiresAt?.toIso8601String(),
    'shopName': shopName,
    'email': email,
    'activatedAt': activatedAt?.toIso8601String(),
  };

  // Load from Hive
  factory LicenseModel.fromHive(Map map) => LicenseModel(
    plan: map['plan'] ?? 'free',
    licenseKey: map['licenseKey'] ?? '',
    isActive: map['isActive'] ?? false,
    expiresAt: map['expiresAt'] != null
      ? DateTime.tryParse(map['expiresAt'])
      : null,
    shopName: map['shopName'] ?? '',
    email: map['email'] ?? '',
    activatedAt: map['activatedAt'] != null
      ? DateTime.tryParse(map['activatedAt'])
      : null,
  );

  // Default free license
  factory LicenseModel.free() => const LicenseModel(
    plan: 'free',
    licenseKey: '',
    isActive: true,
    shopName: '',
    email: '',
  );
}
