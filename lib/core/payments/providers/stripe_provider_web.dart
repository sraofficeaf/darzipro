// Web & desktop stub — uses Stripe Checkout Session (hosted).
// This file must NEVER import package:flutter_stripe/flutter_stripe.dart.
// It is selected by the conditional import in stripe_provider.dart
// when dart.library.html is available (i.e., Flutter Web).

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../payment_provider.dart';

/// Stripe payment provider for Flutter Web.
/// Routes all payments through Stripe Checkout (hosted page).
/// The native Payment Sheet SDK (flutter_stripe) is never loaded.
class StripePaymentProvider implements PaymentProvider {
  final String? defaultPublishableKey;

  const StripePaymentProvider({this.defaultPublishableKey});

  @override
  String get code => 'stripe';

  @override
  String get displayName => 'Card / Stripe';

  @override
  String get iconAsset => 'assets/icons/stripe.svg';

  @override
  List<String> get supportedCurrencies =>
      const ['USD', 'EUR', 'GBP', 'AED', 'PKR'];

  @override
  bool get isInstant => true;

  @override
  Future<PaymentSession> createPayment({
    required String shopId,
    required int amountMinor,
    required String currency,
    required PaymentPurpose purpose,
    Map<String, dynamic>? metadata,
  }) async {
    return _createCheckoutSession(
      shopId: shopId,
      amountMinor: amountMinor,
      currency: currency,
      purpose: purpose,
      metadata: metadata,
    );
  }

  /// Creates a Stripe Checkout Session server-side and returns its URL.
  /// The `providerReference` in the returned session is the unified_payments
  /// row UUID (payment_id), NOT the Stripe session ID, because the
  /// PaymentIntent ID is null at session-creation time and the webhook
  /// keys on metadata.payment_id.
  Future<PaymentSession> _createCheckoutSession({
    required String shopId,
    required int amountMinor,
    required String currency,
    required PaymentPurpose purpose,
    Map<String, dynamic>? metadata,
  }) async {
    final client = Supabase.instance.client;

    final response = await client.functions.invoke(
      'stripe-payment',
      body: {
        'action': 'create-checkout-session',
        'shop_id': shopId,
        'amount_minor': amountMinor,
        'currency': currency.toLowerCase(),
        'purpose': purpose.name,
        'metadata': metadata ?? {},
      },
    );

    if (response.status != 200 && response.status != 201) {
      final errorMsg = response.data is Map
          ? (response.data['error']?.toString() ??
              'Failed to create checkout session')
          : 'Server returned ${response.status}';
      throw Exception(errorMsg);
    }

    final data = response.data as Map<String, dynamic>;
    final url = data['url'] as String?;
    final paymentId = data['payment_id'] as String?;

    if (url == null || url.isEmpty) {
      throw Exception('Checkout session URL was empty');
    }
    if (paymentId == null || paymentId.isEmpty) {
      throw Exception('Server did not return a payment_id');
    }

    // Launch the Stripe Checkout page in a new browser tab.
    // On web, url_launcher always opens externally regardless of LaunchMode.
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      debugPrint('StripeProvider(web): launchUrl failed for $url');
    }

    // providerReference = payment_id (UUID) so the polling screen can
    // call checkStatus(paymentId) via the unified_payments table.
    return PaymentSession(
      providerReference: paymentId,
      redirectUrl: url,
      status: PaymentStatus.pending,
      metadata: {'payment_id': paymentId, 'checkout_url': url},
    );
  }

  /// Checks payment status by querying the unified_payments table directly.
  /// Uses the payment_id UUID as the lookup key.
  @override
  Future<PaymentStatus> checkStatus(String providerReference) async {
    final client = Supabase.instance.client;
    try {
      // providerReference is the unified_payments UUID for web checkout path
      final row = await client
          .from('unified_payments')
          .select('status')
          .eq('id', providerReference)
          .maybeSingle();

      if (row != null) {
        return PaymentStatus.fromString(
            row['status'] as String? ?? 'pending');
      }
    } catch (e) {
      debugPrint('StripeProvider(web).checkStatus error: $e');
    }
    return PaymentStatus.pending;
  }
}
