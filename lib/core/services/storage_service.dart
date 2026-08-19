import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class StorageService {
  static final instance = StorageService._();
  StorageService._();

  static const int freeLimitBytes = 1500000;        // 1.5MB
  static const int warningThresholdBytes = 1200000;   // 1.2MB (80%)

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
        Uri.parse('${SupabaseConfig.url}/rest/v1/shops?id=eq.$shopId&select=storage_used_bytes,storage_addon_active,storage_addon_expires_at,bundled_storage_expires_at,storage_addon_type'),
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
    };
  }

  /// Check if shop can upload [newBytes] more bytes.
  /// Unlimited storage applies if EITHER active add-on OR unexpired 3-year bundled storage is valid.
  Future<Map<String, dynamic>> checkCanUpload(String shopId, int newBytes) async {
    final info = await getStorageInfo(shopId);
    final bool addonActive = info['storage_addon_active'] as bool? ?? false;
    final int used = info['storage_used_bytes'] as int? ?? 0;
    final now = DateTime.now();

    // Check add-on expiry
    bool effectiveAddon = addonActive;
    if (addonActive) {
      final expiresStr = info['storage_addon_expires_at'] as String?;
      if (expiresStr != null) {
        final expires = DateTime.parse(expiresStr);
        if (now.isAfter(expires)) effectiveAddon = false;
      }
    }

    // Check 3-year bundled storage expiry
    bool bundledValid = false;
    final bundledExpiresStr = info['bundled_storage_expires_at'] as String?;
    if (bundledExpiresStr != null) {
      final bundledExpires = DateTime.parse(bundledExpiresStr);
      if (now.isBefore(bundledExpires)) bundledValid = true;
    }

    if (effectiveAddon || bundledValid) {
      return {'canUpload': true, 'used': used, 'addonActive': true};
    }

    if (used + newBytes > freeLimitBytes) {
      return {
        'canUpload': false,
        'reason': 'Storage full (Limited Storage reached). Subscribe to unlimited storage for Rs 1,200/month or Rs 10,000/year.',
        'used': used,
        'addonActive': false,
      };
    }


    return {'canUpload': true, 'used': used, 'addonActive': false};
  }

  /// Increments storage_used_bytes by [addedBytes] for [shopId].
  Future<void> incrementStorageUsed(String shopId, int addedBytes) async {
    try {
      final info = await getStorageInfo(shopId);
      final current = info['storage_used_bytes'] as int? ?? 0;
      final newValue = current + addedBytes;

      await http.patch(
        Uri.parse('${SupabaseConfig.url}/rest/v1/shops?id=eq.$shopId'),
        headers: _headers,
        body: jsonEncode({'storage_used_bytes': newValue}),
      );
    } catch (e) {
      debugPrint('StorageService.incrementStorageUsed error: $e');
    }
  }

  /// Submit storage addon payment for admin review.
  /// Supports both 'monthly' (1200) and 'annual' (10000).
  Future<Map<String, dynamic>> submitStorageAddonPayment({
    required String shopId,
    required String screenshotUrl,
    required String paymentMethod,
    required String transactionId,
    String addonType = 'monthly', // 'monthly' or 'annual'
    int amount = 1200,            // 1200 or 10000
  }) async {
    try {
      final now = DateTime.now();
      final periodMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final client = Supabase.instance.client;
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
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
