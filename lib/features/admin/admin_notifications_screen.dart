import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import 'widgets/admin_ui_kit.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  String _targetGroup = 'all';
  String _template = 'renewal';
  String _recipientSearchQuery = '';
  final _messageCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  final Map<String, String> _templates = {
    'renewal': 'Assalam-o-Alaikum {OwnerName}, aapka Darzi Pro ({ShopName}) plan {ExpiryDate} ko expire ho raha hai. Service jaari rakhne ke liye payment confirm karein. Shukriya!',
    'feature': 'Darzi Pro updates! Humne app me naya Features aur reports add kiya hai. Aaj hi playstore se update karein!',
    'payment': 'Assalam-o-Alaikum, aapka monthly license key payment confirm nahi ho saka. Please confirmation details support par bhejein.',
    'custom': '',
  };

  @override
  void initState() {
    super.initState();
    _messageCtrl.text = _templates['renewal']!;
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _str(dynamic v, [String fallback = 'N/A']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _getShopName(Map<String, dynamic> s) =>
      _str(s['shop_name'] ?? s['name'] ?? s['shopName'], 'Shop');

  String _getOwnerName(Map<String, dynamic> s) =>
      _str(s['shop_owner_name'] ?? s['owner_name'] ?? s['owner'], 'Shop Owner');

  String _getPhone(Map<String, dynamic> s) =>
      _str(s['whatsapp_number'] ?? s['whatsapp'] ?? s['phone'], '');

  void _applyTemplate(String templateKey) {
    setState(() {
      _template = templateKey;
      _messageCtrl.text = _templates[templateKey] ?? '';
    });
  }

  String _personalizeMessage(String rawMsg, Map<String, dynamic> shop) {
    String msg = rawMsg;
    msg = msg.replaceAll('{OwnerName}', _getOwnerName(shop));
    msg = msg.replaceAll('{ShopName}', _getShopName(shop));

    final expStr = shop['expires_at'] ?? shop['bundled_storage_expires_at'];
    if (expStr != null) {
      final expiry = DateTime.tryParse(expStr.toString());
      if (expiry != null) {
        msg = msg.replaceAll('{ExpiryDate}', DateFormat('dd MMM yyyy').format(expiry));
      } else {
        msg = msg.replaceAll('{ExpiryDate}', 'N/A');
      }
    } else {
      msg = msg.replaceAll('{ExpiryDate}', 'N/A');
    }
    return msg;
  }

  void _sendWhatsAppDirect(Map<String, dynamic> shop) async {
    final phone = _getPhone(shop);
    if (phone.isEmpty || phone == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid phone number for this shop.')),
      );
      return;
    }

    final formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent(_personalizeMessage(_messageCtrl.text, shop));
    final url = Uri.parse('https://wa.me/$formattedPhone?text=$msg');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final licensesAsync = ref.watch(adminLicensesProvider);
    final isMobile = MediaQuery.of(context).size.width < 720;

    final bg = context.bg;
    final surface = context.surface;
    final border = context.border;
    final text1 = context.text1;
    final text2 = context.text2;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header (RepaintBoundary for zero scroll cost)
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'Broadcast & Notifications',
                subtitle: 'Send direct WhatsApp broadcasts & custom announcements to shops',
                action: AdminIconBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh Data',
                  onPressed: () => ref.invalidate(adminLicensesProvider),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: licensesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.indigo)),
                  error: (err, stack) => Text('Error loading shops: $err', style: const TextStyle(color: AdminColors.rose)),
                  data: (licenses) {
                    final now = DateTime.now();

                    // Target Group Filter
                    final targetShops = licenses.where((shop) {
                      final plan = _str(shop['plan'] ?? shop['plan_type'], 'mobile_only').toLowerCase();

                      if (_targetGroup == 'pro') return plan == 'full_access' || plan == 'pro' || plan == 'full_access_3yr';
                      if (_targetGroup == 'free') return plan == 'mobile_only' || plan == 'free';
                      if (_targetGroup == 'expiring') {
                        final expStr = shop['expires_at'] ?? shop['bundled_storage_expires_at'];
                        if (expStr == null) return false;
                        final exp = DateTime.tryParse(expStr.toString());
                        if (exp == null) return false;
                        final diff = exp.difference(now).inDays;
                        return diff >= 0 && diff <= 14;
                      }
                      return true;
                    }).where((shop) {
                      if (_recipientSearchQuery.isEmpty) return true;
                      final sName = _getShopName(shop).toLowerCase();
                      final oName = _getOwnerName(shop).toLowerCase();
                      final phone = _getPhone(shop).toLowerCase();
                      return sName.contains(_recipientSearchQuery) || oName.contains(_recipientSearchQuery) || phone.contains(_recipientSearchQuery);
                    }).toList();

                    final messageFormWidget = RepaintBoundary(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                          boxShadow: context.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1. TARGET RECIPIENTS',
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: text2, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                AdminChip(
                                  label: 'ALL SHOPS (${licenses.length})',
                                  isSelected: _targetGroup == 'all',
                                  onTap: () => setState(() => _targetGroup = 'all'),
                                ),
                                AdminChip(
                                  label: 'FULL ACCESS / PRO',
                                  isSelected: _targetGroup == 'pro',
                                  color: AdminColors.amber,
                                  onTap: () => setState(() => _targetGroup = 'pro'),
                                ),
                                AdminChip(
                                  label: 'MOBILE ONLY',
                                  isSelected: _targetGroup == 'free',
                                  color: AdminColors.blue,
                                  onTap: () => setState(() => _targetGroup = 'free'),
                                ),
                                AdminChip(
                                  label: 'EXPIRING SOON',
                                  isSelected: _targetGroup == 'expiring',
                                  color: AdminColors.rose,
                                  onTap: () => setState(() => _targetGroup = 'expiring'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            Text(
                              '2. CHOOSE MESSAGE TEMPLATE',
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: text2, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                AdminChip(
                                  label: 'RENEWAL REMINDER',
                                  isSelected: _template == 'renewal',
                                  color: AdminColors.amber,
                                  onTap: () => _applyTemplate('renewal'),
                                ),
                                AdminChip(
                                  label: 'FEATURE UPDATE',
                                  isSelected: _template == 'feature',
                                  color: AdminColors.indigo,
                                  onTap: () => _applyTemplate('feature'),
                                ),
                                AdminChip(
                                  label: 'PAYMENT ISSUES',
                                  isSelected: _template == 'payment',
                                  color: AdminColors.rose,
                                  onTap: () => _applyTemplate('payment'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            Text(
                              '3. MESSAGE CONTENT ({OwnerName}, {ShopName}, {ExpiryDate})',
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: text2, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _messageCtrl,
                              maxLines: 4,
                              style: GoogleFonts.inter(fontSize: 13, color: text1),
                              decoration: InputDecoration(
                                hintText: 'Type broadcast message...',
                                hintStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                                filled: true,
                                fillColor: bg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AdminColors.indigo, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final recipientsWidget = Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                        boxShadow: context.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'RECIPIENTS (${targetShops.length})',
                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: text1),
                              ),
                              const AdminBadge(label: 'WhatsApp Ready', color: AdminColors.emerald),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Search bar for recipients
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _recipientSearchQuery = v.trim().toLowerCase()),
                            style: GoogleFonts.inter(fontSize: 13, color: text1),
                            decoration: InputDecoration(
                              hintText: 'Search recipients...',
                              hintStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                              prefixIcon: Icon(Icons.search_rounded, size: 16, color: text2),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              filled: true,
                              fillColor: bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AdminColors.indigo),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (targetShops.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text('No shops match criteria', style: GoogleFonts.inter(color: text2, fontSize: 13)),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: targetShops.length,
                              separatorBuilder: (context, idx) => Divider(height: 1, color: border.withValues(alpha: 0.6)),
                              itemBuilder: (context, idx) {
                                final shop = targetShops[idx];
                                final shopName = _getShopName(shop);
                                final ownerName = _getOwnerName(shop);
                                final phone = _getPhone(shop);

                                return RepaintBoundary(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                    leading: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AdminColors.emerald.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AdminColors.emerald),
                                    ),
                                    title: Text(
                                      shopName,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: text1),
                                    ),
                                    subtitle: Text(
                                      'Owner: $ownerName · ${phone.isNotEmpty && phone != "N/A" ? phone : "No phone"}',
                                      style: GoogleFonts.inter(fontSize: 11, color: text2),
                                    ),
                                    trailing: AdminButton.success(
                                      label: 'Send',
                                      icon: Icons.send_rounded,
                                      onPressed: () => _sendWhatsAppDirect(shop),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );

                    if (isMobile) {
                      return Column(
                        children: [
                          messageFormWidget,
                          const SizedBox(height: 16),
                          recipientsWidget,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: messageFormWidget),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: recipientsWidget),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
