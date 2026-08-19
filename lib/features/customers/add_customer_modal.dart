import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/app_modal.dart';
import '../../core/widgets/modal_footer.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/step_indicator.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';

class AddCustomerModal extends ConsumerStatefulWidget {
  const AddCustomerModal({super.key});

  static Future<CustomerModel?> show(BuildContext context) {
    return const AppModal(
      title: 'Add New Client',
      width: 760,
      child: AddCustomerModal(),
    ).show<CustomerModel>(context);
  }

  @override
  ConsumerState<AddCustomerModal> createState() => _AddCustomerModalState();
}

class _AddCustomerModalState extends ConsumerState<AddCustomerModal> {
  int _currentStep = 1; // 1, 2, 3
  bool _isSaving = false;
  CustomerModel? _savedCustomer;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();

  CustomerGender? _gender = CustomerGender.male;
  DateTime? _birthday;

  // Shake keys for validation
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();

  // Error messages
  String? _nameError;
  String? _phoneError;
  String? _genderError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _whatsappCtrl.dispose();
    _notesCtrl.dispose();
    _birthdayCtrl.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    setState(() {
      _nameError = null;
      _phoneError = null;
    });

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    bool isValid = true;

    if (name.length < 2) {
      setState(() => _nameError = 'Name must be at least 2 characters');
      isValid = false;
    }
    if (phone.length < 10) {
      setState(() => _phoneError = 'Phone must be at least 10 digits');
      isValid = false;
    }

    if (!isValid) {
      _shakeKey.currentState?.shake();
      HapticFeedback.vibrate();
    }
    return isValid;
  }

  bool _validateStep2() {
    setState(() {
      _genderError = null;
    });

    if (_gender == null) {
      setState(() => _genderError = 'Please select a gender');
      _shakeKey.currentState?.shake();
      HapticFeedback.vibrate();
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (_validateStep1()) {
        setState(() => _currentStep = 2);
      }
    } else if (_currentStep == 2) {
      if (_validateStep2()) {
        setState(() => _currentStep = 3);
      }
    } else if (_currentStep == 3) {
      _save();
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFFF5A623),
                    onPrimary: Color(0xFF1A0A00),
                    surface: Color(0xFF0F1C30),
                    onSurface: Color(0xFFEDF4FF),
                  ),
                  dialogTheme: const DialogThemeData(
                    backgroundColor: Color(0xFF0F1C30),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFFD97706),
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
        _birthdayCtrl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final List<String> notesParts = [];
    if (_notesCtrl.text.trim().isNotEmpty) {
      notesParts.add(_notesCtrl.text.trim());
    }
    if (_whatsappCtrl.text.trim().isNotEmpty) {
      notesParts.add('WhatsApp: ${_whatsappCtrl.text.trim()}');
    }
    if (_birthdayCtrl.text.trim().isNotEmpty) {
      notesParts.add('Birthday: ${_birthdayCtrl.text.trim()}');
    }
    final finalNotes = notesParts.isEmpty ? null : notesParts.join('\n');

    final newCustomer = CustomerModel(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      gender: _gender ?? CustomerGender.male,
      notes: finalNotes,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(customersProvider.notifier).addCustomer(newCustomer);
      setState(() {
        _isSaving = false;
        _savedCustomer = newCustomer;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to save client: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _currentStep = 1;
      _isSaving = false;
      _savedCustomer = null;
      _gender = CustomerGender.male;
      _birthday = null;
      _nameError = null;
      _phoneError = null;
      _genderError = null;
    });
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _whatsappCtrl.clear();
    _notesCtrl.clear();
    _birthdayCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_savedCustomer != null) {
      return _buildSuccessState();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StepIndicator(
          totalSteps: 3,
          currentStep: _currentStep,
          labels: const ['Personal', 'Gender & WA', 'Notes & Summary'],
        ),
        const SizedBox(height: 14),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShakeWidget(
              key: _shakeKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: _buildStepContent(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ModalFooter(
          currentStep: _currentStep,
          totalSteps: 3,
          onNext: _nextStep,
          onBack: _prevStep,
          nextLabel: _currentStep == 3 ? 'Save Client' : 'Next Step',
          isLoading: _isSaving,
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return Column(
          key: const ValueKey('step_1'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Full Name',
              controller: _nameCtrl,
              hint: 'e.g. Saifur Rahman',
              prefix: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF2D4060)),
            ),
            if (_nameError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(_nameError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
              ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Phone Number',
              controller: _phoneCtrl,
              hint: '0300-1234567',
              keyboardType: TextInputType.phone,
              prefix: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF2D4060)),
            ),
            if (_phoneError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(_phoneError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
              ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Address (Optional)',
              controller: _addressCtrl,
              hint: 'Saddar, Peshawar',
              prefix: const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF2D4060)),
            ),
            const SizedBox(height: 10),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey('step_2'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GENDER',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: const Color(0xFF5A7090),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGenderOption(CustomerGender.male, '👔', 'Men'),
                const SizedBox(width: 10),
                _buildGenderOption(CustomerGender.female, '👗', 'Women'),
                const SizedBox(width: 10),
                _buildGenderOption(CustomerGender.child, '👕', 'Children'),
              ],
            ),
            if (_genderError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(_genderError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
              ),
            const SizedBox(height: 18),
            AppTextField(
              label: 'WhatsApp Number (Optional)',
              controller: _whatsappCtrl,
              hint: 'Same as phone or different',
              keyboardType: TextInputType.phone,
              prefix: const Icon(Icons.chat_rounded, size: 16, color: Color(0xFF2D4060)),
            ),
            const SizedBox(height: 10),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey('step_3'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Special Instructions (Optional)',
              controller: _notesCtrl,
              hint: 'Special instructions, preferences...',
              maxLines: 3,
              prefix: const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF2D4060)),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _selectBirthday(context),
              child: AbsorbPointer(
                child: AppTextField(
                  label: 'Birthday (Optional)',
                  controller: _birthdayCtrl,
                  hint: 'Select birthday',
                  prefix: const Icon(Icons.cake_rounded, size: 16, color: Color(0xFF2D4060)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x0FF5A623),
                border: Border.all(color: const Color(0x26F5A623), width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLIENT SUMMARY',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF5A623),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSummaryRow('Name', _nameCtrl.text.trim()),
                  _buildSummaryRow('Phone', _phoneCtrl.text.trim()),
                  _buildSummaryRow('Gender', _gender?.label ?? 'Not Specified'),
                  if (_addressCtrl.text.trim().isNotEmpty)
                    _buildSummaryRow('Address', _addressCtrl.text.trim()),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.text2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: context.text1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption(CustomerGender g, String emoji, String labelText) {
    final isActive = _gender == g;

    Color bg = const Color(0x08FFFFFF);
    Color border = const Color(0x12FFFFFF);
    Color labelColor = const Color(0xFF3D5470);
    List<BoxShadow>? shadows;

    if (isActive) {
      bg = const Color(0x14F5A623);
      border = const Color(0xFFF5A623);
      labelColor = const Color(0xFFF5A623);
      shadows = const [
        BoxShadow(color: Color(0x26F5A623), blurRadius: 16),
        BoxShadow(color: Color(0x26F5A623), blurRadius: 1),
      ];
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _gender = g);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 2),
            borderRadius: BorderRadius.circular(14),
            boxShadow: shadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                labelText,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Client Added!',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.text1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _savedCustomer?.name ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.text2,
            ),
          ),
          const SizedBox(height: 32),
          // Action Buttons
          _buildActionButton(
            label: '➕ Add Another',
            gradient: const LinearGradient(colors: [Color(0xFFF5A623), Color(0xFFD97706)]),
            onPressed: _resetForm,
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: '📏 Take Measurements',
            gradient: const LinearGradient(colors: [Color(0xFF10CBA0), Color(0xFF059669)]),
            onPressed: () {
              final saved = _savedCustomer;
              if (saved != null) {
                ref.read(selectedMeasurementCustomerIdProvider.notifier).state = saved.id;
                Navigator.of(context).pop(saved);
                context.go('/measurements/${saved.id}/${Uri.encodeComponent(saved.name)}');
              }
            },
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: '✕ Close',
            color: context.isDark ? Colors.white.withValues(alpha: 0.06) : context.surface2,
            border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.08) : context.border),
            onPressed: () => Navigator.pop(context, _savedCustomer),
            textColor: context.text2,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    LinearGradient? gradient,
    Color? color,
    BoxBorder? border,
    required VoidCallback onPressed,
    Color textColor = const Color(0xFF1A0A00),
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        color: color,
        border: border,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── SHAKE WIDGET ─────────────────────────────────────────────────────────────
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final double shakeOffset;
  final int shakeCount;
  final Duration shakeDuration;

  const ShakeWidget({
    super.key,
    required this.child,
    this.shakeOffset = 6.0,
    this.shakeCount = 3,
    this.shakeDuration = const Duration(milliseconds: 300),
  });

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.shakeDuration,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final double sineValue = math.sin(widget.shakeCount * 2 * math.pi * _controller.value);
        return Transform.translate(
          offset: Offset(sineValue * widget.shakeOffset * (1.0 - _controller.value), 0),
          child: child,
        );
      },
    );
  }
}
