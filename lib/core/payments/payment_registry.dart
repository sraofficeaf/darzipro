import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'payment_provider.dart';
import 'providers/manual_provider.dart';
import 'providers/stripe_provider.dart';

/// Registry and selector for payment providers based on shop locale,
/// currency, and database enablement configuration.
class PaymentRegistry {
  PaymentRegistry._();

  static final Map<String, PaymentProvider> _registry = {
    'manual': const ManualPaymentProvider(),
    'stripe': const StripePaymentProvider(),
  };

  /// Allows registering custom or future payment providers dynamically.
  static void registerProvider(PaymentProvider provider) {
    _registry[provider.code] = provider;
  }

  /// Retrieves an instantiated provider by code.
  static PaymentProvider? getProvider(String code) {
    return _registry[code];
  }

  /// Returns the list of enabled, filtered providers applicable for the given
  /// shop [countryCode] and [currency].
  ///
  /// Guarantee: Manual payment provider is ALWAYS returned as a fallback if the
  /// filtered list is empty or an unexpected error occurs.
  static Future<List<PaymentProvider>> availableFor({
    required String countryCode,
    required String currency,
  }) async {
    final curUpper = currency.toUpperCase().trim();
    final countryUpper = countryCode.toUpperCase().trim();

    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('payment_providers')
          .select('code, display_name, enabled, supported_currencies, allowed_countries, priority, is_instant')
          .eq('enabled', true)
          .order('priority', ascending: true);

      final List<PaymentProvider> result = [];

      for (final row in rows) {
        final code = row['code'] as String? ?? '';
        final provider = _registry[code];
        if (provider == null) continue;

        final rawCountries = row['allowed_countries'];
        final List<String> allowedCountries = rawCountries is List
            ? rawCountries.map((e) => e.toString().toUpperCase().trim()).toList()
            : ['*'];

        final rawCurrencies = row['supported_currencies'];
        final List<String> supportedCurrencies = rawCurrencies is List
            ? rawCurrencies.map((e) => e.toString().toUpperCase().trim()).toList()
            : ['*'];

        final countryMatches = allowedCountries.contains('*') ||
            allowedCountries.contains(countryUpper);

        final currencyMatches = supportedCurrencies.contains('*') ||
            supportedCurrencies.contains(curUpper);

        if (countryMatches && currencyMatches) {
          result.add(provider);
        }
      }

      // Guarantee: Always provide manual fallback
      if (result.isEmpty) {
        debugPrint('PaymentRegistry: No providers matched ($countryUpper / $curUpper), falling back to Manual.');
        return [_registry['manual'] ?? const ManualPaymentProvider()];
      }

      return result;
    } catch (e) {
      debugPrint('PaymentRegistry.availableFor error: $e, using Manual fallback.');
      return [_registry['manual'] ?? const ManualPaymentProvider()];
    }
  }
}
