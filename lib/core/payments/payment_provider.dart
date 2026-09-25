import 'package:flutter/foundation.dart';

/// Payment purposes supported across Darzi Pro.
enum PaymentPurpose {
  subscriptionMonthly,
  foundingActivation,
  storageMonthly,
  storageAnnual;

  String get code => name;

  String get displayTitleEn {
    switch (this) {
      case PaymentPurpose.subscriptionMonthly:
        return 'Monthly Subscription';
      case PaymentPurpose.foundingActivation:
        return 'Founding Member Lifetime Activation';
      case PaymentPurpose.storageMonthly:
        return 'Monthly Storage Add-on';
      case PaymentPurpose.storageAnnual:
        return 'Annual Storage Add-on';
    }
  }

  String get displayTitleUr {
    switch (this) {
      case PaymentPurpose.subscriptionMonthly:
        return 'ماہانہ سبسکرپشن';
      case PaymentPurpose.foundingActivation:
        return 'بانی ممبر لائف ٹائم ایکٹیویشن';
      case PaymentPurpose.storageMonthly:
        return 'ماہانہ سٹوریج ایڈ آن';
      case PaymentPurpose.storageAnnual:
        return 'سالانہ سٹوریج ایڈ آن';
    }
  }

  static PaymentPurpose fromString(String val) {
    for (final p in PaymentPurpose.values) {
      if (p.name.toLowerCase() == val.toLowerCase()) return p;
    }
    return PaymentPurpose.subscriptionMonthly;
  }
}

/// Normalized payment status across all payment providers.
enum PaymentStatus {
  pending,
  processing,
  succeeded,
  failed,
  cancelled,
  awaitingReview,
  expired;

  String get code => name;

  bool get isTerminal =>
      this == succeeded || this == failed || this == cancelled || this == expired;

  static PaymentStatus fromString(String val) {
    for (final s in PaymentStatus.values) {
      if (s.name.toLowerCase() == val.toLowerCase()) return s;
    }
    return PaymentStatus.pending;
  }
}

/// Represents an initiated payment session returned by any PaymentProvider.
@immutable
class PaymentSession {
  final String providerReference; // Stripe payment_intent_id, unified payment id, etc.
  final String? redirectUrl; // For hosted checkout
  final String? clientSecret; // For in-app payment sheet confirmation
  final PaymentStatus status;
  final Map<String, dynamic>? metadata;

  const PaymentSession({
    required this.providerReference,
    this.redirectUrl,
    this.clientSecret,
    required this.status,
    this.metadata,
  });

  PaymentSession copyWith({
    String? providerReference,
    String? redirectUrl,
    String? clientSecret,
    PaymentStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentSession(
      providerReference: providerReference ?? this.providerReference,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      clientSecret: clientSecret ?? this.clientSecret,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Provider-agnostic payment interface following the Adapter Pattern.
/// App code never calls a specific payment provider directly.
abstract class PaymentProvider {
  /// Unique provider identifier (e.g. 'stripe', 'manual').
  String get code;

  /// User-facing display name in UI (e.g. 'Card / Stripe').
  String get displayName;

  /// Asset path or identifier for the provider icon.
  String get iconAsset;

  /// Currencies supported by this provider (or ['*'] for any).
  List<String> get supportedCurrencies;

  /// True if payment auto-confirms instantly; false if manual review required.
  bool get isInstant;

  /// Initiates a payment session.
  /// CRITICAL: [amountMinor] is strictly in minor units (integer paisa/cents).
  Future<PaymentSession> createPayment({
    required String shopId,
    required int amountMinor,
    required String currency,
    required PaymentPurpose purpose,
    Map<String, dynamic>? metadata,
  });

  /// Queries the current status of the payment using the provider reference.
  Future<PaymentStatus> checkStatus(String providerReference);
}
