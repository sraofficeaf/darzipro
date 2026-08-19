import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/admin_service.dart';
import 'admin_create_user_modal.dart';

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

  static const _amber = Color(0xFFF5A623);
  static const _red = Color(0xFFFF3A58);
  static const _green = Color(0xFF10B981);

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
        final shopName =
            ((u['shops'] as Map?)?['name'] as String? ?? '').toLowerCase();
        final phone =
            ((u['shops'] as Map?)?['phone'] as String? ?? '').toLowerCase();
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
      _showSnack(blocked ? '✅ User unblocked' : '刻 User blocked');
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

    final ok =
        await AdminService.instance.deleteShopUser(userId, shopId.toString());
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title,
                style: GoogleFonts.outfit(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            content: Text(message,
                style:
                    GoogleFonts.inter(color: textSecondary, fontSize: 14, height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: GoogleFonts.inter(color: textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: danger ? _red : _amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(confirmLabel,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnack(String msg, {bool error = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: error ? _red : (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _buildHeader(textPrimary, textSecondary, border),
          _buildToolbar(surface, border, textPrimary, textSecondary),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _amber))
                : _filtered.isEmpty
                    ? _buildEmpty(textPrimary, textSecondary)
                    : _buildUserList(surface, border, textPrimary, textSecondary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateUser,
        backgroundColor: _amber,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('New User',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary, Color border) {
    final total = _users.length;
    final blocked = _users.where((u) => _isBlocked(u['id'] as String)).length;
    final active = total - blocked;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User Management',
                    style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textPrimary)),
                const SizedBox(height: 4),
                Text('Manage shop owners & staff accounts',
                    style:
                        GoogleFonts.inter(fontSize: 13, color: textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _StatChip(label: 'Total', value: total.toString(), color: _amber),
          const SizedBox(width: 8),
          _StatChip(label: 'Active', value: active.toString(), color: _green),
          const SizedBox(width: 8),
          _StatChip(label: 'Blocked', value: blocked.toString(), color: _red),
          const SizedBox(width: 12),
          _HeaderButton(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              onTap: _loadUsers),
        ],
      ),
    );
  }

  Widget _buildToolbar(Color surface, Color border, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
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
                style: GoogleFonts.inter(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by shop, owner name or phone...',
                  hintStyle: GoogleFonts.inter(
                      color: textSecondary.withValues(alpha: 0.6), fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: textSecondary, size: 18),
                  filled: true,
                  fillColor: surface,
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
                    borderSide: const BorderSide(color: _amber, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _FilterChip(
            label: 'All (${_users.length})',
            active: _filter == 'all',
            onTap: () {
              _filter = 'all';
              _applyFilter();
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Active',
            active: _filter == 'active',
            color: _green,
            onTap: () {
              _filter = 'active';
              _applyFilter();
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Blocked',
            active: _filter == 'blocked',
            color: _red,
            onTap: () {
              _filter = 'blocked';
              _applyFilter();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined,
              size: 56, color: textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No users found',
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 6),
          Text('Try adjusting your search or filter options',
              style: GoogleFonts.inter(fontSize: 13, color: textSecondary)),
        ],
      ),
    );
  }

  Widget _buildUserList(Color surface, Color border, Color textPrimary, Color textSecondary) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _filtered.length,
      itemBuilder: (ctx, idx) => _buildUserCard(_filtered[idx], surface, border, textPrimary, textSecondary),
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
          color: isBlocked ? _red.withValues(alpha: 0.4) : border,
          width: isBlocked ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isBlocked
                    ? [_red.withValues(alpha: 0.3), _red.withValues(alpha: 0.1)]
                    : [_amber.withValues(alpha: 0.3), _amber.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                shopName.isNotEmpty ? shopName[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isBlocked ? _red : _amber),
              ),
            ),
          ),
          const SizedBox(width: 16),

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
                            fontWeight: FontWeight.w800,
                            color: textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isBlocked
                            ? _red.withValues(alpha: 0.15)
                            : _green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isBlocked ? _red : _green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isBlocked ? 'BLOCKED' : 'ACTIVE',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isBlocked ? _red : _green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(ownerName,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary.withValues(alpha: 0.9))),
                    const SizedBox(width: 12),
                    Icon(Icons.email_outlined, size: 13, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(email,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 13, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(phone,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: textSecondary)),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: textSecondary),
                    const SizedBox(width: 4),
                    Text('Joined $dateStr',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: textSecondary)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Action Buttons
          Row(
            children: [
              _ActionButton(
                icon: isBlocked
                    ? Icons.lock_open_rounded
                    : Icons.block_rounded,
                tooltip: isBlocked ? 'Unblock Account' : 'Block Account',
                color: isBlocked ? _green : _red,
                bg: (isBlocked ? _green : _red).withValues(alpha: 0.1),
                onTap: () => _toggleBlockUser(user),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.lock_reset_rounded,
                tooltip: 'Send Password Reset Email',
                color: _amber,
                bg: _amber.withValues(alpha: 0.1),
                onTap: () => _resetPassword(user),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.delete_forever_rounded,
                tooltip: 'Delete Account Permanently',
                color: _red,
                bg: _red.withValues(alpha: 0.1),
                onTap: () => _deleteUser(user),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 9, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    this.color = const Color(0xFFF5A623),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inactiveBorder = isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0);
    final inactiveText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : inactiveBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color.withValues(alpha: 0.5) : inactiveBorder),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? color : inactiveText)),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
