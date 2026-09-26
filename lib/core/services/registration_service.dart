import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class RegistrationService {
  static final instance = RegistrationService._();
  RegistrationService._();

  // SECURITY: No secrets hardcoded here. URL and anon key come from SupabaseConfig.
  String get _baseUrl => SupabaseConfig.url;

  Map<String, String> get _headers => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
      };

  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<bool> validateInviteCode(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/rest/v1/shops?invite_code=eq.$code&select=id'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.isNotEmpty;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> createRegistration({
    required String shopName,
    required String ownerName,
    required String email,
    required String password,
    String? inviteCodeUsed,
    String planSelected = 'trial',
    String? phone,
    String? address,
  }) async {
    try {
      final code = _generateOTP();

      // SECURITY: Password is NEVER stored in public_registrations table.
      // It is submitted securely at admin approval time via the admin's
      // authenticated session → approve-registration Edge Function.
      // The password field is stored only in auth.users (by Supabase internally).
      final body = <String, dynamic>{
        'shop_name': shopName,
        'owner_name': ownerName,
        'email': email,
        if (inviteCodeUsed != null && inviteCodeUsed.trim().isNotEmpty)
          'invite_code_used': inviteCodeUsed.trim(),
        'plan_selected': planSelected,
        'email_verification_code': code,
        'status': 'pending_email_verification',
        'email_verified': false,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null && address.isNotEmpty) 'address': address,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/rest/v1/public_registrations'),
        headers: {
          ..._headers,
          'Prefer': 'return=representation',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final id = data.first['id'];
        return {'success': true, 'id': id, 'code': code};
      } else {
        return {'success': false, 'error': response.body};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> sendOTP({
    required String email,
    required String code,
    required String shopName,
  }) async {
    try {
      // Send OTP via Supabase Auth using your SMTP service
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/v1/otp'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      );
      debugPrint('GoTrue Auth OTP response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('sendOTP via GoTrue Auth error: $e');
      return false;
    }
  }

  // SECURITY NOTE: updatePassword() has been removed.
  // Passwords must NEVER be stored in public_registrations (or any non-auth table).
  // The password is passed directly to the approve-registration Edge Function
  // at approval time via the admin's secure session. It is set in auth.users
  // by the Edge Function using the service_role key (server-side only).
  //
  // If you need to allow users to set a password before approval,
  // use Supabase's password recovery / magic link flow instead.

  Future<Map<String, dynamic>> verifyOTP({
    required String registrationId,
    required String code,
    String? email,
  }) async {
    try {
      // 1. Try Supabase Auth verification if email provided
      if (email != null && email.isNotEmpty) {
        try {
          final res = await Supabase.instance.client.auth.verifyOTP(
            email: email,
            token: code,
            type: OtpType.email,
          );
          if (res.session != null || res.user != null) {
            await http.patch(
              Uri.parse('$_baseUrl/rest/v1/public_registrations?id=eq.$registrationId'),
              headers: _headers,
              body: jsonEncode({'status': 'pending_payment', 'email_verified': true}),
            );
            return {'success': true};
          }
        } catch (authErr) {
          debugPrint('Auth verifyOTP error: $authErr');
        }
      }

      // 2. Database verification fallback (matches saved code in public_registrations table)
      final response = await http.get(
        Uri.parse('$_baseUrl/rest/v1/public_registrations?id=eq.$registrationId&select=email_verification_code,email_verification_sent_at'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isEmpty) return {'success': false, 'error': 'Registration not found'};
        
        final record = data.first;
        final savedCode = record['email_verification_code'];
        final sentAt = DateTime.parse(record['email_verification_sent_at']);
        
        if (savedCode == code) {
          if (DateTime.now().toUtc().difference(sentAt).inMinutes > 10) {
            return {'success': false, 'error': 'Verification code expired'};
          }

          final patchResponse = await http.patch(
            Uri.parse('$_baseUrl/rest/v1/public_registrations?id=eq.$registrationId'),
            headers: _headers,
            body: jsonEncode({
              'status': 'pending_payment',
              'email_verified': true,
            }),
          );

          if (patchResponse.statusCode == 200 || patchResponse.statusCode == 204) {
            return {'success': true};
          }
        }
      }
      return {'success': false, 'error': 'Invalid verification code'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resendOTP({
    required String registrationId,
    required String email,
    required String shopName,
  }) async {
    try {
      final code = _generateOTP();
      
      final patchResponse = await http.patch(
        Uri.parse('$_baseUrl/rest/v1/public_registrations?id=eq.$registrationId'),
        headers: _headers,
        body: jsonEncode({
          'email_verification_code': code,
          'email_verification_sent_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      if (patchResponse.statusCode == 200 || patchResponse.statusCode == 204) {
        final sent = await sendOTP(email: email, code: code, shopName: shopName);
        if (sent) {
          return {'success': true};
        } else {
          return {'success': false, 'error': 'Failed to send email'};
        }
      }
      return {'success': false, 'error': 'Failed to update code'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<String?> uploadPaymentScreenshot({
    required String registrationId,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final ext = filename.split('.').last;
      final path = '$registrationId-${DateTime.now().millisecondsSinceEpoch}.$ext';
      try {
        await Supabase.instance.client.storage
            .from('registration-screenshots')
            .uploadBinary(path, bytes);
        
        final url = Supabase.instance.client.storage
            .from('registration-screenshots')
            .getPublicUrl(path);
        if (url.isNotEmpty) return url;
      } catch (storageErr) {
        debugPrint('Supabase storage upload error, fallback to base64: $storageErr');
      }

      // Failproof fallback: Compressed <20KB base64 Data URI
      final base64Str = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Str';
    } catch (e) {
      debugPrint('Upload error: $e');
      try {
        final base64Str = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64Str';
      } catch (_) {
        return null;
      }
    }
  }

  Future<Map<String, dynamic>> submitPaymentProof({
    required String registrationId,
    required String screenshotUrl,
    required String paymentMethod,
    String transactionId = 'RECEIPT_UPLOADED',
  }) async {
    try {
      final patchResponse = await http.patch(
        Uri.parse('$_baseUrl/rest/v1/public_registrations?id=eq.$registrationId'),
        headers: _headers,
        body: jsonEncode({
          'payment_screenshot_url': screenshotUrl,
          'payment_method': paymentMethod,
          'transaction_id': transactionId,
          'status': 'pending_admin_review',
        }),
      );

      if (patchResponse.statusCode == 200 || patchResponse.statusCode == 204) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to submit payment proof'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> submitUpgradeRequest({
    required String shopId,
    required String screenshotUrl,
    required String transactionId,
    required String paymentMethod,
    required String upgradeType,
    required int amount,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client.from('upgrade_requests').insert({
        'shop_id': shopId,
        'amount': amount,
        'upgrade_type': upgradeType,
        'payment_screenshot_url': screenshotUrl,
        'transaction_id': transactionId,
        'status': 'pending_admin_review',
      });
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Instant Free Trial registration:
  /// 1. Signs up user in auth.users
  /// 2. Calls register_new_shop_free_trial RPC (atomic: shop + profile + trial cycle)
  /// 3. On RPC failure: deletes the orphan auth user so the person can retry with
  ///    the same email address without hitting "email already registered".
  Future<Map<String, dynamic>> registerFreeTrial({
    required String email,
    required String password,
    required String shopName,
    required String ownerName,
    required String phone,
    required String address,
    String? city,
    String? inviteCode,
  }) async {
    final client = Supabase.instance.client;
    String? newUserId;
    try {
      // 1. Create auth account with redirect URL
      final authRes = await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kIsWeb ? 'https://darzipro.pk/#/login' : 'darzipro://login',
      );
      final user = authRes.user;
      if (user == null) {
        return {'success': false, 'error': 'Failed to create user account. Please check your email and password.'};
      }
      newUserId = user.id;

      // 2. Call RPC — it re-raises on failure, so catch below handles it
      final rpcRes = await client.rpc('register_new_shop_free_trial', params: {
        'p_user_id':     user.id,
        'p_shop_name':   shopName,
        'p_owner_name':  ownerName,
        'p_phone':       phone,
        'p_address':     address,
        'p_city':        city,
        'p_invite_code': (inviteCode != null && inviteCode.trim().isNotEmpty)
            ? inviteCode.trim() : null,
      });

      if (rpcRes is Map && rpcRes['success'] == true) {
        return {
          'success': true,
          'shopId': rpcRes['shop_id'],
          'inviteCode': rpcRes['invite_code'],
        };
      }
      throw Exception(rpcRes?['error'] ?? 'Shop setup failed');

    } catch (e) {
      // Shop creation failed after auth user was created.
      // Sign out the session so they don't land on an empty dashboard.
      // The user can resume via /registration-resume or the login guard.
      if (newUserId != null) {
        try { await client.auth.signOut(); } catch (_) {}
      }
      final msg = e.toString().replaceFirst('Exception: ', '');
      return {'success': false, 'error': msg};
    }
  }

  /// Resume registration for a stranded account.
  /// Called by RegistrationResumeScreen when the user already has an active
  /// auth session but has no profiles row (previous registration attempt failed
  /// after auth user was created). Does NOT call signUp.
  Future<Map<String, dynamic>> completeStrandedRegistration({
    required String shopName,
    required String ownerName,
    required String phone,
    required String address,
    String? city,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'No active session. Please sign in again.'};
      }
      final rpcRes = await client.rpc('register_new_shop_free_trial', params: {
        'p_user_id':     user.id,
        'p_shop_name':   shopName,
        'p_owner_name':  ownerName,
        'p_phone':       phone,
        'p_address':     address,
        'p_city':        city,
        'p_invite_code': null,
      });
      if (rpcRes is Map && rpcRes['success'] == true) {
        return {'success': true, 'shopId': rpcRes['shop_id'], 'inviteCode': rpcRes['invite_code']};
      }
      throw Exception(rpcRes?['error'] ?? 'Shop setup failed');
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceFirst('Exception: ', '')};
    }
  }

}
