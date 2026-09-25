import 'package:intl/intl.dart';

/// Helper functions for handling integer minor units (paisa / cents)
/// and converting to display formatting without floating point issues.
class CurrencyUtils {
  CurrencyUtils._();

  /// Formats an integer amount in minor units to user-facing string.
  /// Example: 50000 minor PKR -> "Rs 500", 1250 minor USD -> "$12.50".
  static String formatMinor(int amountMinor, String currency) {
    final cur = currency.toUpperCase();
    final majorVal = amountMinor / 100.0;

    switch (cur) {
      case 'PKR':
        final formatted = NumberFormat('#,##0', 'en_US').format(majorVal.round());
        return 'Rs $formatted';
      case 'USD':
        final formatted = NumberFormat('#,##0.00', 'en_US').format(majorVal);
        return '\$$formatted';
      case 'EUR':
        final formatted = NumberFormat('#,##0.00', 'en_US').format(majorVal);
        return '€$formatted';
      case 'GBP':
        final formatted = NumberFormat('#,##0.00', 'en_US').format(majorVal);
        return '£$formatted';
      case 'AED':
        final formatted = NumberFormat('#,##0.00', 'en_US').format(majorVal);
        return 'AED $formatted';
      default:
        final formatted = NumberFormat('#,##0.00', 'en_US').format(majorVal);
        return '$cur $formatted';
    }
  }

  /// Converts a major numeric amount (e.g. from user input) to integer minor units.
  static int toMinor(num majorAmount) {
    return (majorAmount * 100).round();
  }

  /// Converts minor integer amount to major decimal.
  static double toMajor(int minorAmount) {
    return minorAmount / 100.0;
  }

  /// Returns the standard currency symbol.
  static String getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'PKR':
        return 'Rs';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'AED';
      default:
        return currency.toUpperCase();
    }
  }
}
