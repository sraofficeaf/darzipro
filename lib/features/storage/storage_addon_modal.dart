import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/storage_service.dart';
import '../../shared/providers/supabase_providers.dart';

class StorageAddonModal extends ConsumerStatefulWidget {
  const StorageAddonModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const StorageAddonModal(),
    );
  }

  @override
  ConsumerState<StorageAddonModal> createState() => _StorageAddonModalState();
}

class _StorageAddonModalState extends ConsumerState<StorageAddonModal> {
  final _txnCtrl = TextEditingController();
  String _paymentMethod = 'Easypaisa';
  String _selectedAddonType = 'monthly'; // 'monthly' or 'annual'
  int _selectedAmount = 1200;            // 1200 or 10000
  Uint8List? _screenshotBytes;
  bool _isLoading = false;
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _txnCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _screenshotBytes = bytes;
    });
  }

  Future<void> _submit() async {
    final txn = _txnCtrl.text.trim();
    if (txn.isEmpty) {
      setState(() => _error = 'Please enter transaction ID');
      return;
    }
    if (_screenshotBytes == null) {
      setState(() => _error = 'Please upload payment screenshot');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final shopId = ref.read(currentShopIdProvider);
      if (shopId == null) throw Exception('Shop not found');

      // Upload screenshot
      final ext = 'jpg';
      final path = '$shopId-storage-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage
          .from('storage-addon-screenshots')
          .uploadBinary(path, _screenshotBytes!);
      final url = Supabase.instance.client.storage
          .from('storage-addon-screenshots')
          .getPublicUrl(path);

      final result = await StorageService.instance.submitStorageAddonPayment(
        shopId: shopId,
        screenshotUrl: url,
        paymentMethod: _paymentMethod,
        transactionId: txn,
        addonType: _selectedAddonType,
        amount: _selectedAmount,
      );

      if (result['success'] == true) {
        setState(() {
          _submitted = true;
        });
      } else {
        setState(() {
          _error = result['error']?.toString() ?? 'Submission failed';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const amber = Color(0xFFF5A623);
    const teal = Color(0xFF10CBA0);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: _submitted
          ? _buildSuccess(textPrimary, textSecondary, amber)
          : _buildForm(isDark, textPrimary, textSecondary, amber, teal),
    );
  }

  Widget _buildSuccess(Color textPrimary, Color textSecondary, Color amber) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 64),
        const SizedBox(height: 16),
        Text('Request Submitted!',
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Your storage add-on payment is under review. We will activate it within 24 hours.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: textSecondary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(bool isDark, Color textPrimary, Color textSecondary, Color amber, Color teal) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Storage Add-on',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary)),
              IconButton(
                icon: Icon(Icons.close_rounded, color: textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Plan Option Cards: Monthly vs Annual
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  id: 'monthly',
                  title: 'Monthly',
                  price: 'Rs 1,200',
                  subtitle: '/ month',
                  amount: 1200,
                  isSelected: _selectedAddonType == 'monthly',
                  accentColor: amber,
                  surface: surfaceBg(isDark),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  id: 'annual',
                  title: 'Annual',
                  price: 'Rs 10,000',
                  subtitle: '/ year',
                  badge: 'SAVE 31%',
                  amount: 10000,
                  isSelected: _selectedAddonType == 'annual',
                  accentColor: teal,
                  surface: surfaceBg(isDark),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: amber.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Transfer Rs ${_selectedAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} via Easypaisa/JazzCash/Bank, then upload receipt screenshot below.',
              style: GoogleFonts.inter(fontSize: 13, color: textPrimary, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: InputDecoration(
              labelText: 'Payment Method',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: ['Easypaisa', 'JazzCash', 'Bank Transfer']
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _paymentMethod = v ?? 'Easypaisa'),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _txnCtrl,
            decoration: InputDecoration(
              labelText: 'Transaction ID / Ref *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: _pickScreenshot,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _screenshotBytes != null
                        ? amber
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
              ),
              child: Center(
                child: _screenshotBytes != null
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF10B981)),
                          SizedBox(width: 8),
                          Text('Screenshot uploaded'),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upload_rounded, color: textSecondary),
                          Text('Upload Payment Screenshot *',
                              style: GoogleFonts.inter(color: textSecondary, fontSize: 13)),
                        ],
                      ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF3A58), fontSize: 13)),
          ],
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text('Submit Storage Request (Rs ${_selectedAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')})',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Color surfaceBg(bool isDark) => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  Widget _buildTypeOption({
    required String id,
    required String title,
    required String price,
    required String subtitle,
    required int amount,
    required bool isSelected,
    required Color accentColor,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    String? badge,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddonType = id;
          _selectedAmount = amount;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.12) : surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : textSecondary.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? accentColor : textPrimary,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? accentColor : textSecondary,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 10, color: textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
