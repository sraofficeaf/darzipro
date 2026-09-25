/// Stripe payment provider — platform-adaptive entry point.
///
/// On Flutter Web (dart.library.html available):
///   → stripe_provider_web.dart — pure Dart, no flutter_stripe import.
///     Uses Stripe Checkout Session (hosted page in new tab).
///
/// On Android / iOS / Desktop (dart.library.io, not web):
///   → stripe_provider_native.dart — imports flutter_stripe.
///     Android/iOS: native Payment Sheet.
///     Desktop: Stripe Checkout Session (external browser).
///
/// This file must contain NO implementation code. It is purely a
/// conditional-import router that re-exports StripePaymentProvider.
/// The `dart:io` crash on web is prevented because flutter_stripe
/// (which unconditionally imports dart:io via method_channel_stripe.dart)
/// is only ever loaded by stripe_provider_native.dart, which is never
/// compiled into a web build.

library;

export 'stripe_provider_web.dart'
    if (dart.library.io) 'stripe_provider_native.dart';

