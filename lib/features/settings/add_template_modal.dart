import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/step_indicator.dart';
import '../../../../core/widgets/modal_footer.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/supabase_providers.dart';
import '../../../../shared/providers/license_provider.dart';

class AddTemplateModal extends ConsumerStatefulWidget {
  const AddTemplateModal({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      barrierDismissible: false,
      barrierLabel: 'AddTemplateModal',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: const AddTemplateModal(),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<AddTemplateModal> createState() => _AddTemplateModalState();
}

class _AddTemplateModalState extends ConsumerState<AddTemplateModal> {
  int _currentStep = 1;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'men'; // 'men' / 'women' / 'children'
  bool _isSaving = false;

  final Map<String, Map<String, String>> _fieldsInfo = {
    'lambai': {'en': 'Length', 'ur': 'لمبائی'},
    'chhaati': {'en': 'Chest', 'ur': 'چھاتی'},
    'kamar': {'en': 'Waist', 'ur': 'کمر'},
    'teerwa': {'en': 'Shoulder', 'ur': 'تیرا'},
    'bazo': {'en': 'Sleeve', 'ur': 'بازو'},
    'daman': {'en': 'Daman', 'ur': 'دامن'},
    'baghal': {'en': 'Armhole (Baghal)', 'ur': 'بغل'},
    'collar': {'en': 'Collar', 'ur': 'کالر'},
    'shalwar': {'en': 'Shalwar Length', 'ur': 'شلوار'},
    'panche': {'en': 'Panche', 'ur': 'پانچے'},
    'kaf': {'en': 'Cuff (Kaf)', 'ur': 'کف'},
    'jeb': {'en': 'Pocket (Jeb)', 'ur': 'جیب'},
    'gol': {'en': 'Gol', 'ur': 'گول'},
    'asan': {'en': 'Asan', 'ur': 'آسن'},
    'nara': {'en': 'Nara', 'ur': 'ناڑا'},
    'gareban': {'en': 'Gareban', 'ur': 'گریبان'},
  };

  late Map<String, bool> _selectedFields;

  @override
  void initState() {
    super.initState();
    // Default pre-selected fields
    _selectedFields = {
      'lambai': true,
      'chhaati': true,
      'kamar': true,
      'teerwa': true,
      'bazo': true,
      'daman': true,
      'baghal': true,
      'collar': true,
      'shalwar': true,
      'panche': true,
      'kaf': false,
      'jeb': false,
      'gol': false,
      'asan': false,
      'nara': false,
      'gareban': false,
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep == 1) {
      if (_nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Template Name is required',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else {
      _save();
    }
  }

  void _back() {
    if (_currentStep == 2) {
      setState(() => _currentStep = 1);
    }
  }

  Future<void> _save() async {
    final selectedKeys = _selectedFields.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Please select at least one field',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) {
      setState(() => _isSaving = false);
      return;
    }

    final id = const Uuid().v4();
    final newTemplate = {
      'id': id,
      'shop_id': shopId,
      'name': _nameCtrl.text.trim(),
      'category': _category,
      'fields': selectedKeys,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final license = ref.read(licenseProvider);
      final Box settingsBox = Hive.box('settings_box');

      if (license.isCloudEnabled) {
        final supabase = ref.read(supabaseClientProvider);
        await supabase.from('measurement_templates').insert(newTemplate);
      } else {
        // Offline / local cache
        final cached = settingsBox.get('templates_$shopId');
        final List<Map<String, dynamic>> currentList = cached != null
            ? List<Map<String, dynamic>>.from(cached as List)
            : [];
        // Add default templates first if cached list is empty
        if (currentList.isEmpty) {
          final defaultTemplates = [
            {
              'id': 'temp_men_shalwar_kameez',
              'shop_id': 'default',
              'name': 'Shalwar Kameez (Men)',
              'category': 'men',
              'fields': ['lambai', 'teerwa', 'bazo', 'chhaati', 'baghal', 'kamar', 'daman', 'collar', 'shalwar', 'panche'],
              'created_at': '2026-06-22T00:00:00.000Z',
            },
            {
              'id': 'temp_women_kurti',
              'shop_id': 'default',
              'name': 'Kurti / Suit (Women)',
              'category': 'women',
              'fields': ['lambai', 'teerwa', 'bazo', 'chhaati', 'kamar', 'hip', 'daman', 'gala', 'shalwar', 'panche'],
              'created_at': '2026-06-22T00:00:00.000Z',
            },
          ];
          currentList.addAll(defaultTemplates);
        }
        currentList.add(newTemplate);
        await settingsBox.put('templates_$shopId', currentList);
      }

      // Invalidate templates provider to trigger UI reload
      ref.invalidate(measurementTemplatesProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Template saved ✓',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Save failed: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double width = 760.0;
    return AppModal(
      title: 'Add Custom Template',
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step progress indicator
          StepIndicator(
            totalSteps: 2,
            currentStep: _currentStep,
            labels: const ['Template Info', 'Select Fields'],
          ),
          
          const SizedBox(height: 10),

          // Scrollable body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),

          // Footer
          ModalFooter(
            currentStep: _currentStep,
            totalSteps: 2,
            onNext: _next,
            onBack: _back,
            nextLabel: _currentStep == 1 ? 'Next →' : 'Save Template ✓',
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        AppTextField(
          label: 'Template Name (Required)',
          hint: 'e.g. Kurta, Waistcoat, Sherwani',
          controller: _nameCtrl,
          prefix: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.bookmark_added_rounded, size: 18, color: Color(0xFF2D4060)),
          ),
        ),
        const SizedBox(height: 18),

        // Category Selector
        Text(
          'CATEGORY',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF3D5470),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCategoryOption('men', '👔', 'Men'),
            const SizedBox(width: 8),
            _buildCategoryOption('women', '👗', 'Women'),
            const SizedBox(width: 8),
            _buildCategoryOption('children', '👕', 'Children'),
          ],
        ),
        const SizedBox(height: 18),

        // Description
        AppTextField(
          label: 'Description (Optional)',
          hint: 'Describe the style, fittings, etc.',
          controller: _descCtrl,
          prefix: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.description_rounded, size: 18, color: Color(0xFF2D4060)),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE MEASUREMENT FIELDS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF3D5470),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _fieldsInfo.length,
          itemBuilder: (context, index) {
            final key = _fieldsInfo.keys.elementAt(index);
            final info = _fieldsInfo[key];
            if (info == null) return const SizedBox();
            final isChecked = _selectedFields[key] ?? false;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedFields[key] = !isChecked;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isChecked ? const Color(0x0C10CBA0) : Colors.white.withValues(alpha: 0.02),
                  border: Border.all(
                    color: isChecked ? const Color(0x2610CBA0) : Colors.white.withValues(alpha: 0.05),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isChecked,
                      activeColor: const Color(0xFF10CBA0),
                      onChanged: (val) {
                        setState(() {
                          _selectedFields[key] = val ?? false;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info['ur'] ?? '',
                            style: GoogleFonts.notoNaskhArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isChecked ? const Color(0xFF10CBA0) : const Color(0xFFEDF4FF),
                            ),
                          ),
                          Text(
                            info['en'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: const Color(0xFF8AA0B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryOption(String cat, String emoji, String label) {
    final isSelected = _category == cat;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _category = cat);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0x14F5A623) : const Color(0x08FFFFFF),
            border: Border.all(
              color: isSelected ? const Color(0xFFF5A623) : const Color(0x12FFFFFF),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFFF5A623) : const Color(0xFF3D5470),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
