import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/registration_service.dart';
import '../../shared/providers/license_provider.dart';
import '../../shared/providers/supabase_providers.dart';

class UpgradeRequestScreen extends ConsumerStatefulWidget {
  const UpgradeRequestScreen({super.key});

  @override
  ConsumerState<UpgradeRequestScreen> createState() => _UpgradeRequestScreenState();
}

class _UpgradeRequestScreenState extends ConsumerState<UpgradeRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedPaymentMethod = 'Easypaisa';
  String? _selectedUpgradeType; // 'to_full_access', 'to_3yr', 'mobile_to_3yr'
  int _selectedAmount = 23000;
  XFile? _screenshotFile;
  bool _isLoading = false;

  final List<String> _paymentMethods = ['Easypaisa', 'JazzCash', 'Bank Transfer'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _screenshotFile = pickedFile;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedUpgradeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an upgrade option.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate() || _screenshotFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and upload a screenshot.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final shopId = ref.read(currentShopIdProvider);
      if (shopId == null) throw Exception('Shop ID not found');

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_screenshotFile!.name}';
      final fileBytes = await _screenshotFile!.readAsBytes();

      await Supabase.instance.client.storage
          .from('upgrade-screenshots')
          .uploadBinary(
            '$shopId/$fileName',
            fileBytes,
          );

      final screenshotUrl = Supabase.instance.client.storage
          .from('upgrade-screenshots')
          .getPublicUrl('$shopId/$fileName');

      await RegistrationService.instance.submitUpgradeRequest(
        shopId: shopId,
        screenshotUrl: screenshotUrl,
        transactionId: 'RECEIPT_ATTACHED',
        paymentMethod: _selectedPaymentMethod,
        upgradeType: _selectedUpgradeType!,
        amount: _selectedAmount,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Your upgrade request is under review. We\'ll process it within 1-2 business days.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const amber = Color(0xFFF5A623);
    const teal = Color(0xFF10CBA0);

    final license = ref.watch(licenseProvider);
    final shopAsync = ref.watch(currentShopProvider);
    final shopPlan = (shopAsync.value?['plan'] as String?) ?? (shopAsync.value?['plan_type'] as String?) ?? license.plan;
    final currentPlan = shopPlan.toLowerCase();


    // Determine available upgrade options based on current plan
    final isMobileOnly = currentPlan == 'mobile_only' || currentPlan == 'free' || currentPlan.contains('mobile');
    final isFullAccess = currentPlan == 'full_access' || currentPlan == 'pro';
    final is3Yr = currentPlan == 'full_access_3yr';

    // Auto-select default option if not set
    if (_selectedUpgradeType == null) {
      if (isMobileOnly) {
        _selectedUpgradeType = 'to_full_access';
        _selectedAmount = 23000;
      } else if (isFullAccess) {
        _selectedUpgradeType = 'to_3yr';
        _selectedAmount = 35000;
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Upgrade License Plan', style: GoogleFonts.outfit(color: textPrimary)),
        backgroundColor: surface,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: is3Yr
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      'Highest Tier Active!',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are on Full Access + 3 Years Unlimited Storage. No upgrade needed.',
                      style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Upgrade Option', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 12),

                    // Contextual options for mobile_only
                    if (isMobileOnly) ...[
                      _buildOptionCard(
                        id: 'to_full_access',
                        title: 'Upgrade to 🚀 Professional Plan',
                        price: 'Rs 23,000',
                        amount: 23000,
                        description: 'Unlock Web + Windows Desktop apps, Ad-Free workspace, Thermal Printing, and Level 1-2 Invite Profit.',
                        surface: surface,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accentColor: amber,
                      ),
                      const SizedBox(height: 12),
                      _buildOptionCard(
                        id: 'mobile_to_3yr',
                        title: 'Direct Jump: 👑 Enterprise Plan',
                        price: 'Rs 58,000',
                        amount: 58000,
                        description: 'Unlock Web, Desktop, 3 Years Unlimited Cloud Storage, and Level 1-4 Max Invite Profit.',
                        surface: surface,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accentColor: teal,
                        badge: '👑 BEST VALUE',
                      ),
                    ],

                    // Option for full_access
                    if (isFullAccess) ...[
                      _buildOptionCard(
                        id: 'to_3yr',
                        title: 'Upgrade to 👑 Enterprise Plan',
                        price: 'Rs 35,000',
                        amount: 35000,
                        description: 'Add 3 Years Unlimited Cloud Storage and unlock Level 1-4 Max Invite Profit.',
                        surface: surface,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        accentColor: teal,
                        badge: '💎 BEST VALUE',
                      ),
                    ],

                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Instructions:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textPrimary)),
                          const SizedBox(height: 6),
                          Text(
                            'Transfer Rs ${_selectedAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} to Easypaisa / JazzCash / Bank Transfer.\nThen upload receipt screenshot below.',
                            style: GoogleFonts.inter(color: textSecondary, height: 1.4, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPaymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Payment Method',
                        filled: true,
                        fillColor: surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem(value: method, child: Text(method, style: TextStyle(color: textPrimary)));
                      }).toList(),
                      dropdownColor: surface,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPaymentMethod = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        height: 130,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: amber, style: BorderStyle.solid),
                        ),
                        child: _screenshotFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.upload_file, color: amber, size: 36),
                                  const SizedBox(height: 8),
                                  Text('Upload Payment Screenshot', style: GoogleFonts.inter(color: textPrimary, fontSize: 13)),
                                ],
                              )
                            : Center(
                                child: Text('Selected: ${_screenshotFile!.name}',
                                    style: GoogleFonts.inter(color: textPrimary), textAlign: TextAlign.center),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : Text('Submit Upgrade Request', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOptionCard({
    required String id,
    required String title,
    required String price,
    required int amount,
    required String description,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color accentColor,
    String? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedUpgradeType == id;

    final cardBg = isDark
        ? (isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.18),
                  const Color(0xFF0F172A),
                ],
              )
            : const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ))
        : (isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.10),
                  Colors.white,
                ],
              )
            : const LinearGradient(
                colors: [Colors.white, Color(0xFFFAFAFC)],
              ));

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUpgradeType = id;
          _selectedAmount = amount;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                blurRadius: 18,
                offset: const Offset(0, 6),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, accentColor.withValues(alpha: 0.85)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? accentColor : textPrimary,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accentColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                      width: isSelected ? 0 : 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ upgrade fee (one-time)',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
