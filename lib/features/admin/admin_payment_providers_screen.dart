import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/theme_extensions.dart';
import 'widgets/admin_ui_kit.dart';

class AdminPaymentProvidersScreen extends ConsumerStatefulWidget {
  const AdminPaymentProvidersScreen({super.key});

  @override
  ConsumerState<AdminPaymentProvidersScreen> createState() =>
      _AdminPaymentProvidersScreenState();
}

class _AdminPaymentProvidersScreenState
    extends ConsumerState<AdminPaymentProvidersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _providers = [];
  Map<String, dynamic>? _stripeHealth;
  String? _errorMessage;

  // Common country choices
  static const List<String> _commonCountries = ['*', 'PK', 'US', 'GB', 'AE', 'SA', 'CA'];
  // Common currency choices
  static const List<String> _commonCurrencies = ['*', 'PKR', 'USD', 'EUR', 'GBP', 'AED'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;

      // 1. Fetch providers from database via AdminService
      _providers = await AdminService.instance.fetchPaymentProviders();

      // 2. Check Stripe secrets health via Edge Function
      try {
        final res = await client.functions.invoke(
          'stripe-payment',
          body: {'action': 'health'},
        );
        if (res.status == 200 && res.data is Map) {
          _stripeHealth = Map<String, dynamic>.from(res.data);
        }
      } catch (healthErr) {
        debugPrint('Stripe health check warning: $healthErr');
        _stripeHealth = {'configured': false, 'error': healthErr.toString()};
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProvider({
    required String code,
    bool? enabled,
    String? displayName,
    int? priority,
    List<String>? allowedCountries,
    List<String>? supportedCurrencies,
  }) async {
    try {
      final updated = await AdminService.instance.updatePaymentProvider(
        code: code,
        enabled: enabled,
        displayName: displayName,
        priority: priority,
        allowedCountries: allowedCountries,
        supportedCurrencies: supportedCurrencies,
      );

      // Verify that enabled matches what was requested
      if (enabled != null && updated['enabled'] != enabled) {
        throw Exception(
          'Server state mismatch: expected enabled=$enabled, received ${updated['enabled']}',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment provider updated successfully!')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update provider: $e'),
          backgroundColor: AdminColors.rose,
        ),
      );
      await _loadData();
    }
  }

  void _showEditDialog(Map<String, dynamic> provider) {
    final code = provider['code'] as String;
    final nameCtrl = TextEditingController(text: provider['display_name'] ?? '');
    final priorityCtrl = TextEditingController(text: (provider['priority'] ?? 50).toString());
    bool enabled = provider['enabled'] == true;

    final rawCountries = provider['allowed_countries'];
    List<String> countries = rawCountries is List
        ? List<String>.from(rawCountries.map((e) => e.toString().toUpperCase()))
        : ['*'];

    final rawCurrencies = provider['supported_currencies'];
    List<String> currencies = rawCurrencies is List
        ? List<String>.from(rawCurrencies.map((e) => e.toString().toUpperCase()))
        : ['*'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(
            'Edit Provider: ${provider['display_name'] ?? code}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enabled Toggle
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enabled in App'),
                    subtitle: Text(
                      enabled
                          ? 'Available for eligible shops'
                          : 'Hidden from checkout flow',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    value: enabled,
                    activeTrackColor: AdminColors.emerald,
                    onChanged: (val) => setDlgState(() => enabled = val),
                  ),
                  const SizedBox(height: 12),

                  // Display Name
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Priority (lower = shown first)
                  TextField(
                    controller: priorityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Priority (lower = shown first)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Allowed Countries
                  Text(
                    'Allowed Countries (* for all):',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _commonCountries.map((c) {
                      final has = countries.contains(c);
                      return FilterChip(
                        label: Text(c == '*' ? 'All (*)' : c),
                        selected: has,
                        onSelected: (selected) {
                          setDlgState(() {
                            if (c == '*') {
                              countries = selected ? ['*'] : [];
                            } else {
                              countries.remove('*');
                              if (selected) {
                                countries.add(c);
                              } else {
                                countries.remove(c);
                              }
                              if (countries.isEmpty) countries = ['*'];
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Supported Currencies
                  Text(
                    'Supported Currencies (* for all):',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _commonCurrencies.map((cur) {
                      final has = currencies.contains(cur);
                      return FilterChip(
                        label: Text(cur == '*' ? 'All (*)' : cur),
                        selected: has,
                        onSelected: (selected) {
                          setDlgState(() {
                            if (cur == '*') {
                              currencies = selected ? ['*'] : [];
                            } else {
                              currencies.remove('*');
                              if (selected) {
                                currencies.add(cur);
                              } else {
                                currencies.remove(cur);
                              }
                              if (currencies.isEmpty) currencies = ['*'];
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateProvider(
                  code: code,
                  displayName: nameCtrl.text.trim(),
                  priority: int.tryParse(priorityCtrl.text.trim()) ?? 50,
                  enabled: enabled,
                  allowedCountries: countries,
                  supportedCurrencies: currencies,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emerald),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.bg;
    final surface = context.surface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            AdminPageHeader(
              title: 'Payment Providers',
              subtitle: 'Configure multi-provider checkout, currencies, and gateway integrations',
              action: AdminIconBtn(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh Providers',
                onPressed: _loadData,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text('Error: $_errorMessage'))
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // ── Security & Secrets Notice ────────────────────
                            _buildSecurityCard(surface),
                            const SizedBox(height: 20),

                            // ── Providers List ──────────────────────────────
                            Text(
                              'Configured Payment Gateways',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.text1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._providers.map((p) => _buildProviderCard(p, surface)),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard(Color surface) {
    final isStripeConfigured = _stripeHealth?['configured'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AdminColors.emerald, size: 22),
              const SizedBox(width: 8),
              Text(
                'Payment Secrets & Environment Isolation',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.text1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'In accordance with PCI compliance and adapter architecture, private provider API keys '
            '(Stripe Secret Key & Webhook Secret) live strictly in the Supabase Edge Function environment. '
            'They are never stored in the database or sent to client applications.',
            style: GoogleFonts.inter(fontSize: 12.5, color: context.text2, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isStripeConfigured
                      ? AdminColors.emerald.withValues(alpha: 0.15)
                      : AdminColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isStripeConfigured
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      size: 16,
                      color: isStripeConfigured
                          ? AdminColors.emerald
                          : AdminColors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isStripeConfigured
                          ? 'Stripe Secrets: Active & Configured (VPS Env)'
                          : 'Stripe Secrets: Not Detected in Edge Env (Set in VPS/Coolify)',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isStripeConfigured
                            ? AdminColors.emerald
                            : AdminColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider, Color surface) {
    final code = provider['code'] as String;
    final displayName = provider['display_name'] as String? ?? code;
    final enabled = provider['enabled'] == true;
    final priority = provider['priority'] ?? 50;
    final isInstant = provider['is_instant'] == true;
    final countries = (provider['allowed_countries'] as List?)?.join(', ') ?? '*';
    final currencies = (provider['supported_currencies'] as List?)?.join(', ') ?? '*';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.border),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: enabled
                    ? AdminColors.blue.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isInstant ? Icons.credit_card_rounded : Icons.account_balance_rounded,
                color: enabled ? AdminColors.blue : Colors.grey,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.text1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isInstant
                              ? AdminColors.emerald.withValues(alpha: 0.15)
                              : AdminColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isInstant ? '⚡ Instant' : '🕒 Review Required',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isInstant ? AdminColors.emerald : AdminColors.amber,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Switch.adaptive(
                        value: enabled,
                        activeTrackColor: AdminColors.emerald,
                        onChanged: (val) {
                          _updateProvider(code: code, enabled: val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text(
                        'Priority: $priority',
                        style: GoogleFonts.inter(fontSize: 12, color: context.text2),
                      ),
                      Text(
                        'Countries: $countries',
                        style: GoogleFonts.inter(fontSize: 12, color: context.text2),
                      ),
                      Text(
                        'Currencies: $currencies',
                        style: GoogleFonts.inter(fontSize: 12, color: context.text2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit Provider',
              onPressed: () => _showEditDialog(provider),
            ),
          ],
        ),
      ),
    );
  }
}
