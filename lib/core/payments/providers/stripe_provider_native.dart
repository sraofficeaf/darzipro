// Native (Android / iOS / Desktop) Stripe provider.
// Imports flutter_stripe only in this file; never imported on web.
// Selected by the conditional import in stripe_provider.dart
// when dart.library.html is NOT available.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../payment_provider.dart';

/// Stripe payment provider for Android, iOS, and Desktop.
/// - Android / iOS: native Payment Sheet via flutter_stripe.
/// - Windows / macOS / Linux: Stripe Checkout Session (hosted),
///   launched in external browser. flutter_stripe is imported but
///   PaymentSheet APIs are never called on desktop.
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
    // kIsWeb is always false in this file (dart.library.html not available).
    // Desktop → Checkout Session. Mobile → Payment Sheet.
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (!isMobile) {
      return _createCheckoutSession(
        shopId: shopId,
        amountMinor: amountMinor,
        currency: currency,
        purpose: purpose,
        metadata: metadata,
      );
    }

    return _createPaymentSheet(
      shopId: shopId,
      amountMinor: amountMinor,
      currency: currency,
      purpose: purpose,
      metadata: metadata,
    );
  }

  // ── Checkout Session (Desktop) ──────────────────────────────────────────

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

    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      debugPrint('StripeProvider(native).checkout: launchUrl failed for $url');
    }

    return PaymentSession(
      providerReference: paymentId,
      redirectUrl: url,
      status: PaymentStatus.pending,
      metadata: {'payment_id': paymentId, 'checkout_url': url},
    );
  }

  // ── Payment Sheet (Android / iOS) ───────────────────────────────────────

  Future<PaymentSession> _createPaymentSheet({
    required String shopId,
    required int amountMinor,
    required String currency,
    required PaymentPurpose purpose,
    Map<String, dynamic>? metadata,
  }) async {
    final client = Supabase.instance.client;

    // 1. Invoke Edge Function to create PaymentIntent server-side
    final response = await client.functions.invoke(
      'stripe-payment',
      body: {
        'action': 'create-intent',
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
              'Failed to initialize payment')
          : 'Server returned ${response.status}';
      throw Exception(errorMsg);
    }

    final data = response.data as Map<String, dynamic>;
    final clientSecret = data['clientSecret'] as String?;
    final providerReference = (data['providerReference'] as String?) ?? '';
    final publishableKey =
        (data['publishableKey'] as String?) ?? defaultPublishableKey;

    if (clientSecret == null || clientSecret.isEmpty) {
      throw Exception('Payment provider returned empty client secret');
    }

    // 2. Present native Payment Sheet
    try {
      if (publishableKey != null && publishableKey.isNotEmpty) {
        Stripe.publishableKey = publishableKey;
        await Stripe.instance.applySettings();
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Darzi Pro',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF10B981),
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      return PaymentSession(
        providerReference: providerReference,
        clientSecret: clientSecret,
        status: PaymentStatus.succeeded,
        metadata: data,
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return PaymentSession(
          providerReference: providerReference,
          clientSecret: clientSecret,
          status: PaymentStatus.cancelled,
          metadata: {'error': e.error.localizedMessage},
        );
      }
      return PaymentSession(
        providerReference: providerReference,
        clientSecret: clientSecret,
        status: PaymentStatus.failed,
        metadata: {'error': e.error.localizedMessage},
      );
    } catch (e) {
      return PaymentSession(
        providerReference: providerReference,
        clientSecret: clientSecret,
        status: PaymentStatus.failed,
        metadata: {'error': e.toString()},
      );
    }
  }

  // ── Status Check ────────────────────────────────────────────────────────

  @override
  Future<PaymentStatus> checkStatus(String providerReference) async {
    final client = Supabase.instance.client;

    // For the checkout path, providerReference is the unified_payments UUID.
    // For the PaymentSheet path, it is the Stripe PaymentIntent ID.
    // Try by UUID first; fall back to Stripe provider_reference lookup.
    try {
      // UUID lookup (checkout path)
      final byId = await client
          .from('unified_payments')
          .select('status')
          .eq('id', providerReference)
          .maybeSingle();
      if (byId != null) {
        return PaymentStatus.fromString(byId['status'] as String? ?? 'pending');
      }
    } catch (_) {}

    try {
      // PaymentIntent ID lookup (Payment Sheet path)
      final response = await client.functions.invoke(
        'stripe-payment',
        body: {
          'action': 'check-status',
          'provider_reference': providerReference,
        },
      );
      if (response.status == 200 && response.data is Map) {
        final statusStr =
            response.data['status'] as String? ?? 'pending';
        return PaymentStatus.fromString(statusStr);
      }
    } catch (_) {}

    try {
      // Fallback: check unified_payments by provider_reference
      final row = await client
          .from('unified_payments')
          .select('status')
          .eq('provider_reference', providerReference)
          .maybeSingle();
      if (row != null) {
        return PaymentStatus.fromString(
            row['status'] as String? ?? 'pending');
      }
    } catch (_) {}

    return PaymentStatus.pending;
  }
}
