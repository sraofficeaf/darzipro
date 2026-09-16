import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/theme_extensions.dart';
import 'admin_create_user_modal.dart';
import 'widgets/admin_ui_kit.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _authUsers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _filter = 'all'; // all, active, blocked

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final users = await AdminService.instance.fetchAllShopUsers();
    final authUsers = await AdminService.instance.fetchAuthUsers();

    if (mounted) {
      setState(() {
        _users = users;
        _authUsers = authUsers;
        _applyFilter();
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _getAuthUser(String userId) {
    try {
      return _authUsers.firstWhere((u) => u['id'] == userId);
    } catch (_) {
      return null;
    }
  }

  bool _isBlocked(String userId) {
    final auth = _getAuthUser(userId);
    if (auth == null) return false;
    final bannedUntil = auth['banned_until'] as String?;
    if (bannedUntil == null || bannedUntil.isEmpty) return false;
    try {
      return DateTime.parse(bannedUntil).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _users.where((u) {
        final name = (u['full_name'] as String? ?? '').toLowerCase();
        final shopName = ((u['shops'] as Map?)?['name'] as String? ?? '').toLowerCase();
        final phone = ((u['shops'] as Map?)?['phone'] as String? ?? '').toLowerCase();
        final matchSearch = _search.isEmpty ||
            name.contains(_search.toLowerCase()) ||
            shopName.contains(_search.toLowerCase()) ||
            phone.contains(_search.toLowerCase());

        final blocked = _isBlocked(u['id'] as String);
        if (_filter == 'active' && blocked) return false;
        if (_filter == 'blocked' && !blocked) return false;

        return matchSearch;
      }).toList();
    });
  }

  Future<void> _toggleBlockUser(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final blocked = _isBlocked(userId);
    final name = user['full_name'] ?? 'User';

    final confirmed = await _showConfirmDialog(
      title: blocked ? 'Unblock User' : 'Block User',
      message: blocked
          ? 'Are you sure you want to unblock $name? They will be able to log in again.'
          : 'Are you sure you want to block $name? They will be signed out immediately.',
      confirmLabel: blocked ? 'Unblock' : 'Block User',
      danger: !blocked,
    );
    if (!confirmed) return;

    final ok = blocked
        ? await AdminService.instance.unblockUser(userId)
        : await AdminService.instance.blockUser(userId);

    if (ok) {
      _showSnack(blocked ? '✅ User unblocked' : '🔒 User blocked');
      await _loadUsers();
    } else {
      _showSnack('❌ Action failed', error: true);
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final auth = _getAuthUser(user['id'] as String);
    final email = auth?['email'] ?? '';
    if (email.isEmpty) {
      _showSnack('❌ Email not found', error: true);
      return;
    }

    final ok = await AdminService.instance.sendPasswordReset(email);
    if (ok) {
      _showSnack('📧 Password reset email sent to $email');
    } else {
      _showSnack('❌ Failed to send reset email', error: true);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final shopId = (user['shops'] as Map?)?['id'] ?? '';
    final shopName = (user['shops'] as Map?)?['name'] ?? 'Unknown';

    final confirmed = await _showConfirmDialog(
      title: '⚠️ Delete User',
      message:
          'Permanently delete "$shopName" and ALL their data (orders, customers, etc.)?\n\nThis CANNOT be undone!',
      confirmLabel: 'Delete Forever',
      danger: true,
    );
    if (!confirmed) return;

    final ok = await AdminService.instance.deleteShopUser(userId, shopId.toString());
    if (ok) {
      _showSnack('🗑️ User deleted permanently');
      await _loadUsers();
    } else {
      _showSnack('❌ Delete failed', error: true);
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
            content: Text(message,
                style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: danger ? AdminColors.rose : AdminColors.amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(confirmLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: error ? AdminColors.rose : AdminColors.text1,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _openCreateUser() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AdminCreateUserModal(),
    );
    if (result == true) {
      _showSnack('✅ New user created successfully!');
      await _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final textPrimary = context.text1;
    final textSecondary = context.text2;

    final total = _users.length;
    final blocked = _users.where((u) => _isBlocked(u['id'] as String)).length;
    final active = total - blocked;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Page Header with Mini Stats (RepaintBoundary for zero repaint overhead)
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'User Management',
                subtitle: 'Manage shop owners & staff accounts',
                action: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AdminMiniStat(label: 'Total', value: '$total', color: AdminColors.indigo),
                    const SizedBox(width: 8),
                    AdminMiniStat(label: 'Active', value: '$active', color: AdminColors.emerald),
                    const SizedBox(width: 8),
                    AdminMiniStat(label: 'Blocked', value: '$blocked', color: AdminColors.rose),
                    const SizedBox(width: 12),
                    AdminIconBtn(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh Users',
                      onPressed: _loadUsers,
                    ),
                    const SizedBox(width: 8),
                    AdminButton.primary(
                      label: 'New User',
                      icon: Icons.person_add_rounded,
                      onPressed: _openCreateUser,
                    ),
                  ],
                ),
              ),
            ),

            // Toolbar with Search & Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: surface,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        onChanged: (val) {
                          _search = val;
                          _applyFilter();
                        },
                        style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Search by shop, owner name or phone...',
                          hintStyle: GoogleFonts.inter(
                            color: textSecondary.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 18),
                          filled: true,
                          fillColor: bg,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AdminColors.indigo, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AdminChip(
                    label: 'All (${_users.length})',
                    isSelected: _filter == 'all',
                    onTap: () {
                      _filter = 'all';
                      _applyFilter();
                    },
                  ),
                  const SizedBox(width: 8),
                  AdminChip(
                    label: 'Active ($active)',
                    isSelected: _filter == 'active',
                    color: AdminColors.emerald,
                    onTap: () {
                      _filter = 'active';
                      _applyFilter();
                    },
                  ),
                  const SizedBox(width: 8),
                  AdminChip(
                    label: 'Blocked ($blocked)',
                    isSelected: _filter == 'blocked',
                    color: AdminColors.rose,
                    onTap: () {
                      _filter = 'blocked';
                      _applyFilter();
                    },
                  ),
                ],
              ),
            ),

            // List of Users
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AdminColors.indigo))
                  : _filtered.isEmpty
                      ? _buildEmpty(textPrimary, textSecondary)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, idx) => RepaintBoundary(
                            child: _buildUserCard(_filtered[idx], surface, border, textPrimary, textSecondary),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 54, color: textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          Text(
            'No users found',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search or filter options',
            style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, Color surface, Color border, Color textPrimary, Color textSecondary) {
    final userId = user['id'] as String;
    final ownerName = user['full_name'] as String? ?? 'Unnamed Owner';
    final role = user['role'] as String? ?? 'owner';
    final createdAt = user['created_at'] as String?;

    final shop = user['shops'] as Map<String, dynamic>?;
    final shopName = shop?['name'] as String? ?? 'No Shop Name';
    final phone = shop?['phone'] as String? ?? 'No phone';

    final authUser = _getAuthUser(userId);
    final email = authUser?['email'] as String? ?? 'No email available';
    final isBlocked = _isBlocked(userId);

    String dateStr = 'Unknown';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBlocked ? AdminColors.rose.withValues(alpha: 0.4) : border,
          width: isBlocked ? 1.5 : 1,
        ),
        boxShadow: context.cardShadow,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isBlocked
                    ? [AdminColors.rose.withValues(alpha: 0.2), AdminColors.rose.withValues(alpha: 0.05)]
                    : [AdminColors.indigo.withValues(alpha: 0.2), AdminColors.violet.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                shopName.isNotEmpty ? shopName[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isBlocked ? AdminColors.rose : AdminColors.indigo,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // User & Shop Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shopName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    AdminBadge(
                      label: isBlocked ? 'BLOCKED' : 'ACTIVE',
                      color: isBlocked ? AdminColors.rose : AdminColors.emerald,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline_rounded, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          ownerName,
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.email_outlined, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(email, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_outlined, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(phone, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 13, color: textSecondary),
                        const SizedBox(width: 4),
                        Text('Joined $dateStr', style: GoogleFonts.inter(fontSize: 11, color: textSecondary)),
                      ],
                    ),
                    AdminBadge(label: role.toUpperCase(), color: AdminColors.text3),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminIconBtn(
                icon: isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                tooltip: isBlocked ? 'Unblock Account' : 'Block Account',
                color: isBlocked ? AdminColors.emerald : AdminColors.rose,
                onPressed: () => _toggleBlockUser(user),
              ),
              const SizedBox(width: 6),
              AdminIconBtn(
                icon: Icons.lock_reset_rounded,
                tooltip: 'Send Password Reset Email',
                color: AdminColors.amber,
                onPressed: () => _resetPassword(user),
              ),
              const SizedBox(width: 6),
              AdminIconBtn(
                icon: Icons.delete_forever_rounded,
                tooltip: 'Delete Account Permanently',
                color: AdminColors.rose,
                onPressed: () => _deleteUser(user),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
