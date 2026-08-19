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
      final res = await http.get(
        _restUri('/profiles?select=id,full_name,role,created_at,shop_id,shops(id,name,phone,currency)&order=created_at.desc'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching shop users: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchAuthUsers() async {
    try {
      final res = await http.get(
        _authUri('/admin/users?per_page=1000'),
        headers: _adminHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(data['users'] ?? []);
      }
    } catch (e) {
      debugPrint('Error fetching auth users: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> createShopUser({
    required String email,
    required String password,
    required String shopName,
    required String ownerName,
  }) async {
    try {
      final authRes = await http.post(
        _authUri('/admin/users'),
        headers: _adminHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
          'email_confirm': true,
        }),
      );

      if (authRes.statusCode != 200 && authRes.statusCode != 201) {
        final err = jsonDecode(authRes.body);
        return {'success': false, 'error': err['message'] ?? 'User creation failed'};
      }

      final authUser = jsonDecode(authRes.body) as Map<String, dynamic>;
      final userId = authUser['id'] as String;

      final shopRes = await http.post(
        _restUri('/shops'),
        headers: _restHeaders,
        body: jsonEncode({
          'name': shopName,
          'currency': 'PKR',
          'invite_code': _generateInviteCode(),
        }),
      );

      if (shopRes.statusCode != 200 && shopRes.statusCode != 201) {
        return {'success': false, 'error': 'Shop creation failed'};
      }

      final shopData = (jsonDecode(shopRes.body) as List).first as Map<String, dynamic>;
      final shopId = shopData['id'] as String;

      final profileRes = await http.post(
        _restUri('/profiles'),
        headers: _restHeaders,
        body: jsonEncode({
          'id': userId,
          'shop_id': shopId,
          'full_name': ownerName,
          'role': 'owner',
        }),
      );

      if (profileRes.statusCode != 200 && profileRes.statusCode != 201) {
        return {'success': false, 'error': 'Profile creation failed'};
      }

      return {'success': true, 'userId': userId, 'shopId': shopId};
    } catch (e) {
      debugPrint('Error creating shop user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> blockUser(String userId) async {
    try {
      final res = await http.put(
        _authUri('/admin/users/$userId'),
        headers: _adminHeaders,
        body: jsonEncode({'ban_duration': '876600h'}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      final res = await http.put(
        _authUri('/admin/users/$userId'),
        headers: _adminHeaders,
        body: jsonEncode({'ban_duration': 'none'}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return false;
    }
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

  Future<bool> deleteShopUser(String userId, String shopId) async {
    try {
      final res = await http.delete(
        _authUri('/admin/users/$userId'),
        headers: _adminHeaders,
      );
      if (res.statusCode != 200 && res.statusCode != 204) return false;

      await http.delete(
        _restUri('/shops?id=eq.$shopId'),
        headers: _adminHeaders,
      );
      return true;
    } catch (e) {
      debugPrint('Error deleting shop user: $e');
      return false;
    }
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

      // 1. Fetch all real shops from shops table with owner profiles and licenses
      final shopsRes = await http.get(
        _restUri('/shops?select=*,profiles(full_name,role),licenses(email,plan,status)&order=created_at.desc'),
        headers: _adminHeaders,
      );

      if (shopsRes.statusCode == 200) {
        final rawShops = jsonDecode(shopsRes.body) as List;
        for (final item in rawShops) {
          final s = Map<String, dynamic>.from(item as Map);
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
            'plan': s['plan'] ?? s['plan_type'] ?? 'full_access',
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

  Future<bool> updateLicenseNotes(String id, String notes) async {
    try {
      await client.from('licenses').update({'notes': notes}).eq('id', id);
      return true;
    } catch (e) {
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
      String planType = 'pro';
      if (licenseRes.statusCode == 200) {
        final licList = jsonDecode(licenseRes.body) as List;
        if (licList.isNotEmpty) {
          final first = licList.first as Map<String, dynamic>;
          planType = (first['plan'] as String?) ?? (first['plan_type'] as String?) ?? 'pro';
        }
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
    try {
      final res = await http.post(
        _restUri('/app_settings'),
        headers: {
          ..._adminHeaders,
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode({
          'key': 'minimum_payout_threshold',
          'value': threshold.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Error saving min payout threshold: $e');
      return false;
    }
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
    try {
      final res = await http.post(
        _restUri('/app_settings'),
        headers: {
          ..._adminHeaders,
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode({
          'key': 'payout_delay_days',
          'value': days.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Error saving payout delay days: $e');
      return false;
    }
  }

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

  String _generateInviteCode() {
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
      final payoutsList = (rpcRes != null && rpcRes is Map) ? (rpcRes['payouts'] as List? ?? []) : [];
      final earningsList = (rpcRes != null && rpcRes is Map) ? (rpcRes['earnings'] as List? ?? []) : [];

      List<Map<String, dynamic>> allTransactions = [];
      int totalRevenue = 0;
      int totalPayouts = 0;

      Map<String, Map<String, dynamic>> byType = {
        'registrations': {'amount': 0, 'count': 0},
        'upgrades': {'amount': 0, 'count': 0},
        'storage_monthly': {'amount': 0, 'count': 0},
        'storage_annual': {'amount': 0, 'count': 0},
      };

      Map<String, Map<String, dynamic>> byTier = {
        'mobile_only': {'amount': 0, 'count': 0},
        'full_access': {'amount': 0, 'count': 0},
        'full_access_3yr': {'amount': 0, 'count': 0},
      };

      // Process Approved Public Registrations
      for (final r in pubRegsList) {
        final rMap = Map<String, dynamic>.from(r as Map);
        final dateStr = (rMap['reviewed_at'] ?? rMap['created_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final plan = (rMap['plan_selected'] ?? rMap['plan'] ?? 'full_access').toString();
        final amount = _getPlanPrice(plan, rMap['amount_paid']);
        final shopName = (rMap['shop_name'] ?? 'Tailor Shop').toString();

        byType['registrations']!['amount'] = (byType['registrations']!['amount'] as int) + amount;
        byType['registrations']!['count'] = (byType['registrations']!['count'] as int) + 1;

        if (amount == 12000 || plan.contains('mobile')) {
          byTier['mobile_only']!['amount'] = (byTier['mobile_only']!['amount'] as int) + amount;
          byTier['mobile_only']!['count'] = (byTier['mobile_only']!['count'] as int) + 1;
        } else if (amount == 70000 || plan.contains('3yr')) {
          byTier['full_access_3yr']!['amount'] = (byTier['full_access_3yr']!['amount'] as int) + amount;
          byTier['full_access_3yr']!['count'] = (byTier['full_access_3yr']!['count'] as int) + 1;
        } else {
          byTier['full_access']!['amount'] = (byTier['full_access']!['amount'] as int) + amount;
          byTier['full_access']!['count'] = (byTier['full_access']!['count'] as int) + 1;
        }

        totalRevenue += amount;

        allTransactions.add({
          'id': rMap['id'] ?? '',
          'shop_id': rMap['created_shop_id'] ?? rMap['shop_id'] ?? '',
          'date': date.toIso8601String(),
          'type': 'Registration',
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

        byType['upgrades']!['amount'] = (byType['upgrades']!['amount'] as int) + amount;
        byType['upgrades']!['count'] = (byType['upgrades']!['count'] as int) + 1;

        if (amount == 70000 || upgradeType.contains('3yr')) {
          byTier['full_access_3yr']!['amount'] = (byTier['full_access_3yr']!['amount'] as int) + amount;
          byTier['full_access_3yr']!['count'] = (byTier['full_access_3yr']!['count'] as int) + 1;
        } else if (amount == 12000 || upgradeType.contains('mobile')) {
          byTier['mobile_only']!['amount'] = (byTier['mobile_only']!['amount'] as int) + amount;
          byTier['mobile_only']!['count'] = (byTier['mobile_only']!['count'] as int) + 1;
        } else {
          byTier['full_access']!['amount'] = (byTier['full_access']!['amount'] as int) + amount;
          byTier['full_access']!['count'] = (byTier['full_access']!['count'] as int) + 1;
        }

        totalRevenue += amount;

        allTransactions.add({
          'id': uMap['id'] ?? '',
          'shop_id': uMap['shop_id'] ?? '',
          'date': date.toIso8601String(),
          'type': 'Upgrade',
          'shop_name': shopName,
          'amount': amount,
          'direction': 'In',
          'status': 'approved',
          'payment_method': uMap['payment_method'] ?? 'Online',
          'transaction_id': uMap['transaction_id'] ?? uMap['id'] ?? '',
        });
      }

      // Process Storage Addon Payments
      for (final s in storageList) {
        final sMap = Map<String, dynamic>.from(s as Map);
        final status = (sMap['status'] ?? '').toString();
        if (status != 'approved' && status != 'confirmed') continue;

        final dateStr = (sMap['reviewed_at'] ?? sMap['created_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final amount = (sMap['amount'] as num?)?.toInt() ?? 0;
        final isAnnual = sMap['addon_type'] == 'annual' || amount >= 10000;
        final type = isAnnual ? 'Storage Add-on (Annual)' : 'Storage Add-on (Monthly)';
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

        final plan = (lMap['plan'] ?? lMap['plan_type'] ?? 'full_access').toString();
        final amount = _getPlanPrice(plan, lMap['amount_pkr']);

        byType['registrations']!['amount'] = (byType['registrations']!['amount'] as int) + amount;
        byType['registrations']!['count'] = (byType['registrations']!['count'] as int) + 1;

        if (amount == 12000 || plan.contains('mobile')) {
          byTier['mobile_only']!['amount'] = (byTier['mobile_only']!['amount'] as int) + amount;
          byTier['mobile_only']!['count'] = (byTier['mobile_only']!['count'] as int) + 1;
        } else if (amount == 70000 || plan.contains('3yr')) {
          byTier['full_access_3yr']!['amount'] = (byTier['full_access_3yr']!['amount'] as int) + amount;
          byTier['full_access_3yr']!['count'] = (byTier['full_access_3yr']!['count'] as int) + 1;
        } else {
          byTier['full_access']!['amount'] = (byTier['full_access']!['amount'] as int) + amount;
          byTier['full_access']!['count'] = (byTier['full_access']!['count'] as int) + 1;
        }

        totalRevenue += amount;

        allTransactions.add({
          'id': lMap['id'] ?? '',
          'shop_id': lMap['shop_id'] ?? '',
          'date': date.toIso8601String(),
          'type': 'Registration',
          'shop_name': shopName,
          'amount': amount,
          'direction': 'In',
          'status': lMap['status'] ?? 'active',
          'payment_method': 'Online',
          'transaction_id': lMap['license_key'] ?? lMap['id'] ?? '',
        });
      }



      // Process Payouts OUT
      for (final po in payoutsList) {
        final poMap = Map<String, dynamic>.from(po as Map);
        final dateStr = poMap['created_at'] as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final amount = (poMap['amount'] as num?)?.toInt() ?? 0;
        final shopName = (poMap['inviter_shop'] as Map?)?['name'] ?? 'Inviter Shop';

        totalPayouts += amount;

        allTransactions.add({
          'id': poMap['id'] ?? '',
          'date': date.toIso8601String(),
          'type': 'Payout',
          'shop_name': shopName,
          'amount': amount,
          'direction': 'Out',
          'status': poMap['status'] ?? 'paid',
          'payment_method': 'Payout Direct',
          'transaction_id': poMap['id'] ?? '',
        });
      }

      // Process Top Earners in range
      Map<String, Map<String, dynamic>> topEarnersMap = {};
      for (final e in earningsList) {
        final eMap = Map<String, dynamic>.from(e as Map);
        final dateStr = (eMap['created_at'] ?? eMap['earned_at']) as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null || date.isBefore(start) || date.isAfter(end)) continue;

        final shopId = eMap['inviter_shop_id'] as String? ?? 'unknown';
        final shopName = (eMap['inviter_shop'] as Map?)?['name'] ?? 'Inviter';
        final amount = (eMap['amount'] as num?)?.toInt() ?? 0;

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

      return {
        'summary': {
          'total_revenue': totalRevenue,
          'total_payouts': totalPayouts,
          'net_revenue': totalRevenue - totalPayouts,
          'transaction_count': allTransactions.where((t) => t['direction'] == 'In').length,
        },
        'breakdown': {
          'by_type': byType,
          'by_tier': byTier,
        },
        'top_earners': topEarnersList,
        'transactions': allTransactions,
      };
    } catch (e) {
      debugPrint('Error fetching reports data: $e');
      return {
        'summary': {'total_revenue': 0, 'total_payouts': 0, 'net_revenue': 0, 'transaction_count': 0},
        'breakdown': {
          'by_type': {'registrations': {'amount': 0, 'count': 0}, 'upgrades': {'amount': 0, 'count': 0}, 'storage_monthly': {'amount': 0, 'count': 0}, 'storage_annual': {'amount': 0, 'count': 0}},
          'by_tier': {'mobile_only': {'amount': 0}, 'full_access': {'amount': 0}, 'full_access_3yr': {'amount': 0}},
        },
        'top_earners': [],
        'transactions': [],
      };
    }
  }

  int _getPlanPrice(String? plan, [dynamic fallbackAmount]) {
    if (fallbackAmount != null) {
      final num n = fallbackAmount is num ? fallbackAmount : (num.tryParse(fallbackAmount.toString()) ?? 0);
      if (n > 0) return n.toInt();
    }
    final p = (plan ?? '').toLowerCase();
    if (p.isEmpty) return 0;
    if (p.contains('3yr') || p.contains('three_year') || p.contains('full_access_3yr')) return 70000;
    if (p.contains('mobile')) return 12000;
    return 35000; // Full Access
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
        _restUri('/profit_payouts?status=eq.paid&select=*,inviter_shop:inviter_shop_id(id,name)&order=created_at.desc'),
        headers: _adminHeaders,
      );

      if (res.statusCode != 200) return [];

      final list = jsonDecode(res.body) as List;
      final Map<String, Map<String, dynamic>> map = {};

      for (final item in list) {
        final po = Map<String, dynamic>.from(item as Map);
        final shopId = po['inviter_shop_id'] as String? ?? 'unknown';
        final shopName = (po['inviter_shop'] as Map?)?['name'] as String? ?? 'Unknown Shop';
        final amount = (po['amount'] as num?)?.toInt() ?? 0;

        final dateStr = po['created_at'] as String?;
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
}


