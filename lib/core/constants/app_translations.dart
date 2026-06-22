import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/app_providers.dart';

class AppTranslations {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'dashboard': 'Dashboard',
      'clients': 'Clients',
      'orders': 'Orders',
      'measurements': 'Measurements',
      'reports': 'Reports',
      'settings': 'Settings',
      'clients_found': 'clients found',
      'loading_clients': 'Loading clients...',
      'error_loading_clients': 'Error loading clients',
      'add_client': 'Add Client',
      'search_placeholder': 'Search by name or phone…',
      'all': 'All',
      'men': 'Men',
      'women': 'Women',
      'child': 'Child',
      'no_clients': 'No Clients Found',
      'no_clients_sub': 'Add a new client or try a different search.',
      'orders_count': 'orders',
      'dark_mode': 'Dark Mode',
      'currently_dark': 'Currently dark',
      'currently_light': 'Currently light',
      'language': 'Language',
      'logout': 'Logout',
      'sign_out': 'Sign out of this device',
      'shop_name': 'Shop Name',
      'address': 'Address',
      'phone_number': 'Phone Number',
      'shop_profile': 'SHOP PROFILE',
      'appearance': 'APPEARANCE',
      'measurement_templates': 'MEASUREMENT TEMPLATES',
      'printing': 'PRINTING',
      'account': 'ACCOUNT',
      // Dashboard keys
      'total_clients': 'Total Clients',
      'pending_orders': 'Pending Orders',
      'ready_orders': 'Ready Orders',
      'urgent_orders': 'Urgent Orders',
      'revenue_this_month': 'Revenue This Month',
      'revenue_today': 'Revenue Today',
      'revenue_weekly_trend': 'Revenue Weekly Trend',
      // Orders keys
      'active_orders': 'Active Orders',
      'add_order': 'New Order',
      'search_orders': 'Search orders...',
      // Settings keys
      'change_language': 'Change Language',
      'profile': 'Profile',
    },
    'ur': {
      'dashboard': 'ڈیش بورڈ',
      'clients': 'گاہک',
      'orders': 'آرڈرز',
      'measurements': 'پیمائش',
      'reports': 'رپورٹس',
      'settings': 'ترتیبات',
      'clients_found': 'گاہک ملے',
      'loading_clients': 'گاہک لوڈ ہو رہے ہیں...',
      'error_loading_clients': 'گاہک لوڈ کرنے میں خرابی',
      'add_client': 'نیا گاہک',
      'search_placeholder': 'نام یا فون نمبر تلاش کریں...',
      'all': 'تمام',
      'men': 'مردانہ',
      'women': 'زنانه',
      'child': 'بچوں کا',
      'no_clients': 'کوئی گاہک نہیں ملا',
      'no_clients_sub': 'نیا گاہک شامل کریں یا تلاش تبدیل کریں۔',
      'orders_count': 'آرڈرز',
      'dark_mode': 'ڈارک موڈ',
      'currently_dark': 'ڈارک موڈ آن ہے',
      'currently_light': 'ڈارک موڈ آف ہے',
      'language': 'زبان',
      'logout': 'لاگ آؤٹ',
      'sign_out': 'ڈیوائس سے لاگ آؤٹ کریں',
      'shop_name': 'دکان کا نام',
      'address': 'پتہ',
      'phone_number': 'فون نمبر',
      'shop_profile': 'دکان کی تفصیلات',
      'appearance': 'ظاہری شکل',
      'measurement_templates': 'پیمائش کے ٹیمپلیٹس',
      'printing': 'پرنٹنگ',
      'account': 'اکاؤنٹ',
      // Dashboard keys
      'total_clients': 'کل گاہک',
      'pending_orders': 'باقی آرڈرز',
      'ready_orders': 'تیار آرڈرز',
      'urgent_orders': 'ارجنٹ آرڈرز',
      'revenue_this_month': 'اس مہینے کی آمدنی',
      'revenue_today': 'آج کی آمدنی',
      'revenue_weekly_trend': 'ہفتہ وار رجحان',
      // Orders keys
      'active_orders': 'فعال آرڈرز',
      'add_order': 'نیا آرڈر',
      'search_orders': 'آرڈر تلاش کریں...',
      // Settings keys
      'change_language': 'زبان تبدیل کریں',
      'profile': 'پروفائل',
    }
  };

  static String translate(String key, String languageCode) {
    final langValues = _localizedValues[languageCode] ?? _localizedValues['en']!;
    return langValues[key] ?? key;
  }
}

extension LocalizedContext on BuildContext {
  String translate(String key) {
    try {
      final container = ProviderScope.containerOf(this);
      final lang = container.read(localeProvider);
      return AppTranslations.translate(key, lang);
    } catch (_) {
      return AppTranslations.translate(key, 'en');
    }
  }
}
