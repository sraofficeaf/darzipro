/// LicenseModel — retained for backward compatibility with Hive cache
/// and existing providers. In the new subscription model, actual
/// subscription state comes from [SubscriptionState] / Supabase.
///
/// This model is still used locally for:
///   - Cloud-enabled flag (always true now — all plans have cloud access)
///   - Offline cache of whether the user has a valid session
class LicenseModel {
  final String plan;       // subscription plan code or legacy code
  final String licenseKey; // retained for key-based activation (legacy)
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

  // ── Plan checks (new subscription model) ──────────────────────

  /// All plans in the new model have cloud database access.
  bool get isCloudEnabled => true;

  /// True if the shop has lifetime (grandfathered) access.
  bool get isLifetime =>
      plan == 'lifetime' ||
      plan == 'full_access' ||
      plan == 'full_access_3yr' ||
      plan == 'mobile_only';

  /// True if shop is on an active paid plan.
  bool get isActivePaidPlan =>
      plan == 'basic' || plan == 'standard' || plan == 'unlimited' || isLifetime;

  /// True if shop is on the trial plan.
  bool get isTrial => plan == 'trial';

  /// Kept for legacy references — treated as isActivePaidPlan.
  bool get isPro => isActivePaidPlan;
  bool get isBusiness => plan == 'unlimited' || isLifetime;

  // ── Expiry helpers ─────────────────────────────────────────────

  int get daysRemaining {
    if (expiresAt == null) return 0;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  bool get isExpiringSoon => daysRemaining <= 7 && daysRemaining > 0;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  // ── Hive serialization ─────────────────────────────────────────

  Map<String, dynamic> toHive() => {
        'plan': plan,
        'licenseKey': licenseKey,
        'isActive': isActive,
        'expiresAt': expiresAt?.toIso8601String(),
        'shopName': shopName,
        'email': email,
        'activatedAt': activatedAt?.toIso8601String(),
      };

  factory LicenseModel.fromHive(Map map) => LicenseModel(
        plan: map['plan'] ?? 'trial',
        licenseKey: map['licenseKey'] ?? '',
        isActive: map['isActive'] ?? true,
        expiresAt: map['expiresAt'] != null
            ? DateTime.tryParse(map['expiresAt'])
            : null,
        shopName: map['shopName'] ?? '',
        email: map['email'] ?? '',
        activatedAt: map['activatedAt'] != null
            ? DateTime.tryParse(map['activatedAt'])
            : null,
      );

  /// Default free/trial license for new users.
  factory LicenseModel.free() => const LicenseModel(
        plan: 'trial',
        licenseKey: '',
        isActive: true,
        shopName: '',
        email: '',
      );

  LicenseModel copyWith({
    String? plan,
    String? licenseKey,
    bool? isActive,
    DateTime? expiresAt,
    String? shopName,
    String? email,
    DateTime? activatedAt,
  }) {
    return LicenseModel(
      plan: plan ?? this.plan,
      licenseKey: licenseKey ?? this.licenseKey,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      activatedAt: activatedAt ?? this.activatedAt,
    );
  }
}
