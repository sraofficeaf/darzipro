import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class StorageService {
  static final instance = StorageService._();
  StorageService._();

  final Map<String, int> _planStorageLimitsBytes = {};
  DateTime? _planStorageLimitsTime;

  /// Fetches storage allowance in bytes for a plan code from subscription_plans table.
  /// Reads directly from single source of truth in database (subscription_plans.storage_allowance_bytes).
  Future<int> getStorageLimitBytesForPlan(String planCode) async {
    final now = DateTime.now();
    if (_planStorageLimitsBytes.isNotEmpty &&
        _planStorageLimitsTime != null &&
        now.difference(_planStorageLimitsTime!).inMinutes < 5) {
      if (_planStorageLimitsBytes.containsKey(planCode)) {
        return _planStorageLimitsBytes[planCode]!;
      }
    }

    try {
      final res = await http.get(
        Uri.parse('${SupabaseConfig.url}/rest/v1/subscription_plans?select=code,storage_allowance_bytes'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        for (final row in data) {
          final c = row['code']?.toString() ?? '';
          final bytes = int.tryParse(row['storage_allowance_bytes']?.toString() ?? '');
          if (c.isNotEmpty && bytes != null) {
            _planStorageLimitsBytes[c] = bytes;
          }
        }
        _planStorageLimitsTime = now;
        if (_planStorageLimitsBytes.containsKey(planCode)) {
          return _planStorageLimitsBytes[planCode]!;
        }
      }
    } catch (e) {
      debugPrint('StorageService.getStorageLimitBytesForPlan error: $e');
    }

    return _planStorageLimitsBytes[planCode] ?? 0;
  }

  /// Fetches storage allowance in MB for a plan code from subscription_plans table.
  Future<int> getStorageLimitMbForPlan(String planCode) async {
    final bytes = await getStorageLimitBytesForPlan(planCode);
    return bytes ~/ (1024 * 1024);
  }

  /// Fetches storage add-on capacity in GB from app_settings (default 1 GB).
  Future<int> getStorageAddonGb() async {
    try {
      final res = await http.get(
        Uri.parse('${SupabaseConfig.url}/rest/v1/app_settings?key=eq.storage_addon_gb&select=value'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final val = int.tryParse(data.first['value']?.toString() ?? '');
          if (val != null && val > 0) return val;
        }
      }
    } catch (e) {
      debugPrint('StorageService.getStorageAddonGb error: $e');
    }
    return 1;
  }

  /// Calculates the effective total storage limit in MB for a shop,
  /// dynamically including base plan allowance and any active storage add-on
  /// read from app_settings (storage_addon_gb * 1024 MB).
  Future<int> getEffectiveStorageLimitMbForShop(String shopId) async {
    try {
      final res = await http.get(
        Uri.parse('${SupabaseConfig.url}/rest/v1/shops?id=eq.$shopId&select=plan_code,storage_addon_active,storage_addon_expires_at,lifetime_access,lifetime_storage_limit_bytes,founding_storage_limit_bytes'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final shop = Map<String, dynamic>.from(data.first);
          final lifetimeBytes = shop['lifetime_storage_limit_bytes'] as int?;
          if (lifetimeBytes != null && lifetimeBytes > 0) {
            return lifetimeBytes ~/ (1024 * 1024);
          }
          final foundingBytes = shop['founding_storage_limit_bytes'] as int?;
          if (foundingBytes != null && foundingBytes > 0) {
            return foundingBytes ~/ (1024 * 1024);
          }

          final planCode = (shop['plan_code'] as String?) ?? 'trial';
          final planBaseMb = await getStorageLimitMbForPlan(planCode);

          bool addonActive = shop['storage_addon_active'] == true;
          if (addonActive && shop['storage_addon_expires_at'] != null) {
            final expires = DateTime.tryParse(shop['storage_addon_expires_at'].toString());
            if (expires != null && DateTime.now().isAfter(expires)) {
              addonActive = false;
            }
          }

          final addonGb = await getStorageAddonGb();
          final additionalMb = addonActive ? (addonGb * 1024) : 0;
          return planBaseMb + additionalMb;
        }
      }
    } catch (e) {
      debugPrint('StorageService.getEffectiveStorageLimitMbForShop error: $e');
    }
    return await getStorageLimitMbForPlan('trial');
  }

  /// Legacy alias for compatibility.
  Future<int> getBaseStorageLimitMb({String planCode = 'trial'}) async {
    return getStorageLimitMbForPlan(planCode);
  }

  /// Fetches base storage allowance in bytes.
  Future<int> getBaseStorageLimitBytes({String planCode = 'trial'}) async {
    return getStorageLimitBytesForPlan(planCode);
  }

  // SECURITY: Service role key is NEVER stored in client code.
  // All requests use the anon key + authenticated user JWT.
  // Admin-level storage ops go through Edge Functions server-side.
  String get _authToken =>
      Supabase.instance.client.auth.currentSession?.accessToken ??
      SupabaseConfig.anonKey;

  Map<String, String> get _headers => {
    'apikey': SupabaseConfig.anonKey,
    'Authorization': 'Bearer $_authToken',
    'Content-Type': 'application/json',
  };

  /// Returns storage info for a shop.
  Future<Map<String, dynamic>> getStorageInfo(String shopId) async {
    try {
      final res = await http.get(
        Uri.parse('${SupabaseConfig.url}/rest/v1/shops?id=eq.$shopId&select=storage_used_bytes,storage_addon_active,storage_addon_expires_at,bundled_storage_expires_at,storage_addon_type,plan_code'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) return Map<String, dynamic>.from(data.first);
      }
    } catch (e) {
      debugPrint('StorageService.getStorageInfo error: $e');
    }
    return {
      'storage_used_bytes': 0,
      'storage_addon_active': false,
      'storage_addon_expires_at': null,
      'bundled_storage_expires_at': null,
      'storage_addon_type': null,
      'plan_code': 'trial',
    };
  }

  /// Check if shop can upload [newBytes] more bytes.
  /// Storage limit is based on plan allowance + active add-on (+1 GB).
  Future<Map<String, dynamic>> checkCanUpload(String shopId, int newBytes) async {
    final info = await getStorageInfo(shopId);
    final int used = info['storage_used_bytes'] as int? ?? 0;
    final totalLimitMb = await getEffectiveStorageLimitMbForShop(shopId);
    final totalLimitBytes = totalLimitMb * 1024 * 1024;

    if (used + newBytes > totalLimitBytes) {
      final usedMbStr = (used / (1024 * 1024)).toStringAsFixed(1);
      final limitDisplay = totalLimitMb >= 1024 && totalLimitMb % 1024 == 0
          ? '${totalLimitMb ~/ 1024} GB'
          : '$totalLimitMb MB';
      return {
        'canUpload': false,
        'reason': 'Storage limit reached ($usedMbStr MB / $limitDisplay). Add 1 GB storage for Rs 250/month or upgrade your plan.',
        'used': used,
        'limitBytes': totalLimitBytes,
        'addonActive': info['storage_addon_active'] == true,
      };
    }

    return {
      'canUpload': true,
      'used': used,
      'limitBytes': totalLimitBytes,
      'addonActive': info['storage_addon_active'] == true,
    };
  }

  /// Increments storage_used_bytes by [addedBytes] for [shopId].
  Future<void> incrementStorageUsed(String shopId, int addedBytes) async {
    try {
      final client = Supabase.instance.client;
      final shop = await client.from('shops').select('storage_used_bytes').eq('id', shopId).maybeSingle();
      final current = (shop?['storage_used_bytes'] as int?) ?? 0;
      final newValue = current + addedBytes;
      await client.from('shops').update({'storage_used_bytes': newValue}).eq('id', shopId);
    } catch (e) {
      debugPrint('StorageService.incrementStorageUsed error: $e');
    }
  }

  /// Submit storage addon payment for admin review to unified_payments.
  /// Supports both 'monthly' (250) and 'annual' (2500).
  Future<Map<String, dynamic>> submitStorageAddonPayment({
    required String shopId,
    required String screenshotUrl,
    required String paymentMethod,
    required String transactionId,
    String addonType = 'monthly', // 'monthly' or 'annual'
    int amount = 250,             // 250 or 2500
  }) async {
    try {
      final now = DateTime.now();
      final periodMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final client = Supabase.instance.client;
      final purpose = addonType == 'annual' ? 'storageAnnual' : 'storageMonthly';
      final amountMinor = amount * 100;

      // 1. Insert into unified_payments (core multi-provider table)
      await client.from('unified_payments').insert({
        'shop_id': shopId,
        'provider_code': 'manual',
        'purpose': purpose,
        'amount_minor': amountMinor,
        'currency': 'PKR',
        'status': 'awaitingReview',
        'receipt_url': screenshotUrl,
        'manual_transaction_id': transactionId,
        if (transactionId.isNotEmpty) 'provider_reference': transactionId,
        'metadata': {
          'addon_type': addonType,
          'period_month': periodMonth,
          'payment_method': paymentMethod,
        },
      });

      // 2. Backward compatibility insert
      try {
        await client.from('storage_addon_payments').insert({
          'shop_id': shopId,
          'amount': amount,
          'addon_type': addonType,
          'payment_method': paymentMethod,
          'transaction_id': transactionId,
          'payment_screenshot_url': screenshotUrl,
          'period_month': periodMonth,
          'status': 'pending_admin_review',
        });
      } catch (_) {}

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
