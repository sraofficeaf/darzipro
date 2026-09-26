import 'dart:convert';
import 'dart:math';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class AdminService {
  static final AdminService instance = AdminService._internal();
  AdminService._internal();

  String? currentAdminEmail;

  SupabaseClient get client => Supabase.instance.client;

  Map<String, String> get _adminHeaders {
    final token = client.auth.currentSession?.accessToken ?? SupabaseConfig.anonKey;
    return {
      'Authorization': 'Bearer $token',
      'apikey': SupabaseConfig.anonKey,
      'Content-Type': 'application/json',
    };
  }

  Map<String, String> get _restHeaders => {
        ..._adminHeaders,
        'Prefer': 'return=representation',
      };

  Uri _authUri(String path) =>
      Uri.parse('${SupabaseConfig.url}/auth/v1$path');

  Uri _restUri(String path) =>
      Uri.parse('${SupabaseConfig.url}/rest/v1$path');

  Uri _functionUri(String path) =>
      Uri.parse('${SupabaseConfig.url}/functions/v1$path');

  Future<Map<String, dynamic>> _callAdminUsersEdgeFunction(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        _functionUri('/admin-users'),
        headers: _adminHeaders,
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      debugPrint('admin-users Edge Function failed: ${res.statusCode} ${res.body}');
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return {'success': false, 'error': 'Server error: ${res.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error invoking admin-users Edge Function: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<dynamic> _callAdminRpc(String fnName, [Map<String, dynamic>? params]) async {
    try {
      final res = await http.post(
        _restUri('/rpc/$fnName'),
        headers: _adminHeaders,
        body: jsonEncode(params ?? {}),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      debugPrint('Admin RPC $fnName failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('Error calling admin RPC $fnName: $e');
    }
    return null;
  }

  // =========================================================================
  // ── ADMIN LOGIN ───────────────────────────────────────────────────────────
  // =========================================================================

  Future<Map<String, dynamic>?> loginAdmin(
      String email, String password) async {
    try {
      // Step 1: Create a real Supabase Auth session first so that subsequent
      // calls have a valid JWT to pass the RLS check on admin_users table.
      try {
        await client.auth.signInWithPassword(email: email, password: password);
      } catch (authErr) {
        debugPrint('Admin Supabase auth sign-in error: $authErr');
        return null;
      }

      // Step 2: Fetch admin_users row to verify role/permissions and check bcrypt password
      final response = await client
          .from('admin_users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) {
        // If not found in admin_users, sign out immediately to revoke session
        await client.auth.signOut();
        return null;
      }

      final storedHash = response['password_hash'] as String?;
      if (storedHash == null || storedHash.isEmpty) {
        await client.auth.signOut();
        return null;
      }

      bool isMatch = false;
      if (storedHash.startsWith('\$2a\$') || storedHash.startsWith('\$2b\$') || storedHash.startsWith('\$2y\$')) {
        isMatch = BCrypt.checkpw(password, storedHash);
      } else {
        final legacySha = sha256.convert(utf8.encode('DARZI_PRO_ADMIN_SALT_2026_V1:$password')).toString();
        isMatch = (storedHash == legacySha) || (storedHash == password);
      }

      if (!isMatch) {
        await client.auth.signOut();
        return null;
      }

      currentAdminEmail = email;

      // Step 3: Async upgrade hash to bcrypt and record last_login
      try {
        final newBcryptHash = BCrypt.hashpw(password, BCrypt.gensalt());
        await client.from('admin_users').update({
          'last_login': DateTime.now().toIso8601String(),
          'password_hash': newBcryptHash,
        }).eq('id', response['id']);
      } catch (_) {}

      return response;
    } catch (e) {
      debugPrint('Admin login error: $e');
    }
    return null;
  }

  // =========================================================================
  // ── USER MANAGEMENT ───────────────────────────────────────────────────────
  // =========================================================================

  Future<List<Map<String, dynamic>>> fetchAllShopUsers() async {
    try {
      final res = await _callAdminUsersEdgeFunction({'action': 'list'});
      if (res['success'] == true && res['users'] is List) {
        return List<Map<String, dynamic>>.from(res['users']);
      }
    } catch (e) {
      debugPrint('Error fetching shop users via edge function: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchAuthUsers() async {
    try {
      final res = await _callAdminUsersEdgeFunction({'action': 'list'});
      if (res['success'] == true && res['users'] is List) {
        return List<Map<String, dynamic>>.from(res['users']);
      }
    } catch (e) {
      debugPrint('Error fetching auth users via edge function: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> createShopUser({
    required String email,
    required String password,
    required String shopName,
    required String ownerName,
    String? phone,
  }) async {
    return await _callAdminUsersEdgeFunction({
      'action': 'create',
      'email': email,
      'password': password,
      'shopName': shopName,
      'ownerName': ownerName,
      'phone': phone,
    });
  }

  Future<bool> blockUser(String userId, {String duration = '876600h'}) async {
    final res = await _callAdminUsersEdgeFunction({
      'action': 'block',
      'userId': userId,
      'duration': duration,
    });
    return res['success'] == true;
  }

  Future<bool> unblockUser(String userId) async {
    final res = await _callAdminUsersEdgeFunction({
      'action': 'unblock',
      'userId': userId,
    });
    return res['success'] == true;
  }

  Future<bool> resendConfirmationEmail(String email) async {
    final res = await _callAdminUsersEdgeFunction({
      'action': 'resend_confirmation',
      'email': email,
    });
    return res['success'] == true;
  }

  Future<bool> confirmUserEmail(String userId) async {
    final res = await _callAdminUsersEdgeFunction({
      'action': 'confirm_email',
      'userId': userId,
    });
    return res['success'] == true;
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      final res = await http.post(
        _authUri('/recover'),
        headers: {'apikey': SupabaseConfig.anonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending password reset: $e');
      return false;
    }
  }

  Future<bool> deleteShopUser(String userId, [String? shopId]) async {
    final res = await _callAdminUsersEdgeFunction({
      'action': 'delete',
      'userId': userId,
    });
    if (res['success'] == true && shopId != null && shopId.isNotEmpty) {
      try {
        await http.delete(
          _restUri('/shops?id=eq.$shopId'),
          headers: _adminHeaders,
        );
      } catch (_) {}
    }
    return res['success'] == true;
  }

  // =========================================================================
  // ── PUBLIC REGISTRATIONS ──────────────────────────────────────────────────
  // =========================================================================

  Future<List<Map<String, dynamic>>> fetchRegistrations([String? status]) async {
    try {
      var url = '/public_registrations?order=created_at.desc';
      if (status != null) url += '&status=eq.$status';
      final res = await http.get(_restUri(url), headers: _adminHeaders);
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching registrations: $e');
    }
    return [];
  }

  /// Approves a pending registration by calling the approve-registration Edge
  /// Function, which uses the service_role key SERVER-SIDE ONLY to create the
  /// auth.users account. The caller's real JWT (from signInWithPassword) is
  /// sent as the Authorization header — the function verifies identity via
  /// auth.getUser() before proceeding. No service role key is ever in this file.
  Future<Map<String, dynamic>> approveRegistration({
    required String id,
    required String shopName,
    required String ownerName,
    required String email,
    required String plan,
    String? inviteCodeUsed,
    String? password,
  }) async {
    try {
      final efUri = Uri.parse('${SupabaseConfig.url}/functions/v1/approve-registration');
      final res = await http.post(
        efUri,
        headers: _adminHeaders,
        body: jsonEncode({
          'id': id,
          'shopName': shopName,
          'ownerName': ownerName,
          'email': email,
          'plan': plan,
          if (inviteCodeUsed != null && inviteCodeUsed.isNotEmpty) 'inviteCodeUsed': inviteCodeUsed,
          if (password != null && password.isNotEmpty) 'password': password,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data;
      }

      // Try to extract error message from response body
      try {
        final errData = jsonDecode(res.body) as Map<String, dynamic>;
        return {
          'success': false,
          'error': errData['error'] ?? 'approve-registration failed (${res.statusCode})',
        };
      } catch (_) {
        return {'success': false, 'error': 'approve-registration failed (${res.statusCode})'};
      }
    } catch (e) {
      debugPrint('Error approving registration: $e');
      return {'success': false, 'error': e.toString()};
    }
  }


  Future<bool> rejectRegistration({
    required String id,
    required String reason,
  }) async {
    try {
      final res = await _callAdminRpc('reject_registration', {
        'p_registration_id': id,
        'p_reason': reason,
      });
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('Error rejecting registration: $e');
      return false;
    }
  }

  /// Reusable function for multi-level invite profit calculation (up to 4 levels).
  /// Walk up the invite chain via invited_by_code.
  /// At level N (1..4), check if ancestor's invite_level_unlocked >= N.
  /// Percentages: Level 1 = 15%, Level 2 = 2.5%, Level 3 = 1.5%, Level 4 = 1.0%.
  Future<void> calculateAndCreateMultilevelProfit({
    required String payingShopId,
    required int paymentAmount,
    required String earningType,
  }) async {
    try {
      final levelPercentages = [0.15, 0.025, 0.015, 0.01];
      String? currentShopId = payingShopId;

      // Fetch platform owner ID once (for deleted shop redirects)
      String? platformOwnerId;
      try {
        final platformRes = await http.get(
          _restUri('/app_settings?key=eq.platform_owner_shop_id&select=value'),
          headers: _adminHeaders,
        );
        if (platformRes.statusCode == 200) {
          final platformData = jsonDecode(platformRes.body) as List;
          if (platformData.isNotEmpty) {
            platformOwnerId = platformData.first['value'] as String?;
          }
        }
      } catch (_) {}

      for (int level = 1; level <= 4; level++) {
        // Fetch current shop's invited_by_code
        final currentShopRes = await http.get(
          _restUri('/shops?id=eq.$currentShopId&select=invited_by_code'),
          headers: _adminHeaders,
        );
        if (currentShopRes.statusCode != 200) break;
        final currentData = jsonDecode(currentShopRes.body) as List;
        if (currentData.isEmpty) break;

        final String? inviterCode = currentData.first['invited_by_code'] as String?;
        if (inviterCode == null || inviterCode.isEmpty) break;

        // Fetch inviter shop — include status to detect deleted shops
        final inviterRes = await http.get(
          _restUri('/shops?invite_code=eq.$inviterCode&select=id,invite_level_unlocked,status'),
          headers: _adminHeaders,
        );
        if (inviterRes.statusCode != 200) break;
        final inviterData = jsonDecode(inviterRes.body) as List;
        if (inviterData.isEmpty) break;

        final inviterShop = inviterData.first as Map<String, dynamic>;
        final String inviterShopId = inviterShop['id'] as String;
        final int inviteLevelUnlocked = (inviterShop['invite_level_unlocked'] as int?) ?? 1;
        final String inviterStatus = (inviterShop['status'] as String?) ?? 'active';

        // Determine earning recipient:
        // - If inviter is deleted → redirect this level's earning to platform account
        // - Continue walking chain PAST deleted shop using its invited_by_code
        final String earningRecipient;
        if (inviterStatus == 'deleted') {
          // Redirect to platform account (if configured), else skip
          if (platformOwnerId != null && platformOwnerId.isNotEmpty) {
            earningRecipient = platformOwnerId;
          } else {
            // Platform not configured — skip this level, continue chain
            currentShopId = inviterShopId;
            continue;
          }
        } else {
          earningRecipient = inviterShopId;
        }

        // If ancestor unlocked level N (inviteLevelUnlocked >= level) → create profit
        // For deleted shops redirected to platform: always create (platform has level 4)
        final bool shouldEarn = inviterStatus == 'deleted'
            ? true // platform always earns
            : inviteLevelUnlocked >= level;

        if (shouldEarn) {
          final earnedAmount = (paymentAmount * levelPercentages[level - 1]).round();
          await http.post(
            _restUri('/profit_earnings'),
            headers: _restHeaders,
            body: jsonEncode({
              'inviter_shop_id': earningRecipient,
              'invited_shop_id': payingShopId,
              'earning_type': earningType,
              'level': level,
              'amount': earnedAmount,
              'status': 'pending',
              'earned_at': DateTime.now().toUtc().toIso8601String(),
            }),
          );
        }

        // Move up to next ancestor
        // Even if this shop was deleted, we continue using ITS invited_by_code
        // so the chain above it (A→B(deleted)→C) still resolves C correctly
        currentShopId = inviterShopId;
      }
    } catch (e) {
      debugPrint('Error in calculateAndCreateMultilevelProfit: $e');
    }
  }


  // =========================================================================
  // ── LICENSES ─────────────────────────────────────────────────────────────
  // =========================================================================

  Future<List<Map<String, dynamic>>> fetchLicenses() async {
    try {
      final List<Map<String, dynamic>> shopsList = [];

      // 1. Fetch real client shops via get_admin_shops_data RPC (SECURITY DEFINER)
      final rpcRes = await _callAdminRpc('get_admin_shops_data');
      if (rpcRes != null && rpcRes is List) {
        final list = List<Map<String, dynamic>>.from(rpcRes);
        return list.where((s) => s['id'] != 'bb800b6f-fd70-4ca7-8b51-3b934d3c18c1').toList();
      }

      // Fallback: Fetch from shops table directly
      final shopsRes = await http.get(
        _restUri('/shops?select=*,profiles(full_name,role),licenses(email,plan,status)&order=created_at.desc'),
        headers: _adminHeaders,
      );

      if (shopsRes.statusCode == 200) {
        final rawShops = jsonDecode(shopsRes.body) as List;
        for (final item in rawShops) {
          final s = Map<String, dynamic>.from(item as Map);
          if (s['id'] == 'bb800b6f-fd70-4ca7-8b51-3b934d3c18c1') continue;
          final profiles = s['profiles'] as List?;
          String ownerName = 'N/A';
          if (profiles != null && profiles.isNotEmpty) {
            final ownerProf = profiles.firstWhere(
              (p) => p['role'] == 'owner',
              orElse: () => profiles.first,
            );
            ownerName = ownerProf['full_name'] as String? ?? 'N/A';
          }

          final lics = s['licenses'] as List?;
          String shopEmail = 'N/A';
          if (lics != null && lics.isNotEmpty) {
            for (final l in lics) {
              final em = l['email'] as String?;
              if (em != null && em.isNotEmpty) {
                shopEmail = em;
                break;
              }
            }
          }

          shopsList.add({
            ...s,
            'email': shopEmail,
            'shop_name': s['name'] ?? 'Shop',
            'shop_owner_name': ownerName,
            'whatsapp_number': s['phone'] ?? 'N/A',
            'plan': s['plan_code'] ?? s['plan'] ?? 'trial',
          });
        }
      }

      // 2. Fetch licenses table entries if any
      final licRes = await http.get(
        _restUri('/licenses?select=*&order=created_at.desc'),
        headers: _adminHeaders,
      );

      if (licRes.statusCode == 200) {
        final rawLics = jsonDecode(licRes.body) as List;
        for (final item in rawLics) {
          final l = Map<String, dynamic>.from(item as Map);
          final exists = shopsList.any((s) =>
              s['id'] == l['id'] ||
              (l['shop_name'] != null &&
                  l['shop_name'].toString().toLowerCase() != 'darzi pro' &&
                  s['shop_name'].toString().toLowerCase() ==
                      l['shop_name'].toString().toLowerCase()));
          if (!exists) {
            shopsList.add(l);
          }
        }
      }

      if (shopsList.isNotEmpty) return shopsList;

      final response = await client
          .from('licenses')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching licenses: $e');
      return [];
    }
  }



  Future<bool> createLicense({
    required String shopName,
    required String ownerName,
    required String city,
    required String whatsapp,
    required String plan,
    required int durationDays,
    required String key,
    required String paymentMethod,
    required int amount,
    required String transactionId,
  }) async {
    try {
      final expiryDate = DateTime.now().add(Duration(days: durationDays));

      final licenseResult = await client.from('licenses').insert({
        'license_key': key,
        'shop_name': shopName,
        'shop_owner_name': ownerName,
        'shop_city': city,
        'whatsapp_number': whatsapp,
        'plan': plan,
        'plan_type': plan,
        'status': 'active',
        'is_active': true,
        'expires_at': expiryDate.toIso8601String(),
        'payment_method': paymentMethod,
        'notes': 'Generated via Admin Panel',
      }).select().single();

      final licenseId = licenseResult['id'];

      await client.from('payments').insert({
        'license_id': licenseId,
        'shop_name': shopName,
        'amount_pkr': amount,
        'payment_method': paymentMethod,
        'transaction_id': transactionId,
        'payment_date': DateTime.now().toIso8601String().split('T')[0],
        'month_paid_for': dateFormatMonthPaidFor(),
        'status': 'confirmed',
        'notes': 'Payment for license $key',
      });

      return true;
    } catch (e) {
      debugPrint('Error generating license: $e');
      return false;
    }
  }

  String dateFormatMonthPaidFor() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[now.month - 1]} ${now.year}';
  }

  Future<bool> extendLicense(String id, int additionalDays) async {
    try {
      final license = await client
          .from('licenses')
          .select('expires_at')
          .eq('id', id)
          .single();
      final currentExpiry = DateTime.parse(license['expires_at'] as String);
      final newExpiry = currentExpiry.add(Duration(days: additionalDays));

      await client.from('licenses').update({
        'expires_at': newExpiry.toIso8601String(),
        'status': newExpiry.isAfter(DateTime.now()) ? 'active' : 'expired',
      }).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('Error extending license: $e');
      return false;
    }
  }

  Future<bool> updateLicenseNotes(String shopId, String notes) async {
    try {
      // 1. Try updating license matching shop_id
      final updated = await client
          .from('licenses')
          .update({'notes': notes})
          .eq('shop_id', shopId)
          .select('id');
      if (updated.isNotEmpty) {
        return true;
      }

      // 2. If no row matched by shop_id, check if passed ID is license primary key id
      final updatedById = await client
          .from('licenses')
          .update({'notes': notes})
          .eq('id', shopId)
          .select('id');
      if (updatedById.isNotEmpty) {
        return true;
      }

      // 3. If no license row exists yet for this shop, create one
      final shop = await client.from('shops').select('name, phone').eq('id', shopId).maybeSingle();
      if (shop != null) {
        final inserted = await client.from('licenses').insert({
          'shop_id': shopId,
          'shop_name': shop['name'] ?? 'Unnamed Shop',
          'phone': shop['phone'] ?? '',
          'notes': notes,
          'status': 'active',
          'license_key': 'LIC-${DateTime.now().millisecondsSinceEpoch}',
        }).select('id');
        return inserted.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating license notes: $e');
      return false;
    }
  }

  Future<bool> deleteLicense(String id) async {
    try {
      await client.from('licenses').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateShopDetails({
    required String shopId,
    required String name,
    required String phone,
    required String address,
    required String email,
  }) async {
    try {
      // 1. Update shops table
      await client.from('shops').update({
        'name': name,
        'phone': phone,
        'address': address,
      }).eq('id', shopId);

      // 2. Update licenses table
      await client.from('licenses').update({
        'shop_name': name,
        'phone': phone,
        'email': email,
      }).eq('shop_id', shopId);

      return true;
    } catch (e) {
      debugPrint('Error updating shop details: $e');
      return false;
    }
  }

  // =========================================================================
  // ── PAYMENTS (with Profit Trigger) ────────────────────────────────────────
  // =========================================================================

  Future<List<Map<String, dynamic>>> fetchPayments() async {
    try {
      final response = await client
          .from('payments')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<bool> addManualPayment({
    required String licenseId,
    required String shopName,
    required int amount,
    required String method,
    required String transactionId,
    required String monthFor,
    required String date,
  }) async {
    try {
      // Insert payment and get ID back
      final paymentResult = await client.from('payments').insert({
        'license_id': licenseId,
        'shop_name': shopName,
        'amount_pkr': amount,
        'payment_method': method,
        'transaction_id': transactionId,
        'payment_date': date,
        'month_paid_for': monthFor,
        'status': 'confirmed',
      }).select().single();

      final paymentId = paymentResult['id'] as String;

      // Extend license by 30 days
      await extendLicense(licenseId, 30);

      // ── Profit trigger ────────────────────────────────────────
      await _triggerMonthlyProfit(
        shopName: shopName,
        licenseId: licenseId,
        paymentId: paymentId,
      );

      return true;
    } catch (e) {
      debugPrint('Error adding manual payment: $e');
      return false;
    }
  }

  Future<void> _triggerMonthlyProfit({
    required String shopName,
    required String licenseId,
    required String paymentId,
  }) async {
    try {
      // Find shop by name
      final shopRes = await http.get(
        _restUri('/shops?name=eq.${Uri.encodeComponent(shopName)}&select=id,invited_by_code'),
        headers: _adminHeaders,
      );
      if (shopRes.statusCode != 200) return;
      final shopList = jsonDecode(shopRes.body) as List;
      if (shopList.isEmpty) return;

      final shopData = shopList.first as Map<String, dynamic>;
      final invitedByCode = shopData['invited_by_code'] as String?;
      final invitedShopId = shopData['id'] as String;

      if (invitedByCode == null || invitedByCode.isEmpty) return;

      // Find inviter shop
      final inviterRes = await http.get(
        _restUri('/shops?invite_code=eq.$invitedByCode&select=id'),
        headers: _adminHeaders,
      );
      if (inviterRes.statusCode != 200) return;
      final inviterList = jsonDecode(inviterRes.body) as List;
      if (inviterList.isEmpty) return;
      final inviterShopId = inviterList.first['id'] as String;

      // Get plan type from license (try 'plan' then 'plan_type')
      final licenseRes = await http.get(
        _restUri('/licenses?id=eq.$licenseId&select=plan,plan_type'),
        headers: _adminHeaders,
      );
      String? planType;
      if (licenseRes.statusCode == 200) {
        final licList = jsonDecode(licenseRes.body) as List;
        if (licList.isNotEmpty) {
          final first = licList.first as Map<String, dynamic>;
          planType = (first['plan'] as String?) ?? (first['plan_type'] as String?);
        }
      }
      if (planType == null || planType.trim().isEmpty) {
        throw StateError('Could not resolve plan type for license $licenseId');
      }

      final earningType = planType == 'business' ? 'monthly_business' : 'monthly_pro';
      final earningAmount = planType == 'business' ? 750 : 200;

      // Create profit_earnings row
      await http.post(
        _restUri('/profit_earnings'),
        headers: _restHeaders,
        body: jsonEncode({
          'inviter_shop_id': inviterShopId,
          'invited_shop_id': invitedShopId,
          'earning_type': earningType,
          'amount': earningAmount,
          'related_payment_id': paymentId,
          'status': 'pending',
        }),
      );

      debugPrint('Profit earning created: Rs $earningAmount for inviter $inviterShopId');
    } catch (e) {
      // Never fail payment due to profit trigger error
      debugPrint('Profit trigger error (non-fatal): $e');
    }
  }

  // =========================================================================
  // ── INVITE / PROFIT MANAGEMENT (Admin) ───────────────────────────────────
  // =========================================================================

  /// Returns grouped pending earnings per inviter shop
  Future<List<Map<String, dynamic>>> fetchAdminPendingEarnings() async {
    try {
      final res = await http.get(
        _restUri('/profit_earnings?status=eq.pending&select=inviter_shop_id,amount,inviter_shop:inviter_shop_id(name)'),
        headers: _adminHeaders,
      );
      if (res.statusCode != 200) return [];

      final List<dynamic> rows = jsonDecode(res.body);
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final row in rows) {
        final shopId = row['inviter_shop_id'] as String;
        final shopName = (row['inviter_shop'] as Map?)?['name'] ?? 'Unknown';
        final amount = row['amount'] as int;

        if (grouped.containsKey(shopId)) {
          grouped[shopId]!['total_pending'] =
              (grouped[shopId]!['total_pending'] as int) + amount;
          grouped[shopId]!['earnings_count'] =
              (grouped[shopId]!['earnings_count'] as int) + 1;
        } else {
          grouped[shopId] = {
            'inviter_shop_id': shopId,
            'inviter_shop_name': shopName,
            'total_pending': amount,
            'earnings_count': 1,
          };
        }
      }

      return grouped.values.toList()
        ..sort((a, b) =>
            (b['total_pending'] as int).compareTo(a['total_pending'] as int));
    } catch (e) {
      debugPrint('Error fetching pending earnings: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAdminPayouts() async {
    try {
      final res = await http.get(
        _restUri('/profit_payouts?select=*,inviter_shop:inviter_shop_id(name)&order=created_at.desc'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching admin payouts: $e');
    }
    return [];
  }

  Future<int> getMinPayoutThreshold() async {
    try {
      final res = await http.get(
        _restUri('/app_settings?key=eq.minimum_payout_threshold'),
        headers: _restHeaders,
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty && list.first['value'] != null) {
          return int.tryParse(list.first['value'].toString()) ?? 1000;
        }
      }
    } catch (e) {
      debugPrint('Error reading min payout threshold: $e');
    }
    return 1000;
  }

  Future<bool> setMinPayoutThreshold(int threshold) async {
    return updateAppSetting('minimum_payout_threshold', threshold.toString());
  }

  Future<int> getPayoutDelayDays() async {
    try {
      final res = await http.get(
        _restUri('/app_settings?key=eq.payout_delay_days'),
        headers: _restHeaders,
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty && list.first['value'] != null) {
          return int.tryParse(list.first['value'].toString()) ?? 0;
        }
      }
    } catch (e) {
      debugPrint('Error reading payout delay days: $e');
    }
    return 0;
  }

  Future<bool> setPayoutDelayDays(int days) async {
    return updateAppSetting('payout_delay_days', days.toString());
  }

  Future<Map<String, dynamic>> getStorageAddonConfig() async {
    final defaultConfig = {
      'storage_monthly_price': 250,
      'storage_monthly_active': true,
      'storage_annual_price': 2500,
      'storage_annual_active': true,
      'storage_addon_gb': 1,
      'storage_profit_percent': 0.0,
    };
    try {
      final res = await http.get(
        _restUri('/app_settings?key=in.(storage_addon_price_monthly,storage_active_monthly,storage_addon_price_annual,storage_active_annual,storage_addon_profit_percent,storage_addon_gb)'),
        headers: _restHeaders,
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final map = {for (var item in list) item['key']: item['value']};
        return {
          'storage_monthly_price': int.tryParse(map['storage_addon_price_monthly']?.toString() ?? '') ?? 250,
          'storage_monthly_active': map['storage_active_monthly'] == 'true',
          'storage_annual_price': int.tryParse(map['storage_addon_price_annual']?.toString() ?? '') ?? 2500,
          'storage_annual_active': map['storage_active_annual'] == 'true',
          'storage_addon_gb': int.tryParse(map['storage_addon_gb']?.toString() ?? '') ?? 1,
          'storage_profit_percent': double.tryParse(map['storage_addon_profit_percent']?.toString() ?? '') ?? 0.0,
        };
      }
    } catch (e) {
      debugPrint('Error reading storage add-on config: $e');
    }
    return defaultConfig;
  }

  Future<bool> setStorageAddonConfig(Map<String, dynamic> config) async {
    try {
      final entries = [
        {'key': 'storage_addon_price_monthly', 'value': config['storage_monthly_price']?.toString() ?? '250'},
        {'key': 'storage_active_monthly', 'value': (config['storage_monthly_active'] ?? true).toString()},
        {'key': 'storage_addon_price_annual', 'value': config['storage_annual_price']?.toString() ?? '2500'},
        {'key': 'storage_active_annual', 'value': (config['storage_active_annual'] ?? true).toString()},
        {'key': 'storage_addon_gb', 'value': (config['storage_addon_gb'] ?? 1).toString()},
        {'key': 'storage_addon_profit_percent', 'value': '0'},
      ];

      for (final entry in entries) {
        final ok = await updateAppSetting(entry['key']!, entry['value']!);
        if (!ok) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error saving storage add-on config: $e');
      return false;
    }
  }

  // Aliases for compatibility
  Future<Map<String, dynamic>> getPlanConfig() => getStorageAddonConfig();
  Future<bool> setPlanConfig(Map<String, dynamic> config) => setStorageAddonConfig(config);

  Future<Map<String, dynamic>> processPayout(String periodMonth) async {
    try {
      final threshold = await getMinPayoutThreshold();
      final delayDays = await getPayoutDelayDays();
      final cutoff = DateTime.now().subtract(Duration(days: delayDays));

      // Get all pending earnings
      final earningsRes = await http.get(
        _restUri('/profit_earnings?status=eq.pending&select=id,inviter_shop_id,amount,earned_at,created_at,inviter_shop:inviter_shop_id(name)'),
        headers: _adminHeaders,
      );
      if (earningsRes.statusCode != 200) {
        return {'success': false, 'error': 'Failed to fetch earnings'};
      }

      final rawEarnings = jsonDecode(earningsRes.body) as List;

      // Filter earnings past the delay period
      final List<Map<String, dynamic>> eligibleEarnings = [];
      for (final item in rawEarnings) {
        final e = Map<String, dynamic>.from(item as Map);
        if (delayDays <= 0) {
          eligibleEarnings.add(e);
        } else {
          final earnedAtStr = e['earned_at'] ?? e['created_at'];
          if (earnedAtStr == null) {
            eligibleEarnings.add(e);
          } else {
            final earnedAt = DateTime.tryParse(earnedAtStr.toString());
            if (earnedAt == null || earnedAt.isBefore(cutoff) || earnedAt.isAtSameMomentAs(cutoff)) {
              eligibleEarnings.add(e);
            }
          }
        }
      }

      // Group eligible earnings by inviter
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final e in eligibleEarnings) {
        final shopId = e['inviter_shop_id'] as String;
        grouped.putIfAbsent(shopId, () => []).add(e);
      }


      int batchesCreated = 0;
      int skipped = 0;

      for (final entry in grouped.entries) {
        final shopId = entry.key;
        final shopEarnings = entry.value;
        final total = shopEarnings.fold<int>(0, (s, e) => s + (e['amount'] as int));

        if (total < threshold) {
          skipped++;
          continue;
        }

        // Create payout record
        final payoutRes = await http.post(
          _restUri('/profit_payouts'),
          headers: _restHeaders,
          body: jsonEncode({
            'inviter_shop_id': shopId,
            'total_amount': total,
            'period_month': periodMonth,
            'status': 'pending',
          }),
        );

        if (payoutRes.statusCode != 200 && payoutRes.statusCode != 201) continue;

        final payoutData = (jsonDecode(payoutRes.body) as List).first;
        final payoutId = payoutData['id'] as String;

        // Update all included earnings
        final earningIds = shopEarnings.map((e) => e['id']).toList();
        for (final eid in earningIds) {
          await http.patch(
            _restUri('/profit_earnings?id=eq.$eid'),
            headers: _adminHeaders,
            body: jsonEncode({
              'status': 'included_in_payout',
              'payout_id': payoutId,
            }),
          );
        }

        batchesCreated++;
      }

      return {
        'success': true,
        'batches_created': batchesCreated,
        'skipped_below_threshold': skipped,
      };
    } catch (e) {
      debugPrint('Error processing payout: $e');
      return {'success': false, 'error': e.toString()};
    }
  }


  Future<bool> markPayoutPaid({
    required String payoutId,
    required String method,
    required String txRef,
  }) async {
    try {
      // Update payout
      final res = await http.patch(
        _restUri('/profit_payouts?id=eq.$payoutId'),
        headers: _adminHeaders,
        body: jsonEncode({
          'status': 'paid',
          'paid_at': DateTime.now().toIso8601String(),
          'payment_method': method,
          'transaction_reference': txRef,
        }),
      );
      if (res.statusCode != 200 && res.statusCode != 204) return false;

      // Update linked earnings to 'paid'
      await http.patch(
        _restUri('/profit_earnings?payout_id=eq.$payoutId'),
        headers: _adminHeaders,
        body: jsonEncode({'status': 'paid'}),
      );

      return true;
    } catch (e) {
      debugPrint('Error marking payout paid: $e');
      return false;
    }
  }

  // =========================================================================
  // ── APP VERSIONS ──────────────────────────────────────────────────────────
  // =========================================================================

  Future<List<Map<String, dynamic>>> fetchAppVersions() async {
    try {
      final response = await client
          .from('app_versions')
          .select()
          .order('released_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<bool> publishAppVersion({
    required String version,
    required int buildNumber,
    required String downloadUrl,
    required String releaseNotes,
    required bool isMandatory,
  }) async {
    try {
      await client.from('app_versions').insert({
        'version': version,
        'build_number': buildNumber,
        'download_url': downloadUrl,
        'release_notes': releaseNotes,
        'is_mandatory': isMandatory,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // ── HELPERS ───────────────────────────────────────────────────────────────
  // =========================================================================

  String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'DARZI-INV-$code';
  }




  // =========================================================================
  // ── UPGRADE REQUESTS ────────────────────────────────────────────────────
  // =========================================================================

  Future<List<Map<String, dynamic>>> fetchUpgradeRequests({String status = 'pending_admin_review'}) async {
    try {
      final res = await http.get(
        _restUri('/upgrade_requests?select=*,shop:shop_id(id,name,invite_code,invited_by_code)&status=eq.$status&order=created_at.desc'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('fetchUpgradeRequests error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> approveUpgradeRequest({
    required String upgradeRequestId,
    required String shopId,
    required String? invitedByCode,
  }) async {
    try {
      final res = await _callAdminRpc('approve_upgrade_request', {
        'p_upgrade_request_id': upgradeRequestId,
        'p_shop_id': shopId,
        'p_invited_by_code': invitedByCode,
      });
      if (res != null && res['success'] == true) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Approve upgrade RPC failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> rejectUpgradeRequest({
    required String upgradeRequestId,
    required String reason,
  }) async {
    try {
      final res = await _callAdminRpc('reject_upgrade_request', {
        'p_upgrade_request_id': upgradeRequestId,
        'p_reason': reason,
      });
      if (res != null && res['success'] == true) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Reject upgrade RPC failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // =========================================================================
  // ── STORAGE ADDON PAYMENTS ───────────────────────────────────────────────
  // =========================================================================

  Future<List<Map<String, dynamic>>> fetchPendingStorageAddonPayments() async {
    try {
      final res = await http.get(
        _restUri('/storage_addon_payments?select=*,shop:shop_id(id,name,invited_by_code)&status=eq.pending_admin_review&order=created_at.desc'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('fetchPendingStorageAddonPayments error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> approveStorageAddon({
    required String paymentId,
    required String shopId,
    required String? invitedByCode,
  }) async {
    try {
      final res = await _callAdminRpc('approve_storage_addon', {
        'p_payment_id': paymentId,
        'p_shop_id': shopId,
        'p_invited_by_code': invitedByCode,
      });
      if (res != null && res['success'] == true) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Approve storage addon RPC failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> rejectStorageAddon({
    required String paymentId,
    required String reason,
  }) async {
    try {
      final res = await _callAdminRpc('reject_storage_addon', {
        'p_payment_id': paymentId,
        'p_reason': reason,
      });
      if (res != null && res['success'] == true) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Reject storage addon RPC failed'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // =========================================================================
  // ── FINANCIAL REPORTS DATA ───────────────────────────────────────────────
  // =========================================================================

  Future<Map<String, dynamic>> fetchReportsData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      final rpcRes = await _callAdminRpc('get_admin_reports_data');

      final pubRegsList = (rpcRes != null && rpcRes is Map) ? (rpcRes['public_registrations'] as List? ?? []) : [];
      final upgradesList = (rpcRes != null && rpcRes is Map) ? (rpcRes['upgrades'] as List? ?? []) : [];
      final storageList = (rpcRes != null && rpcRes is Map) ? (rpcRes['storage_payments'] as List? ?? []) : [];
      final licsList = (rpcRes != null && rpcRes is Map) ? (rpcRes['licenses'] as List? ?? []) : [];
      final payoutsList = (rpcRes != null && rpcRes is Map) ? (rpcRes['agency_payouts'] ?? rpcRes['payouts'] as List? ?? []) : [];
      final earningsList = (rpcRes != null && rpcRes is Map) ? (rpcRes['agency_earnings'] ?? rpcRes['earnings'] as List? ?? []) : [];

      // Fetch succeeded unified payments (Core Multi-Provider Architecture)
      List<Map<String, dynamic>> subPaymentsList = [];
      if (rpcRes != null && rpcRes is Map && rpcRes['unified_payments'] is List) {
        subPaymentsList = List<Map<String, dynamic>>.from(rpcRes['unified_payments']);
      } else {
        try {
          final subRes = await http.get(
            _restUri('/unified_payments?status=eq.succeeded&is_test=eq.false&select=*,shops(name)&order=created_at.desc'),
            headers: _adminHeaders,
          );
          if (subRes.statusCode == 200) {
            subPaymentsList = List<Map<String, dynamic>>.from(jsonDecode(subRes.body));
          }
        } catch (e) {
          debugPrint('Error fetching unified payments for reports: $e');
        }
      }

      // Fallback: If unified_payments had no rows (during initial migration), check legacy subscription_payments
      if (subPaymentsList.isEmpty) {
        try {
          final legacyRes = await http.get(
            _restUri('/subscription_payments?status=in.(approved,confirmed)&select=*,shops(name)&order=created_at.desc'),
            headers: _adminHeaders,
          );
          if (legacyRes.statusCode == 200) {
            final legacyList = List<Map<String, dynamic>>.from(jsonDecode(legacyRes.body));
            subPaymentsList = legacyList.map((l) {
              final amt = (l['amount_pkr'] as num?)?.toInt() ?? 0;
              return {
                ...l,
                'amount_minor': amt * 100,
                'provider_code': 'manual',
                'purpose': l['payment_type'] == 'founding_activation'
                    ? 'foundingActivation'
                    : 'subscriptionMonthly',
              };
            }).toList();
          }
        } catch (_) {}
      }

      List<Map<String, dynamic>> allTransactions = [];
      int totalRevenue = 0;
      int totalPayouts = 0;

      // Grouped by Category / Type: RECURRING vs ONE-TIME
      Map<String, Map<String, dynamic>> byType = {
        // RECURRING:
        'subscription_monthly': {'amount': 0, 'count': 0, 'group': 'recurring'},
        'founding_monthly':     {'amount': 0, 'count': 0, 'group': 'recurring'},
        'storage_monthly':      {'amount': 0, 'count': 0, 'group': 'recurring'},
        // ONE-TIME:
        'founding_activation':  {'amount': 0, 'count': 0, 'group': 'onetime'},
        'storage_annual':       {'amount': 0, 'count': 0, 'group': 'onetime'},
        'legacy_registrations': {'amount': 0, 'count': 0, 'group': 'onetime'},
        'legacy_upgrades':      {'amount': 0, 'count': 0, 'group': 'onetime'},
        // Compatibility mirrors for any existing references
        'registrations':        {'amount': 0, 'count': 0, 'group': 'onetime'},
        'upgrades':             {'amount': 0, 'count': 0, 'group': 'onetime'},
      };

      // By Payment Provider Breakdown
      Map<String, Map<String, dynamic>> byProvider = {
        'stripe': {'amount': 0, 'count': 0, 'displayName': 'Card / Stripe'},
        'manual': {'amount': 0, 'count': 0, 'displayName': 'Bank / Easypaisa / JazzCash'},
      };

      // byTier uses the 5 subscription plan codes
      Map<String, Map<String, dynamic>> byTier = {
        'trial':     {'amount': 0, 'count': 0},
        'basic':     {'amount': 0, 'count': 0},
        'standard':  {'amount': 0, 'count': 0},
        'unlimited': {'amount': 0, 'count': 0},
        'founding':  {'amount': 0, 'count': 0},
      };

      // Helper: normalise plan codes to valid subscription plan bucket keys
      String normalisePlanTier(String plan) {
        final p = plan.toLowerCase();
        if (p == 'trial') return 'trial';
        if (p == 'basic') return 'basic';
        if (p == 'standard') return 'standard';
        if (p == 'unlimited') return 'unlimited';
        if (p == 'founding') return 'founding';
        return 'standard';
      }

      // Fetch dynamic founding activation fee from app_settings at runtime
      int foundingActivationFeeSetting = 35000;
      try {
        final foundingSettings = await fetchAppSettings(prefix: 'founding');
        final feeStr = foundingSettings['founding_activation_fee'];
        if (feeStr != null && feeStr.trim().isNotEmpty) {
          foundingActivationFeeSetting = int.tryParse(feeStr.trim()) ?? 35000;
        }
      } catch (e) {
        debugPrint('Error fetching founding settings in reports: $e');
      }

      // ── Process Succeeded Unified Payments (Core Model) ──
      for (final sp in subPaymentsList) {
        final spMap = Map<String, dynamic>.from(sp);
        // Exclude test payments
        if (spMap['is_test'] == true) {
          continue;
        }
        final dateStr = (spMap['completed_at'] ?? spMap['reviewed_at'] ?? spMap['created_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final rawMinor = spMap['amount_minor'];
        int amount = 0;
        if (rawMinor != null) {
          amount = ((rawMinor as num).toInt() / 100.0).round();
        } else {
          amount = (spMap['amount_pkr'] as num?)?.toInt() ?? 0;
        }

        final purpose = (spMap['purpose'] ?? '').toString();
        final planCode = (spMap['metadata'] is Map
                ? spMap['metadata']['plan_code']
                : spMap['plan_code'] ?? '')
            .toString()
            .toLowerCase();
        final providerCode = (spMap['provider_code'] ?? 'manual').toString().toLowerCase();
        final shopName = (spMap['shops'] as Map?)?['name']?.toString() ?? 'Shop';

        final isFoundingActivation = purpose == 'foundingActivation' ||
            (planCode == 'founding' && foundingActivationFeeSetting > 0 && amount >= (foundingActivationFeeSetting * 0.7));
        final isFoundingMonthly = planCode == 'founding' && !isFoundingActivation;
        final isStorageMonthly = purpose == 'storageMonthly';
        final isStorageAnnual = purpose == 'storageAnnual';

        final String typeKey;
        final String displayType;
        if (isFoundingActivation) {
          typeKey = 'founding_activation';
          displayType = 'Founding Activation';
        } else if (isFoundingMonthly) {
          typeKey = 'founding_monthly';
          displayType = 'Founding Monthly';
        } else if (isStorageMonthly) {
          typeKey = 'storage_monthly';
          displayType = 'Storage (Monthly)';
        } else if (isStorageAnnual) {
          typeKey = 'storage_annual';
          displayType = 'Storage (Annual)';
        } else {
          typeKey = 'subscription_monthly';
          displayType = 'Subscription (Monthly)';
        }

        byType[typeKey]!['amount'] = (byType[typeKey]!['amount'] as int) + amount;
        byType[typeKey]!['count'] = (byType[typeKey]!['count'] as int) + 1;

        // Provider breakdown
        if (!byProvider.containsKey(providerCode)) {
          byProvider[providerCode] = {
            'amount': 0,
            'count': 0,
            'displayName': providerCode == 'stripe' ? 'Card / Stripe' : providerCode,
          };
        }
        byProvider[providerCode]!['amount'] = (byProvider[providerCode]!['amount'] as int) + amount;
        byProvider[providerCode]!['count'] = (byProvider[providerCode]!['count'] as int) + 1;

        final tierKey = normalisePlanTier(planCode.isNotEmpty ? planCode : (isFoundingActivation ? 'founding' : 'basic'));
        byTier[tierKey]!['amount'] = (byTier[tierKey]!['amount'] as int) + amount;
        byTier[tierKey]!['count'] = (byTier[tierKey]!['count'] as int) + 1;

        totalRevenue += amount;

        allTransactions.add({
          'id': spMap['id'] ?? '',
          'shop_id': spMap['shop_id'] ?? '',
          'date': date.toIso8601String(),
          'type': displayType,
          'shop_name': shopName,
          'amount': amount,
          'direction': 'In',
          'status': spMap['status'] ?? 'succeeded',
          'provider_code': providerCode,
          'payment_method': providerCode == 'stripe' ? 'Stripe Card' : (spMap['metadata']?['payment_method'] ?? 'Bank/Manual'),
          'transaction_id': spMap['provider_reference'] ?? spMap['manual_transaction_id'] ?? spMap['id'] ?? '',
        });
      }

      // Process Approved Public Registrations
      for (final r in pubRegsList) {
        final rMap = Map<String, dynamic>.from(r as Map);
        final dateStr = (rMap['reviewed_at'] ?? rMap['created_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final plan = (rMap['plan_selected'] ?? rMap['plan'] ?? '').toString();
        final amount = _getPlanPrice(plan, rMap['amount_paid']);
        final shopName = (rMap['shop_name'] ?? 'Tailor Shop').toString();

        byType['legacy_registrations']!['amount'] = (byType['legacy_registrations']!['amount'] as int) + amount;
        byType['legacy_registrations']!['count'] = (byType['legacy_registrations']!['count'] as int) + 1;
        byType['registrations']!['amount'] = (byType['registrations']!['amount'] as int) + amount;
        byType['registrations']!['count'] = (byType['registrations']!['count'] as int) + 1;

        final tierKey = normalisePlanTier(plan);
        byTier[tierKey]!['amount'] = (byTier[tierKey]!['amount'] as int) + amount;
        byTier[tierKey]!['count'] = (byTier[tierKey]!['count'] as int) + 1;

        totalRevenue += amount;

        allTransactions.add({
          'id': rMap['id'] ?? '',
          'shop_id': rMap['created_shop_id'] ?? rMap['shop_id'] ?? '',
          'date': date.toIso8601String(),
          'type': 'Legacy Registration',
          'shop_name': shopName,
          'amount': amount,
          'direction': 'In',
          'status': 'approved',
          'payment_method': rMap['payment_method'] ?? 'Easypaisa',
          'transaction_id': rMap['transaction_id'] ?? rMap['id'] ?? '',
        });
      }

      // Process Approved Upgrades
      for (final u in upgradesList) {
        final uMap = Map<String, dynamic>.from(u as Map);
        final dateStr = (uMap['reviewed_at'] ?? uMap['created_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final amount = (uMap['amount_pkr'] as num?)?.toInt() ?? (uMap['amount'] as num?)?.toInt() ?? 0;
        final shopName = (uMap['shop_name'] ?? 'Shop').toString();
        final upgradeType = (uMap['upgrade_type'] ?? uMap['plan_selected'] ?? '').toString().toLowerCase();

        byType['legacy_upgrades']!['amount'] = (byType['legacy_upgrades']!['amount'] as int) + amount;
        byType['legacy_upgrades']!['count'] = (byType['legacy_upgrades']!['count'] as int) + 1;
        byType['upgrades']!['amount'] = (byType['upgrades']!['amount'] as int) + amount;
        byType['upgrades']!['count'] = (byType['upgrades']!['count'] as int) + 1;

        final upgTierKey = normalisePlanTier(upgradeType);
        byTier[upgTierKey]!['amount'] = (byTier[upgTierKey]!['amount'] as int) + amount;
        byTier[upgTierKey]!['count'] = (byTier[upgTierKey]!['count'] as int) + 1;

        totalRevenue += amount;

        allTransactions.add({
          'id': uMap['id'] ?? '',
          'shop_id': uMap['shop_id'] ?? '',
          'date': date.toIso8601String(),
          'type': 'Legacy Upgrade',
          'shop_name': shopName,
          'amount': amount,
          'direction': 'In',
          'status': 'approved',
          'payment_method': uMap['payment_method'] ?? 'Online',
          'transaction_id': uMap['transaction_id'] ?? uMap['id'] ?? '',
        });
      }

      // Process Storage Addon Payments (deduplicated against unified_payments to prevent double counting)
      final processedTxIds = allTransactions.map((t) => t['id'].toString()).toSet();
      for (final s in storageList) {
        final sMap = Map<String, dynamic>.from(s as Map);
        final sid = (sMap['id'] ?? '').toString();
        if (processedTxIds.contains(sid)) continue; // Already counted via unified_payments!

        final status = (sMap['status'] ?? '').toString();
        if (status != 'approved' && status != 'confirmed') continue;

        final dateStr = (sMap['reviewed_at'] ?? sMap['created_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final amount = (sMap['amount'] as num?)?.toInt() ?? 0;
        final isAnnual = sMap['addon_type'] == 'annual' || amount >= 10000;
        final type = isAnnual ? 'Storage (Annual)' : 'Storage (Monthly)';
        final shopName = (sMap['shops'] as Map?)?['name'] ?? 'Shop';

        if (isAnnual) {
          byType['storage_annual']!['amount'] = (byType['storage_annual']!['amount'] as int) + amount;
          byType['storage_annual']!['count'] = (byType['storage_annual']!['count'] as int) + 1;
        } else {
          byType['storage_monthly']!['amount'] = (byType['storage_monthly']!['amount'] as int) + amount;
          byType['storage_monthly']!['count'] = (byType['storage_monthly']!['count'] as int) + 1;
        }

        totalRevenue += amount;

        allTransactions.add({
          'id': sMap['id'] ?? '',
          'shop_id': sMap['shop_id'] ?? '',
          'date': date.toIso8601String(),
          'type': type,
          'shop_name': shopName,
          'amount': amount,
          'direction': 'In',
          'status': 'confirmed',
          'payment_method': sMap['payment_method'] ?? 'Easypaisa',
          'transaction_id': sMap['transaction_id'] ?? sMap['id'] ?? '',
        });
      }

      // Process Active Licenses (avoiding duplicates via shop_id UUID matching)
      for (final l in licsList) {
        final lMap = Map<String, dynamic>.from(l as Map);

        if (lMap['payment_ref'] == null && lMap['amount_pkr'] == null) {
          continue;
        }

        final licShopId = (lMap['shop_id'] ?? '').toString();
        final shopName = (lMap['shop_name'] ?? 'Darzi Shop').toString();

        final exists = allTransactions.any((t) {
          final tShopId = (t['shop_id'] ?? '').toString();
          if (licShopId.isNotEmpty && tShopId.isNotEmpty) {
            return tShopId == licShopId;
          }
          return t['shop_name'].toString().toLowerCase() == shopName.toLowerCase();
        });
        if (exists) continue;

        final dateStr = (lMap['created_at'] ?? lMap['activated_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final plan = (lMap['plan'] ?? lMap['plan_type'] ?? '').toString();
        final amount = _getPlanPrice(plan, lMap['amount_pkr']);

        byType['legacy_registrations']!['amount'] = (byType['legacy_registrations']!['amount'] as int) + amount;
        byType['legacy_registrations']!['count'] = (byType['legacy_registrations']!['count'] as int) + 1;
        byType['registrations']!['amount'] = (byType['registrations']!['amount'] as int) + amount;
        byType['registrations']!['count'] = (byType['registrations']!['count'] as int) + 1;

        final licTierKey = normalisePlanTier(plan);
        byTier[licTierKey]!['amount'] = (byTier[licTierKey]!['amount'] as int) + amount;
        byTier[licTierKey]!['count'] = (byTier[licTierKey]!['count'] as int) + 1;

        totalRevenue += amount;

        allTransactions.add({
          'id': lMap['id'] ?? '',
          'shop_id': lMap['shop_id'] ?? '',
          'date': date.toIso8601String(),
          'type': 'Legacy Registration',
          'shop_name': shopName,
          'amount': amount,
          'direction': 'In',
          'status': lMap['status'] ?? 'active',
          'payment_method': 'Online',
          'transaction_id': lMap['license_key'] ?? lMap['id'] ?? '',
        });
      }



      // Process Agency Payouts OUT
      for (final po in payoutsList) {
        final poMap = Map<String, dynamic>.from(po as Map);
        final dateStr = (poMap['processed_at'] ?? poMap['requested_at'] ?? poMap['created_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final amount = poMap['amount_minor'] != null
            ? ((poMap['amount_minor'] as num).toInt() / 100.0).round()
            : (poMap['amount'] as num?)?.toInt() ?? 0;
        final shopName = (poMap['agency_shop'] as Map?)?['name'] ?? (poMap['inviter_shop'] as Map?)?['name'] ?? 'Agency Shop';

        totalPayouts += amount;

        allTransactions.add({
          'id': poMap['id'] ?? '',
          'date': date.toIso8601String(),
          'type': 'Agency Payout',
          'shop_name': shopName,
          'amount': amount,
          'direction': 'Out',
          'status': poMap['status'] ?? 'paid',
          'payment_method': poMap['method'] ?? 'Payout Direct',
          'transaction_id': poMap['reference'] ?? poMap['id'] ?? '',
        });
      }

      // Process Top Agencies in range
      Map<String, Map<String, dynamic>> topEarnersMap = {};
      for (final e in earningsList) {
        final eMap = Map<String, dynamic>.from(e as Map);
        final dateStr = (eMap['created_at'] ?? eMap['earned_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final shopId = (eMap['agency_shop_id'] ?? eMap['inviter_shop_id']) as String? ?? 'unknown';
        final shopName = (eMap['agency_shop'] as Map?)?['name'] ?? (eMap['inviter_shop'] as Map?)?['name'] ?? 'Agency';
        final amount = eMap['earning_minor'] != null
            ? ((eMap['earning_minor'] as num).toInt() / 100.0).round()
            : (eMap['amount'] as num?)?.toInt() ?? 0;

        if (topEarnersMap.containsKey(shopId)) {
          topEarnersMap[shopId]!['total_earned'] = (topEarnersMap[shopId]!['total_earned'] as int) + amount;
          topEarnersMap[shopId]!['events_count'] = (topEarnersMap[shopId]!['events_count'] as int) + 1;
        } else {
          topEarnersMap[shopId] = {
            'shop_id': shopId,
            'shop_name': shopName,
            'total_earned': amount,
            'events_count': 1,
          };
        }
      }

      final topEarnersList = topEarnersMap.values.toList()
        ..sort((a, b) => (b['total_earned'] as int).compareTo(a['total_earned'] as int));

      // Sort all transactions chronologically descending
      allTransactions.sort((a, b) {
        final dA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final dB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return dB.compareTo(dA);
      });

      final int recurringAmount = (byType['subscription_monthly']!['amount'] as int) +
          (byType['founding_monthly']!['amount'] as int) +
          (byType['storage_monthly']!['amount'] as int);
      final int recurringCount = (byType['subscription_monthly']!['count'] as int) +
          (byType['founding_monthly']!['count'] as int) +
          (byType['storage_monthly']!['count'] as int);

      final int onetimeAmount = (byType['founding_activation']!['amount'] as int) +
          (byType['storage_annual']!['amount'] as int) +
          (byType['legacy_registrations']!['amount'] as int) +
          (byType['legacy_upgrades']!['amount'] as int);
      final int onetimeCount = (byType['founding_activation']!['count'] as int) +
          (byType['storage_annual']!['count'] as int) +
          (byType['legacy_registrations']!['count'] as int) +
          (byType['legacy_upgrades']!['count'] as int);

      return {
        'summary': {
          'total_revenue': totalRevenue,
          'total_payouts': totalPayouts,
          'net_revenue': totalRevenue - totalPayouts,
          'transaction_count': allTransactions.where((t) => t['direction'] == 'In').length,
          'recurring_revenue': recurringAmount,
          'recurring_count': recurringCount,
          'onetime_revenue': onetimeAmount,
          'onetime_count': onetimeCount,
          'founding_activation_fee': foundingActivationFeeSetting,
        },
        'breakdown': {
          'by_type': byType,
          'by_tier': byTier,
          'by_provider': byProvider,
        },
        'top_earners': topEarnersList,
        'transactions': allTransactions,
      };
    } catch (e) {
      debugPrint('Error fetching reports data: $e');
      return {
        'summary': {
          'total_revenue': 0,
          'total_payouts': 0,
          'net_revenue': 0,
          'transaction_count': 0,
          'recurring_revenue': 0,
          'recurring_count': 0,
          'onetime_revenue': 0,
          'onetime_count': 0,
        },
        'breakdown': {
          'by_type': {
            'subscription_monthly': {'amount': 0, 'count': 0, 'group': 'recurring'},
            'founding_monthly':     {'amount': 0, 'count': 0, 'group': 'recurring'},
            'storage_monthly':      {'amount': 0, 'count': 0, 'group': 'recurring'},
            'founding_activation':  {'amount': 0, 'count': 0, 'group': 'onetime'},
            'storage_annual':       {'amount': 0, 'count': 0, 'group': 'onetime'},
            'legacy_registrations': {'amount': 0, 'count': 0, 'group': 'onetime'},
            'legacy_upgrades':      {'amount': 0, 'count': 0, 'group': 'onetime'},
            'registrations':        {'amount': 0, 'count': 0, 'group': 'onetime'},
            'upgrades':             {'amount': 0, 'count': 0, 'group': 'onetime'},
          },
          'by_tier': {
            'trial':     {'amount': 0, 'count': 0},
            'basic':     {'amount': 0, 'count': 0},
            'standard':  {'amount': 0, 'count': 0},
            'unlimited': {'amount': 0, 'count': 0},
            'founding':  {'amount': 0, 'count': 0},
          },
        },
        'top_earners': [],
        'transactions': [],
      };
    }
  }

  int _getPlanPrice(String? plan, [dynamic fallbackAmount]) {
    // Always prefer explicit amount_paid / amount_pkr from the record.
    if (fallbackAmount != null) {
      final num n = fallbackAmount is num ? fallbackAmount : (num.tryParse(fallbackAmount.toString()) ?? 0);
      if (n > 0) return n.toInt();
    }
    // No hardcoded plan prices — subscription prices live in the DB.
    return 0;
  }

  Future<List<Map<String, dynamic>>> fetchPayoutRecipients() async {
    try {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      final prevMonthDate = DateTime(currentYear, currentMonth - 1, 1);
      final prevYear = prevMonthDate.year;
      final prevMonth = prevMonthDate.month;

      final res = await http.get(
        _restUri('/agency_payouts?status=eq.paid&select=*,agency_profiles:agency_shop_id(shop_id,agency_code,display_name)&order=paid_at.desc.nullslast'),
        headers: _adminHeaders,
      );

      if (res.statusCode != 200) return [];

      final list = jsonDecode(res.body) as List;
      final Map<String, Map<String, dynamic>> map = {};

      for (final item in list) {
        final po = Map<String, dynamic>.from(item as Map);
        final shopId = po['agency_shop_id'] as String? ?? 'unknown';
        final agencyProfile = po['agency_profiles'] as Map<String, dynamic>?;
        final shopName = agencyProfile?['display_name'] as String? ?? agencyProfile?['agency_code'] as String? ?? 'Unknown Agency';
        final amount = po['amount_minor'] != null
            ? ((po['amount_minor'] as num).toInt() / 100.0).round()
            : (po['amount'] as num?)?.toInt() ?? 0;

        final dateStr = (po['paid_at'] ?? po['processed_at'] ?? po['requested_at']) as String?;
        final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

        if (!map.containsKey(shopId)) {
          map[shopId] = {
            'shop_id': shopId,
            'shop_name': shopName,
            'this_month_paid': 0,
            'last_month_paid': 0,
            'total_paid_lifetime': 0,
            'last_payout_date': dateStr,
          };
        }

        final entry = map[shopId]!;
        entry['total_paid_lifetime'] = (entry['total_paid_lifetime'] as int) + amount;

        if (date != null) {
          if (date.year == currentYear && date.month == currentMonth) {
            entry['this_month_paid'] = (entry['this_month_paid'] as int) + amount;
          } else if (date.year == prevYear && date.month == prevMonth) {
            entry['last_month_paid'] = (entry['last_month_paid'] as int) + amount;
          }

          final currentLatest = DateTime.tryParse(entry['last_payout_date'] as String? ?? '');
          if (currentLatest == null || date.isAfter(currentLatest)) {
            entry['last_payout_date'] = date.toIso8601String();
          }
        }
      }

      final result = map.values.toList()
        ..sort((a, b) => (b['this_month_paid'] as int).compareTo(a['this_month_paid'] as int));

      return result;
    } catch (e) {
      debugPrint('Error fetching payout recipients: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchShopVpsUsage() async {
    try {
      final shopsRes = await http.get(
        _restUri('/shops?select=id,name,phone,plan_code,storage_used_bytes,storage_addon_active,created_at,status'),
        headers: _adminHeaders,
      );
      if (shopsRes.statusCode != 200) return [];
      final List shops = jsonDecode(shopsRes.body);

      // Fetch customer count per shop
      final customersRes = await http.get(
        _restUri('/customers?select=shop_id'),
        headers: _adminHeaders,
      );
      Map<String, int> customerCounts = {};
      if (customersRes.statusCode == 200) {
        final List custs = jsonDecode(customersRes.body);
        for (var c in custs) {
          final sId = c['shop_id']?.toString();
          if (sId != null) customerCounts[sId] = (customerCounts[sId] ?? 0) + 1;
        }
      }

      // Fetch measurement count per shop
      final measurementsRes = await http.get(
        _restUri('/measurements?select=shop_id'),
        headers: _adminHeaders,
      );
      Map<String, int> measurementCounts = {};
      if (measurementsRes.statusCode == 200) {
        final List meas = jsonDecode(measurementsRes.body);
        for (var m in meas) {
          final sId = m['shop_id']?.toString();
          if (sId != null) measurementCounts[sId] = (measurementCounts[sId] ?? 0) + 1;
        }
      }

      // Fetch order count per shop
      final ordersRes = await http.get(
        _restUri('/orders?select=shop_id'),
        headers: _adminHeaders,
      );
      Map<String, int> orderCounts = {};
      if (ordersRes.statusCode == 200) {
        final List ords = jsonDecode(ordersRes.body);
        for (var o in ords) {
          final sId = o['shop_id']?.toString();
          if (sId != null) orderCounts[sId] = (orderCounts[sId] ?? 0) + 1;
        }
      }

      List<Map<String, dynamic>> results = [];
      for (var shop in shops) {
        final shopId = shop['id'] as String;
        final usedBytes = (shop['storage_used_bytes'] as num?)?.toInt() ?? 0;
        final cCount = customerCounts[shopId] ?? 0;
        final mCount = measurementCounts[shopId] ?? 0;
        final oCount = orderCounts[shopId] ?? 0;
        final totalRecords = cCount + mCount + oCount;

        final status = (shop['status'] as String? ?? 'active').toLowerCase();
        final isActive = status != 'deleted' && status != 'inactive';

        results.add({
          'id': shopId,
          'name': shop['name'] ?? 'Unnamed Shop',
          'phone': shop['phone'] ?? '-',
          'plan': shop['plan_code'] ?? 'trial',
          'plan_code': shop['plan_code'] ?? 'trial',
          'storage_used_bytes': usedBytes,
          'storage_addon_active': shop['storage_addon_active'] == true,
          'is_active': isActive,
          'status': status,
          'created_at': shop['created_at'],
          'customer_count': cCount,
          'measurement_count': mCount,
          'order_count': oCount,
          'total_records': totalRecords,
        });
      }

      results.sort((a, b) => (b['storage_used_bytes'] as int).compareTo(a['storage_used_bytes'] as int));
      return results;
    } catch (e) {
      debugPrint('Error fetching shop VPS usage: $e');
      return [];
    }
  }

  // =========================================================================
  // ── SUBSCRIPTION MANAGEMENT ──────────────────────────────────────────────
  // =========================================================================

  Future<List<Map<String, dynamic>>> fetchSubscriptionPayments({String status = 'awaitingReview'}) async {
    try {
      final effectiveStatus = status == 'pending_admin_review' ? 'awaitingReview' : status;

      // 1. If checking awaiting review, use get_admin_approvals_data RPC (SECURITY DEFINER)
      if (effectiveStatus == 'awaitingReview') {
        final approvalsRes = await _callAdminRpc('get_admin_approvals_data');
        if (approvalsRes != null && approvalsRes is Map && approvalsRes['pending_payments'] is List) {
          final list = List<Map<String, dynamic>>.from(approvalsRes['pending_payments']);
          return list.where((p) => p['shop_id'] != 'bb800b6f-fd70-4ca7-8b51-3b934d3c18c1').toList();
        }
      }

      // 2. Fetch from unified_payments (Single authoritative ledger)
      final res = await http.get(
        _restUri('/unified_payments?status=eq.$effectiveStatus&order=created_at.desc&select=*,shops(id,name,phone,city,invite_code,invited_by_code)'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        return list.where((p) => p['shop_id'] != 'bb800b6f-fd70-4ca7-8b51-3b934d3c18c1').toList();
      }
    } catch (e) {
      debugPrint('Error fetching subscription payments: $e');
    }
    return [];
  }

  Future<bool> approveSubscriptionPayment({
    required String paymentId,
    required String shopId,
    String? cycleId,
    bool? isTest,
  }) async {
    try {
      // 1. Call atomic, shared fulfill_payment RPC
      final Map<String, dynamic> rpcBody = {'p_payment_id': paymentId};
      if (isTest != null) rpcBody['p_is_test'] = isTest;
      final rpcRes = await http.post(
        _restUri('/rpc/fulfill_payment'),
        headers: _restHeaders,
        body: jsonEncode(rpcBody),
      );

      if (rpcRes.statusCode == 200) {
        final data = jsonDecode(rpcRes.body);
        if (data is Map && data['success'] == true) return true;
      }

      // 2. Fallback: If legacy payment row, perform direct approval
      final payRes = await http.patch(
        _restUri('/subscription_payments?id=eq.$paymentId'),
        headers: _restHeaders,
        body: jsonEncode({'status': 'approved', 'reviewed_at': DateTime.now().toUtc().toIso8601String()}),
      );
      if (payRes.statusCode == 200 || payRes.statusCode == 204) {
        if (cycleId != null) {
          await http.patch(
            _restUri('/shop_usage_cycles?id=eq.$cycleId'),
            headers: _restHeaders,
            body: jsonEncode({'payment_status': 'paid', 'paid_at': DateTime.now().toUtc().toIso8601String()}),
          );
        }
        await http.patch(
          _restUri('/shops?id=eq.$shopId'),
          headers: _restHeaders,
          body: jsonEncode({'subscription_status': 'active'}),
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error approving subscription payment: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAuditAlerts() async {
    try {
      final res = await http.get(
        _restUri('/admin_audit_logs?is_resolved=eq.false&order=created_at.desc'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching admin audit alerts: $e');
    }
    return [];
  }

  /// Approves a founding activation payment using the shared fulfill_payment RPC.
  Future<Map<String, dynamic>> approveFoundingActivationPayment({
    required String paymentId,
    required String shopId,
    required int freeMonths,
    required double storageGb,
    bool? isTest,
  }) async {
    try {
      // Shared fulfillment function handles founding activation atomically
      final Map<String, dynamic> rpcBody = {'p_payment_id': paymentId};
      if (isTest != null) rpcBody['p_is_test'] = isTest;
      final res = await http.post(
        _restUri('/rpc/fulfill_payment'),
        headers: _restHeaders,
        body: jsonEncode(rpcBody),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['success'] == true) return data;
      }

      // Fallback: Legacy activate_founding_membership RPC
      final legacyRes = await http.post(
        _restUri('/rpc/activate_founding_membership'),
        headers: _restHeaders,
        body: jsonEncode({
          'p_shop_id':          shopId,
          'p_payment_id':       paymentId,
          'p_free_months':      freeMonths,
          'p_storage_limit_gb': storageGb,
        }),
      );
      if (legacyRes.statusCode == 200) {
        final data = jsonDecode(legacyRes.body);
        if (data is Map<String, dynamic>) return data;
      }

      return {'success': false, 'error': 'Server error ${res.statusCode}'};
    } catch (e) {
      debugPrint('AdminService.approveFoundingActivationPayment error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sets or updates the is_test flag on any unified_payments record via admin RPC.
  Future<bool> setPaymentTestFlag({
    required String paymentId,
    required bool isTest,
  }) async {
    try {
      final res = await http.post(
        _restUri('/rpc/admin_set_payment_test_flag'),
        headers: _restHeaders,
        body: jsonEncode({
          'p_payment_id': paymentId,
          'p_is_test': isTest,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is Map && data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error setting payment test flag: $e');
      return false;
    }
  }

  Future<bool> rejectSubscriptionPayment({required String paymentId, required String reason}) async {
    try {
      // 1. Call reject_unified_payment RPC
      final res = await http.post(
        _restUri('/rpc/reject_unified_payment'),
        headers: _restHeaders,
        body: jsonEncode({
          'p_payment_id': paymentId,
          'p_reason': reason,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['success'] == true) return true;
      }

      // 2. Direct unified_payments patch
      final patchUnified = await http.patch(
        _restUri('/unified_payments?id=eq.$paymentId'),
        headers: _restHeaders,
        body: jsonEncode({
          'status': 'failed',
          'failure_reason': reason,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      if (patchUnified.statusCode == 200 || patchUnified.statusCode == 204) return true;

      // 3. Fallback: legacy subscription_payments patch
      final resLegacy = await http.patch(
        _restUri('/subscription_payments?id=eq.$paymentId'),
        headers: _restHeaders,
        body: jsonEncode({
          'status': 'rejected',
          'rejection_reason': reason,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      return resLegacy.statusCode == 200 || resLegacy.statusCode == 204;
    } catch (e) {
      debugPrint('Error rejecting subscription payment: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSubscriptionPlans() async {
    try {
      final res = await http.get(
        _restUri('/subscription_plans?order=sort_order.asc'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching subscription plans: $e');
    }
    return [];
  }

  // ── PAYMENT PROVIDERS MANAGEMENT ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchPaymentProviders() async {
    try {
      final res = await http.get(
        _restUri('/payment_providers?order=priority.asc'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
      debugPrint('fetchPaymentProviders failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('Error fetching payment providers: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> updatePaymentProvider({
    required String code,
    bool? enabled,
    List<String>? supportedCurrencies,
    List<String>? allowedCountries,
    int? priority,
    String? displayName,
  }) async {
    final params = <String, dynamic>{'p_code': code};
    if (enabled != null) params['p_enabled'] = enabled;
    if (supportedCurrencies != null) params['p_supported_currencies'] = supportedCurrencies;
    if (allowedCountries != null) params['p_allowed_countries'] = allowedCountries;
    if (priority != null) params['p_priority'] = priority;
    if (displayName != null) params['p_display_name'] = displayName;

    final result = await _callAdminRpc('admin_update_payment_provider', params);
    if (result == null) {
      throw Exception('Failed to update payment provider "$code": Empty response or unauthorized.');
    }
    if (result is! Map) {
      throw Exception('Failed to update payment provider "$code": Unexpected server response.');
    }
    final map = Map<String, dynamic>.from(result);
    if (map.isEmpty) {
      throw Exception('Failed to update payment provider "$code": Empty record returned.');
    }
    return map;
  }

  // ── MULTI-CURRENCY PLAN PRICING ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchPlanPrices({String? planCode}) async {
    try {
      final endpoint = planCode != null && planCode.isNotEmpty
          ? '/plan_prices?plan_code=eq.$planCode&order=currency.asc'
          : '/plan_prices?order=plan_code.asc,currency.asc';

      final res = await http.get(_restUri(endpoint), headers: _adminHeaders);
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching plan prices: $e');
    }
    return [];
  }

  Future<bool> upsertPlanPrice({
    required String planCode,
    required String currency,
    required int amountMinor,
  }) async {
    final result = await _callAdminRpc('admin_upsert_plan_price', {
      'p_plan_code': planCode,
      'p_currency': currency,
      'p_amount_minor': amountMinor,
    });
    if (result == null) {
      throw Exception('Failed to upsert plan price for $planCode ($currency): Empty or null response.');
    }
    return true;
  }

  Future<bool> deletePlanPrice({
    required String planCode,
    required String currency,
  }) async {
    final result = await _callAdminRpc('admin_delete_plan_price', {
      'p_plan_code': planCode,
      'p_currency': currency,
    });
    if (result == null) {
      throw Exception('Failed to delete plan price for $planCode ($currency): Empty or null response.');
    }
    return true;
  }

  Future<bool> upsertSubscriptionPlan(Map<String, dynamic> plan) async {
    final result = await _callAdminRpc('admin_upsert_subscription_plan', {
      'p_code': plan['code'],
      'p_name_en': plan['name_en'],
      'p_name_ur': plan['name_ur'],
      'p_price_pkr': plan['price_pkr'],
      'p_max_orders_per_month': plan['max_orders_per_month'],
      'p_max_active_customers': plan['max_active_customers'],
      'p_trial_days': plan['trial_days'],
      'p_sort_order': plan['sort_order'],
      'p_is_active': plan['is_active'],
      'p_storage_allowance_bytes': plan['storage_allowance_bytes'],
    });

    if (result == null) {
      throw Exception('Failed to upsert subscription plan: Empty or null response.');
    }

    if (plan.containsKey('code') && plan.containsKey('price_pkr')) {
      // Sync PKR price to plan_prices in minor units
      final pkrPrice = (plan['price_pkr'] as num?)?.toInt() ?? 0;
      await upsertPlanPrice(
        planCode: plan['code'],
        currency: 'PKR',
        amountMinor: pkrPrice * 100,
      );
    }
    return true;
  }

  Future<bool> grantLifetimeAccess(String shopId, {double storageGb = 5.0}) async {
    try {
      final res = await http.patch(
        _restUri('/shops?id=eq.$shopId'),
        headers: _restHeaders,
        body: jsonEncode({
          'lifetime_access': true,
          'subscription_status': 'lifetime',
          'plan_code': 'unlimited',
          'lifetime_storage_limit_bytes': (storageGb * 1073741824).toInt(),
        }),
      );
      final ok = res.statusCode == 200 || res.statusCode == 204;
      if (ok) {
        final list = jsonDecode(res.body);
        return list is List && list.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('Error granting lifetime access: $e');
      return false;
    }
  }

  Future<bool> revokeLifetimeAccess(String shopId, {String newPlan = 'trial'}) async {
    try {
      final res = await http.patch(
        _restUri('/shops?id=eq.$shopId'),
        headers: _restHeaders,
        body: jsonEncode({
          'lifetime_access': false,
          'subscription_status': newPlan == 'trial' ? 'trial' : 'active',
          'plan_code': newPlan,
        }),
      );
      final ok = res.statusCode == 200 || res.statusCode == 204;
      if (ok) {
        final list = jsonDecode(res.body);
        return list is List && list.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('Error revoking lifetime access: $e');
      return false;
    }
  }

  Future<bool> updateShopPlan(String shopId, {required String newPlan, required String newStatus}) async {
    try {
      final res = await http.patch(
        _restUri('/shops?id=eq.$shopId'),
        headers: _restHeaders,
        body: jsonEncode({
          'plan_code': newPlan,
          'subscription_status': newStatus,
          if (newPlan != 'unlimited') 'lifetime_access': false,
        }),
      );
      final ok = res.statusCode == 200 || res.statusCode == 204;
      if (ok) {
        final list = jsonDecode(res.body);
        return list is List && list.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating shop plan: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchSubscriptionStats() async {
    try {
      // 1. Primary: Server-side atomic SECURITY DEFINER RPC (excludes platform shop)
      final rpcRes = await _callAdminRpc('get_admin_subscription_stats');
      if (rpcRes != null && rpcRes is Map) {
        return Map<String, dynamic>.from(rpcRes);
      }

      // 2. Fallback: Fetch all shops with subscription columns (excluding platform shop bb800b6f)
      final res = await http.get(
        _restUri('/shops?select=id,plan_code,subscription_status,billing_cycle_end,founding_free_until&status=neq.deleted'),
        headers: _adminHeaders,
      );
      if (res.statusCode != 200) return {};

      final allShops = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      final shops = allShops.where((s) => s['id'] != 'bb800b6f-fd70-4ca7-8b51-3b934d3c18c1').toList();

      // Calculate plan prices from subscription_plans table
      final plansRes = await http.get(
        _restUri('/subscription_plans?select=code,price_pkr'),
        headers: _adminHeaders,
      );
      final planPriceMap = <String, int>{};
      if (plansRes.statusCode == 200) {
        for (final p in List<Map<String, dynamic>>.from(jsonDecode(plansRes.body))) {
          planPriceMap[p['code'] as String] = (p['price_pkr'] as int?) ?? 0;
        }
      }

      // Fetch founding settings to determine monthly recurring fee
      final settingsRes = await http.get(
        _restUri('/app_settings?key=like.founding%25'),
        headers: _adminHeaders,
      );
      int foundingMonthlyFee = 0;
      if (settingsRes.statusCode == 200) {
        final settings = <String, String>{
          for (final r in List<Map<String, dynamic>>.from(jsonDecode(settingsRes.body)))
            r['key'] as String: r['value'] as String
        };
        final mode = settings['founding_monthly_mode'] ?? 'linked';
        if (mode == 'fixed') {
          foundingMonthlyFee = int.tryParse(settings['founding_monthly_fixed'] ?? '500') ?? 500;
        } else {
          // linked: use basic plan price
          foundingMonthlyFee = planPriceMap['basic'] ?? 500;
        }
      }

      // Aggregate
      final planCounts = <String, int>{};
      int mrr = 0;
      int foundingMrr = 0;       // founding shops PAST free period
      int foundingActivations = 0; // founding shops in free period
      int graceCount = 0;
      int readOnlyCount = 0;
      int lifetimeCount = 0;
      int foundingCount = 0;
      final now = DateTime.now();
      int upcomingRenewals = 0;

      for (final shop in shops) {
        final planCode = shop['plan_code'] as String? ?? 'trial';
        final status   = shop['subscription_status'] as String? ?? 'trial';
        final cycleEnd = shop['billing_cycle_end'] as String?;
        final foundingFreeUntil = shop['founding_free_until'] as String?;

        planCounts[planCode] = (planCounts[planCode] ?? 0) + 1;

        if (status == 'lifetime') {
          lifetimeCount++;
        } else if (planCode == 'founding' || status == 'founding') {
          foundingCount++;
          // Check if in free period or paying period
          final freeUntil = foundingFreeUntil != null ? DateTime.tryParse(foundingFreeUntil) : null;
          if (freeUntil != null && now.isBefore(freeUntil)) {
            foundingActivations++; // still in free period, no MRR contribution
          } else {
            foundingMrr += foundingMonthlyFee; // past free period, recurring
          }
        } else if (status == 'active' || status == 'expiring') {
          mrr += planPriceMap[planCode] ?? 0;
        } else if (status == 'grace') {
          graceCount++;
        } else if (status == 'read_only') {
          readOnlyCount++;
        }

        if (cycleEnd != null) {
          final end = DateTime.tryParse(cycleEnd);
          if (end != null && end.isAfter(now) && end.isBefore(now.add(const Duration(days: 7)))) {
            upcomingRenewals++;
          }
        }
      }

      return {
        'mrr':                   mrr,
        'founding_mrr':          foundingMrr,
        'founding_activations':  foundingActivations,
        'founding_count':        foundingCount,
        'plan_counts':           planCounts,
        'plan_prices':           planPriceMap, // for dynamic display in UI
        'grace_count':           graceCount,
        'read_only_count':       readOnlyCount,
        'lifetime_count':        lifetimeCount,
        'upcoming_renewals_7d':  upcomingRenewals,
        'total_shops':           shops.length,
        'total_mrr':             mrr + foundingMrr,
      };
    } catch (e) {
      debugPrint('Error fetching subscription stats: $e');
      return {};
    }
  }

  /// Fetches all app_settings rows matching the given prefix.
  Future<Map<String, String>> fetchAppSettings({String prefix = ''}) async {
    try {
      final filter = prefix.isNotEmpty
          ? '?key=like.${Uri.encodeComponent(prefix)}%25'
          : '';
      final res = await http.get(
        _restUri('/app_settings$filter'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        final rows = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        return {for (final r in rows) r['key'] as String: r['value'] as String};
      }
    } catch (e) {
      debugPrint('AdminService.fetchAppSettings error: $e');
    }
    return {};
  }

  /// Upserts a single app_setting key/value pair via admin RPC.
  Future<bool> updateAppSetting(String key, String value) async {
    final result = await _callAdminRpc('admin_update_app_setting', {
      'p_key': key,
      'p_value': value,
    });
    if (result == null) {
      throw Exception('Failed to update app setting "$key": Empty or null response from server.');
    }
    return true;
  }
}

