import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../customers/add_customer_modal.dart';
import '../printing/pdf_builder.dart';
import '../printing/widgets/card_image_capturer.dart';
import '../printing/widgets/naap_card_widget.dart';

export 'measurement_field_config.dart';
import 'measurement_field_config.dart';


// ── MAIN MEASUREMENTS SCREEN (3-STEP FLOW) ─────────────────────────────────
class MeasurementsScreen extends ConsumerStatefulWidget {
  final String? customerId;
  final String? customerName;
  final MeasurementCategory? category;
  final String? measurementId;
  final String? profileName;

  const MeasurementsScreen({
    super.key,
    this.customerId,
    this.customerName,
    this.category,
    this.measurementId,
    this.profileName,
  });

  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen> {
  // Step indicator state (0: Setup, 1: Naap, 2: Silai & Design)
  int _currentStep = 0;

  // Controllers & Form State
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final TextEditingController _profileNameCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final FocusNode _profileNameFocusNode = FocusNode();

  // Step 1: Setup State
  MeasurementCategory _selectedCategory = MeasurementCategory.men;
  String _selectedProfileType = 'شلوار قمیض';

  final List<String> _profilePresetTypes = [
    'شلوار قمیض',
    'واسکٹ',
    'شیروانی',
    'کرتا پاجامہ',
    'پینٹ کوٹ',
  ];

  // Step 3: Silai & Design State
  List<Map<String, dynamic>> _silaiOptions = [
    {'label': 'ڈبل سلائی', 'checked': true},
    {'label': 'زنجیری سلائی', 'checked': false},
    {'label': 'سٹیل بٹن', 'checked': true},
    {'label': 'کف پلیٹ نہیں', 'checked': false},
    {'label': 'چاک پٹی کاج', 'checked': false},
    {'label': 'کپڑا بٹن', 'checked': false},
    {'label': 'پلاسٹک بٹن', 'checked': false},
    {'label': 'امبرائیڈری', 'checked': false},
  ];

  String _collarType = 'Standard';
  String _neckStyle = 'Round';
  String _kafStyle = 'Standard';
  String _frontStyle = 'Standard';
  String _pocketType = 'Chest';
  String _shape = 'Straight';
  String _shalwarStyle = 'Straight';

  // Persistence, Drafts & Loading
  String? _currentMeasurementId;
  bool _initialized = false;
  bool _isSaving = false;
  bool _isPrinting = false;
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initControllers();
    _profileNameCtrl.text = widget.profileName ?? 'شلوار قمیض';
    if (widget.profileName != null && !_profilePresetTypes.contains(widget.profileName)) {
      _selectedProfileType = 'custom';
    } else if (widget.profileName != null) {
      _selectedProfileType = widget.profileName!;
    }

    if (widget.category != null) {
      _selectedCategory = widget.category!;
    }

    if (widget.customerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedMeasurementCustomerIdProvider.notifier).state = widget.customerId;
        }
      });
    }
  }

  void _initControllers() {
    for (final field in k15MeasurementFields) {
      _controllers[field.key] = TextEditingController();
      _focusNodes[field.key] = FocusNode();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _profileNameCtrl.dispose();
    _notesCtrl.dispose();
    _profileNameFocusNode.dispose();
    super.dispose();
  }

  // ── DATA LOADING & PRE-FILLING ──────────────────────────────────────────
  void _loadCustomerData(String customerId, [MeasurementModel? specificMeasurement]) {
    for (final ctrl in _controllers.values) {
      ctrl.clear();
    }
    _notesCtrl.clear();

    if (specificMeasurement != null) {
      _currentMeasurementId = specificMeasurement.id;
      _selectedCategory = specificMeasurement.category;
      _profileNameCtrl.text = specificMeasurement.profileName;
      if (_profilePresetTypes.contains(specificMeasurement.profileName)) {
        _selectedProfileType = specificMeasurement.profileName;
      } else {
        _selectedProfileType = 'custom';
      }

      for (final section in specificMeasurement.sections) {
        if (section.title == 'Design Options') {
          for (final f in section.fields) {
            if (f.key == 'collar_type') _collarType = f.value;
            if (f.key == 'neck_style') _neckStyle = f.value;
            if (f.key == 'kaf_style') _kafStyle = f.value;
            if (f.key == 'front_style') _frontStyle = f.value;
            if (f.key == 'pocket_type') _pocketType = f.value;
            if (f.key == 'shape') _shape = f.value;
            if (f.key == 'shalwar_style') _shalwarStyle = f.value;
          }
        } else {
          for (final field in section.fields) {
            if (_controllers.containsKey(field.key)) {
              _controllers[field.key]!.text = field.value;
            }
          }
        }
      }

      if (specificMeasurement.silaiOptions != null && specificMeasurement.silaiOptions!.isNotEmpty) {
        _silaiOptions = specificMeasurement.silaiOptions!.map((o) => Map<String, dynamic>.from(o)).toList();
      }
      _notesCtrl.text = specificMeasurement.silaiNotes ?? '';
      _initialized = true;
      if (mounted) setState(() {});
      return;
    }

    final Box draftBox = Hive.box('naap_drafts_box');
    dynamic draft;
    try {
      final draftKey = widget.measurementId != null
          ? 'draft_${customerId}_${widget.measurementId}'
          : 'draft_$customerId';
      draft = draftBox.get(draftKey) ?? draftBox.get('draft_$customerId');
    } catch (e) {
      debugPrint('Error reading draft from Hive: $e');
    }

    bool draftLoaded = false;
    if (draft is Map) {
      try {
        final data = Map<String, dynamic>.from(draft);
        _selectedCategory = MeasurementCategory.values.firstWhere(
          (c) => c.name == data['category'],
          orElse: () => widget.category ?? MeasurementCategory.men,
        );

        if (data['profile_name'] != null) {
          _profileNameCtrl.text = data['profile_name'] as String;
          if (_profilePresetTypes.contains(_profileNameCtrl.text)) {
            _selectedProfileType = _profileNameCtrl.text;
          } else {
            _selectedProfileType = 'custom';
          }
        }

        final rawValues = data['values'] is Map ? data['values'] as Map : null;
        if (rawValues != null) {
          final values = Map<String, String>.from(rawValues);
          values.forEach((k, v) {
            if (_controllers.containsKey(k)) _controllers[k]!.text = v;
          });
        }

        final rawOptions = data['designOptions'] is Map ? data['designOptions'] as Map : null;
        if (rawOptions != null) {
          final options = Map<String, String>.from(rawOptions);
          if (options.containsKey('collar_type')) _collarType = options['collar_type']!;
          if (options.containsKey('neck_style')) _neckStyle = options['neck_style']!;
          if (options.containsKey('kaf_style')) _kafStyle = options['kaf_style']!;
          if (options.containsKey('front_style')) _frontStyle = options['front_style']!;
          if (options.containsKey('pocket_type')) _pocketType = options['pocket_type']!;
          if (options.containsKey('shape')) _shape = options['shape']!;
          if (options.containsKey('shalwar_style')) _shalwarStyle = options['shalwar_style']!;
        }

        if (data.containsKey('silaiOptions')) {
          final rawOpts = data['silaiOptions'] as List<dynamic>? ?? [];
          _silaiOptions = rawOpts.map((o) => Map<String, dynamic>.from(o as Map)).toList();
        }
        _notesCtrl.text = data['notes'] ?? '';
        draftLoaded = true;
      } catch (e) {
        debugPrint('Error parsing draft: $e');
      }
    }

    if (draftLoaded && _currentMeasurementId == null) {
      final existingMeasurements = ref.read(customerMeasurementsProvider).valueOrNull ?? [];
      final existing = existingMeasurements.where(
        (m) => m.customerId == customerId &&
               m.profileName.trim().toLowerCase() == _profileNameCtrl.text.trim().toLowerCase(),
      ).firstOrNull;
      if (existing != null) {
        _currentMeasurementId = existing.id;
      }
    }

    if (!draftLoaded) {
      try {
        final existingMeasurements = ref.read(customerMeasurementsProvider).valueOrNull ?? [];
        MeasurementModel? existing;
        if (widget.measurementId != null) {
          existing = existingMeasurements.where((m) => m.id == widget.measurementId).firstOrNull;
        } else {
          existing = existingMeasurements.where((m) => m.customerId == customerId).firstOrNull;
        }

        if (existing != null) {
          _currentMeasurementId = existing.id;
          _selectedCategory = existing.category;
          _profileNameCtrl.text = existing.profileName;
          if (_profilePresetTypes.contains(existing.profileName)) {
            _selectedProfileType = existing.profileName;
          } else {
            _selectedProfileType = 'custom';
          }

          for (final section in existing.sections) {
            if (section.title == 'Design Options') {
              for (final f in section.fields) {
                if (f.key == 'collar_type') _collarType = f.value;
                if (f.key == 'neck_style') _neckStyle = f.value;
                if (f.key == 'kaf_style') _kafStyle = f.value;
                if (f.key == 'front_style') _frontStyle = f.value;
                if (f.key == 'pocket_type') _pocketType = f.value;
                if (f.key == 'shape') _shape = f.value;
                if (f.key == 'shalwar_style') _shalwarStyle = f.value;
              }
            } else {
              for (final field in section.fields) {
                if (_controllers.containsKey(field.key)) {
                  _controllers[field.key]!.text = field.value;
                }
              }
            }
          }

          if (existing.silaiOptions != null && existing.silaiOptions!.isNotEmpty) {
            _silaiOptions = existing.silaiOptions!.map((o) => Map<String, dynamic>.from(o)).toList();
          }
          _notesCtrl.text = existing.silaiNotes ?? '';
        } else {
          if (widget.profileName != null) {
            _profileNameCtrl.text = widget.profileName!;
            if (_profilePresetTypes.contains(widget.profileName)) {
              _selectedProfileType = widget.profileName!;
            } else {
              _selectedProfileType = 'custom';
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading existing measurement: $e');
      }
    }

    _initialized = true;
    if (mounted) setState(() {});
  }

  void _startNewMeasurement(String customerId) {
    for (final ctrl in _controllers.values) {
      ctrl.clear();
    }
    _notesCtrl.clear();
    _currentMeasurementId = null;
    _profileNameCtrl.text = 'شلوار قمیض';
    _selectedProfileType = 'شلوار قمیض';
    _selectedCategory = MeasurementCategory.men;
    _collarType = 'Standard';
    _neckStyle = 'Round';
    _kafStyle = 'Standard';
    _frontStyle = 'Standard';
    _pocketType = 'Chest';
    _shape = 'Straight';
    _shalwarStyle = 'Straight';
    _silaiOptions = [
      {'label': 'ڈبل سلائی', 'checked': false},
      {'label': 'سنگل سلائی', 'checked': false},
      {'label': 'تریپائی', 'checked': false},
      {'label': 'کپڑا بٹن', 'checked': false},
      {'label': 'پلاسٹک بٹن', 'checked': false},
      {'label': 'امبرائیڈری', 'checked': false},
    ];
    _initialized = true;
    ref.read(selectedMeasurementCustomerIdProvider.notifier).state = customerId;
    if (mounted) setState(() {});
  }

  // ── AUTO-SAVE DRAFT ─────────────────────────────────────────────────────
  void _onFieldChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _saveDraft();
    });
  }

  void _saveDraft() async {
    final customerId = ref.read(selectedMeasurementCustomerIdProvider) ?? widget.customerId;
    if (customerId == null) return;

    final draftData = {
      'category': _selectedCategory.name,
      'profile_name': _profileNameCtrl.text.trim(),
      'values': {
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      },
      'designOptions': {
        'collar_type': _collarType,
        'neck_style': _neckStyle,
        'kaf_style': _kafStyle,
        'front_style': _frontStyle,
        'pocket_type': _pocketType,
        'shape': _shape,
        'shalwar_style': _shalwarStyle,
      },
      'silaiOptions': _silaiOptions,
      'notes': _notesCtrl.text,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final Box draftBox = Hive.box('naap_drafts_box');
      final draftKey = widget.measurementId != null
          ? 'draft_${customerId}_${widget.measurementId}'
          : 'draft_$customerId';
      await draftBox.put(draftKey, draftData);
      await draftBox.put('draft_$customerId', draftData);
    } catch (_) {}
  }

  MeasurementModel _buildCurrentMeasurementModel(String customerId) {
    final fields = k15MeasurementFields.map((f) => MeasurementFieldModel(
      key: f.key,
      label: f.nameEng,
      unit: 'in',
      value: _controllers[f.key]?.text.trim() ?? '',
    )).toList();

    final designFields = [
      MeasurementFieldModel(key: 'collar_type', label: 'Collar Type', unit: '', value: _collarType),
      MeasurementFieldModel(key: 'neck_style', label: 'Neck Style', unit: '', value: _neckStyle),
      MeasurementFieldModel(key: 'kaf_style', label: 'Kaf Style', unit: '', value: _kafStyle),
      MeasurementFieldModel(key: 'front_style', label: 'Front Style', unit: '', value: _frontStyle),
      MeasurementFieldModel(key: 'pocket_type', label: 'Pocket Type', unit: '', value: _pocketType),
      MeasurementFieldModel(key: 'shape', label: 'Shape', unit: '', value: _shape),
      MeasurementFieldModel(key: 'shalwar_style', label: 'Shalwar Style', unit: '', value: _shalwarStyle),
    ];

    final resolvedProfileName = _profileNameCtrl.text.trim().isNotEmpty
        ? _profileNameCtrl.text.trim()
        : (widget.profileName ?? 'شلوار قمیض');

    // 1 customer ke liye 1 profile name (e.g. Shalwar Kameez) ka duplicate na bane
    final allMeasurements = ref.read(measurementsProvider).valueOrNull ?? [];
    final existingSameProfile = allMeasurements.where(
      (m) => m.customerId == customerId &&
             m.profileName.trim().toLowerCase() == resolvedProfileName.trim().toLowerCase(),
    ).firstOrNull;

    final effectiveId = _currentMeasurementId ??
                        widget.measurementId ??
                        existingSameProfile?.id ??
                        const Uuid().v4();

    return MeasurementModel(
      id: effectiveId,
      customerId: customerId,
      title: resolvedProfileName,
      profileName: resolvedProfileName,
      category: _selectedCategory,
      sections: [
        MeasurementSectionModel(title: 'Measurements', fields: fields),
        MeasurementSectionModel(title: 'Design Options', fields: designFields),
      ],
      updatedAt: DateTime.now(),
      silaiOptions: _silaiOptions,
      silaiNotes: _notesCtrl.text.trim(),
    );
  }

  // ── PRINT NAAP CARD ─────────────────────────────────────────────────────
  Future<void> _printNaapCard(String customerId, CustomerModel? customer) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final customerOrders = ref.read(ordersProvider).valueOrNull
          ?.where((o) => o.customerId == customerId)
          .toList() ?? [];
      if (customerOrders.isNotEmpty) {
        customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      }
      final latestOrder = customerOrders.firstOrNull;

      final effectiveOrder = latestOrder ?? OrderModel(
        id: 'naap_${DateTime.now().millisecondsSinceEpoch}',
        customerId: customerId,
        customerName: customer?.name ?? widget.customerName ?? 'Customer',
        tokenNumber: 'NAAP',
        orderNumber: 1,
        orderDate: DateTime.now(),
        status: OrderStatus.pending,
        totalAmount: 0,
        items: const [],
        payments: const [],
      );

      final currentMeasurement = _buildCurrentMeasurementModel(customerId);

      List<int> pdfBytes;
      try {
        final pngBytes = await CardImageCapturer.captureOnDemand(
          context,
          cardWidget: NaapCardWidget(
            order: effectiveOrder,
            customer: customer,
            measurement: currentMeasurement,
          ),
        );
        pdfBytes = await DarziPdfBuilder.buildPdfFromImageBytes(
          pngBytes,
          pageFormat: PdfPageFormat.a5,
        );
      } catch (captureErr) {
        debugPrint('NaapCard captureOnDemand failed, using direct pdf builder: $captureErr');
        pdfBytes = await DarziPdfBuilder.buildTraditionalNaapCard(
          effectiveOrder,
          customer,
          currentMeasurement,
        );
      }

      await Printing.layoutPdf(
        name: 'Naap_${customer?.name ?? "Client"}.pdf',
        onLayout: (_) async => Uint8List.fromList(pdfBytes),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print Error: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFFFF3A58),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // ── SAVE PROFILE TO DATABASE ────────────────────────────────────────────
  Future<void> _saveMeasurements(String customerId, String customerName) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final measurement = _buildCurrentMeasurementModel(customerId);

      // Save measurement (online ya offline dono mein kaam karta hai)
      await ref.read(measurementsProvider.notifier).addOrUpdateMeasurement(measurement);

      // Draft clear karo
      try {
        final Box draftBox = Hive.box('naap_drafts_box');
        final draftKey = widget.measurementId != null
            ? 'draft_${customerId}_${widget.measurementId}'
            : 'draft_$customerId';
        await draftBox.delete(draftKey);
        await draftBox.delete('draft_$customerId');
      } catch (_) {}

      if (!mounted) return;

      // Sab references pop se PEHLE store karo
      final messenger = ScaffoldMessenger.of(context);
      final profileName = measurement.profileName;

      // go_router: pehle canPop check karo
      // agar screen stack mein hai toh pop, warna measurements list par go
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.measurements);
      }

      // Parent screen ke Scaffold par snackbar — safe hai
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Naap save ho gaya! ($profileName)',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10CBA0),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('_saveMeasurements error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Save error: $e',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF3A58),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      // Screen pop ho chuki hoti hai — mounted false hoga, setState nahi chalega
      if (mounted && _isSaving) setState(() => _isSaving = false);
    }
  }


  // ── STEP VALIDATION & NAVIGATION ─────────────────────────────────────────
  void _goToNextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep == 1) {
      final lambaiText = _controllers['lambai']?.text.trim() ?? '';
      if (lambaiText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please enter length (لمبائی) measurement',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      _saveDraft();
      setState(() => _currentStep++);
    }
  }

  void _goToPrevStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      _saveDraft();
      setState(() => _currentStep--);
    } else {
      // go_router: canPop check karo
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.measurements);
      }
    }
  }

  // ── DESIGN PICKER BOTTOM SHEET ──────────────────────────────────────────
  void _openDesignPicker({
    required String title,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    HapticFeedback.lightImpact();
    final isDark = context.isDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF10192B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: isDark ? const Color(0x22FFFFFF) : const Color(0xFFE5E7EB),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF12213A),
                ),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final isSelected = opt == currentValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: isSelected
                        ? (isDark ? const Color(0xFF2A2008) : const Color(0xFFFFFBEB))
                        : (isDark ? const Color(0x0CFFFFFF) : const Color(0xFFF9FAFB)),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onSelected(opt);
                        _onFieldChanged();
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF5A623)
                                : (isDark ? const Color(0x14FFFFFF) : const Color(0xFFE5E7EB)),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              opt,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFFD97706)
                                    : (isDark ? Colors.white : const Color(0xFF374151)),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFFF5A623), size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── BUILD MAIN METHOD ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final customerId = ref.watch(selectedMeasurementCustomerIdProvider) ?? widget.customerId;
    final customersAsync = ref.watch(customersProvider);
    final customerMeasurementsAsync = ref.watch(customerMeasurementsProvider);

    if (customerId != null && !_initialized && customerMeasurementsAsync.hasValue) {
      _loadCustomerData(customerId);
    }

    if (customerId == null) {
      return _buildCustomerSelector(customersAsync);
    }

    final selectedCustomer = customersAsync.valueOrNull?.firstWhere(
      (c) => c.id == customerId,
      orElse: () => CustomerModel(
        id: customerId,
        name: widget.customerName ?? 'Client',
        phone: '',
        address: '',
        gender: CustomerGender.male,
        createdAt: DateTime.now(),
      ),
    );

    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final isDark = context.isDark;
    final bgColor = isDark ? AppColors.bgDark : const Color(0xFFF3F6FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header card matching screenshot + Stepper (progressing in Urdu RTL)
            _buildTopHeader(selectedCustomer, customerId, isDesktop),

            // Step Content in Urdu Direction (RTL)
            Expanded(
              child: isDesktop
                  ? _buildDesktopLayout(selectedCustomer)
                  : _buildMobileLayout(selectedCustomer),
            ),

            // Bottom Navigation Bar
            _buildBottomBar(customerId, selectedCustomer?.name ?? widget.customerName ?? 'Client', isDesktop),
          ],
        ),
      ),
    );
  }

  // ── HEADER MATCHING USER SCREENSHOT + ACTION BUTTONS ────────────────────
  Widget _buildTopHeader(CustomerModel? customer, String customerId, bool isDesktop) {
    final isDark = context.isDark;
    final customerName = customer?.name ?? widget.customerName ?? 'Client';
    final customerPhone = customer?.phone ?? '';
    final customerIdDisplay = customer != null
        ? (customer.id.length <= 6 ? customer.id : customer.id.substring(0, 5).toUpperCase())
        : '1045';

    final customerOrders = ref.watch(ordersProvider).valueOrNull
        ?.where((o) => o.customerId == customerId)
        .toList() ?? [];
    final orderCount = customerOrders.isNotEmpty ? customerOrders.length : (customer?.totalOrders ?? 0);
    final joinedDateStr = customer != null
        ? DateFormat('dd MMM yyyy').format(customer.createdAt)
        : DateFormat('dd MMM yyyy').format(DateTime.now());

    return Container(
      margin: EdgeInsets.fromLTRB(16, isDesktop ? 16 : 40, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: context.cardShadow,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row: Back Button + Avatar + Customer Measurements Title + Details Pill + Actions
            Row(
              children: [
                // Back Button
                Material(
                  color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _goToPrevStep,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Avatar Icon (matching user screenshot)
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF162744) : const Color(0xFFF0F7FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0x333B82F6) : const Color(0xFFDBEAFE)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      size: 26,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Title and Urdu Subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Customer Measurements',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'کسٹمر کے ناپ درج کریں',
                      style: GoogleFonts.notoNastaliqUrdu(
                        fontSize: 11.5,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),

                if (isDesktop) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF132238) : const Color(0xFFF1F7FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0x223B82F6) : const Color(0xFFE0EDF8),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Customer ID
                              _buildHeaderInfoItem(
                                icon: Icons.person_outline_rounded,
                                label: 'Customer ID',
                                value: '#$customerIdDisplay',
                              ),
                              _buildHeaderDivider(),
                              // 2. Customer Name (Large Bold) + Mobile Subtitle
                              _buildHeaderInfoItem(
                                icon: Icons.person_outline_rounded,
                                label: 'Customer Name',
                                value: customerName,
                                subtitle: customerPhone.isNotEmpty ? customerPhone : '0300-0000000',
                                isName: true,
                              ),
                              _buildHeaderDivider(),
                              // 3. Customer Joined Date (New Customer / Since)
                              _buildHeaderInfoItem(
                                icon: Icons.calendar_today_outlined,
                                label: 'Joined Date',
                                value: joinedDateStr,
                              ),
                              _buildHeaderDivider(),
                              // 4. Total Orders Count
                              _buildHeaderInfoItem(
                                icon: Icons.shopping_bag_outlined,
                                label: 'Total Orders',
                                value: '$orderCount Orders',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  const Spacer(),
                ],

                // Print Button
                OutlinedButton.icon(
                  onPressed: _isPrinting ? null : () => _printNaapCard(customerId, customer),
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_rounded, size: 16),
                  label: Text(
                    'Print',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0x14FFFFFF) : const Color(0xFFF8FAFC),
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    side: BorderSide(color: isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

                const SizedBox(width: 8),

                // Save Button
                InkWell(
                  onTap: _isSaving ? null : () => _saveMeasurements(customerId, customerName),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF5C842), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF5A623).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSaving)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF12213A)),
                          )
                        else
                          const Icon(Icons.check_rounded, size: 16, color: Color(0xFF12213A)),
                        const SizedBox(width: 6),
                        Text(
                          'Save',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF12213A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Mobile Customer Info Strip (When width < 720px)
            if (!isDesktop) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF132238) : const Color(0xFFF1F7FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0x223B82F6) : const Color(0xFFE0EDF8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$customerIdDisplay • $customerName',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (customerPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            customerPhone,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$orderCount Orders',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Since $joinedDateStr',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Stepper: Progressing in Urdu RTL Direction
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 480 : double.infinity),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    children: [
                      _buildStepItem(0, 'Setup', 'سیٹ اپ'),
                      _buildStepLine(0),
                      _buildStepItem(1, 'Naap', 'سائز'),
                      _buildStepLine(1),
                      _buildStepItem(2, 'Silai', 'ڈیزائن'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfoItem({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    bool isName = false,
  }) {
    final isDark = context.isDark;
    final isUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(value);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: isUrdu
                  ? GoogleFonts.notoNastaliqUrdu(
                      fontSize: isName ? 14.5 : 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    )
                  : GoogleFonts.outfit(
                      fontSize: isName ? 15 : 12.5,
                      fontWeight: isName ? FontWeight.w800 : FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(
                subtitle,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderDivider() {
    final isDark = context.isDark;
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: isDark ? const Color(0x223B82F6) : const Color(0xFFD6E4F0),
    );
  }

  Widget _buildStepItem(int stepIndex, String titleEng, String titleUrdu) {
    final isDone = _currentStep > stepIndex;
    final isActive = _currentStep == stepIndex;

    Color circleBg;
    Color circleTextColor;
    List<BoxShadow>? glow;

    if (isDone) {
      circleBg = const Color(0xFFF5A623);
      circleTextColor = const Color(0xFF12213A);
    } else if (isActive) {
      circleBg = Colors.white;
      circleTextColor = const Color(0xFF12213A);
      glow = [
        BoxShadow(
          color: const Color(0xFFF5A623).withValues(alpha: 0.5),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    } else {
      circleBg = Colors.grey.withValues(alpha: 0.2);
      circleTextColor = Colors.grey;
    }

    final labelColor = isActive
        ? const Color(0xFFF5A623)
        : (isDone ? (context.isDark ? Colors.white : const Color(0xFF1E293B)) : Colors.grey);

    return InkWell(
      onTap: () {
        if (stepIndex < _currentStep) {
          HapticFeedback.lightImpact();
          setState(() => _currentStep = stepIndex);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? const Color(0xFFF5A623) : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: glow,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 15, color: Color(0xFF12213A))
                    : Text(
                        '${stepIndex + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: circleTextColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$titleEng / $titleUrdu',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLine(int leftStepIndex) {
    final isDone = _currentStep > leftStepIndex;
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFF5A623) : (context.isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  // ── MOBILE LAYOUT (<720PX) (URDU RTL DIRECTION) ─────────────────────────
  Widget _buildMobileLayout(CustomerModel? customer) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_currentStep == 0) _buildStep1SetupMobile(),
            if (_currentStep == 1) _buildStep2NaapMobile(),
            if (_currentStep == 2) _buildStep3SilaiMobile(),
          ],
        ),
      ),
    );
  }

  // ── DESKTOP LAYOUT (≥720PX) (URDU RTL DIRECTION) ────────────────────────
  Widget _buildDesktopLayout(CustomerModel? customer) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_currentStep == 0) _buildStep1SetupDesktop(),
                if (_currentStep == 1) _buildStep2NaapDesktop(),
                if (_currentStep == 2) _buildStep3SilaiDesktop(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── STEP 1: SETUP (MOBILE) ──────────────────────────────────────────────
  Widget _buildStep1SetupMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGenderCategoryCard(),
        const SizedBox(height: 12),
        _buildProfileTypeGridCard(),
        const SizedBox(height: 12),
        _buildCustomNameCard(),
      ],
    );
  }

  // ── STEP 1: SETUP (DESKTOP - RTL) ───────────────────────────────────────
  Widget _buildStep1SetupDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Right Column in RTL: Category Selector + Profile Grid
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGenderCategoryCard(),
              const SizedBox(height: 12),
              _buildProfileTypeGridCard(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Left Column in RTL: Custom Name + Summary Preview
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCustomNameCard(),
              const SizedBox(height: 12),
              _buildDesktopProfilePreviewCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderCategoryCard() {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
        ),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'صنف منتخب کریں (Gender Category)',
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Select Gender',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildGenderOption(
                icon: '👔',
                urduLabel: 'مرد',
                engLabel: 'Men',
                category: MeasurementCategory.men,
              ),
              const SizedBox(width: 10),
              _buildGenderOption(
                icon: '👗',
                urduLabel: 'عورت',
                engLabel: 'Women',
                category: MeasurementCategory.women,
              ),
              const SizedBox(width: 10),
              _buildGenderOption(
                icon: '🧒',
                urduLabel: 'بچے',
                engLabel: 'Kids',
                category: MeasurementCategory.children,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption({
    required String icon,
    required String urduLabel,
    required String engLabel,
    required MeasurementCategory category,
  }) {
    final isDark = context.isDark;
    final isSelected = _selectedCategory == category;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedCategory = category;
          });
          _onFieldChanged();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2A2008) : const Color(0xFFFFFBEB))
                : (isDark ? const Color(0x0CFFFFFF) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF5A623)
                  : (isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFF5A623).withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                urduLabel,
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFFD97706)
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
              ),
              Text(
                engLabel,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFFD97706)
                      : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTypeGridCard() {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
        ),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'لباس کی قسم (Profile Type)',
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Select Dress',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.8,
            children: [
              ..._profilePresetTypes.map((type) => _buildProfileTypeItem(type)),
              _buildCustomProfileTypeItem(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTypeItem(String typeName) {
    final isDark = context.isDark;
    final isSelected = _selectedProfileType == typeName;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedProfileType = typeName;
          _profileNameCtrl.text = typeName;
        });
        _onFieldChanged();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E2E4A) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0x0CFFFFFF) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Text(
          typeName,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoNastaliqUrdu(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A))
                : (isDark ? Colors.white : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomProfileTypeItem() {
    final isDark = context.isDark;
    final isSelected = _selectedProfileType == 'custom';

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedProfileType = 'custom';
        });
        _profileNameFocusNode.requestFocus();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2A2008) : const Color(0xFFFFFBEB))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF5A623)
                : (isDark ? Colors.white24 : const Color(0xFF94A3B8)),
            width: isSelected ? 2 : 1.2,
          ),
        ),
        child: Text(
          '+ اپنا نام (Custom)',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFFD97706)
                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomNameCard() {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
        ),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'پروفائل کا عنوان (Profile Name)',
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Custom Name',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _profileNameCtrl,
            focusNode: _profileNameFocusNode,
            textDirection: TextDirection.rtl,
            onChanged: (val) {
              if (!_profilePresetTypes.contains(val)) {
                if (_selectedProfileType != 'custom') {
                  setState(() => _selectedProfileType = 'custom');
                }
              }
              _onFieldChanged();
            },
            style: GoogleFonts.notoNastaliqUrdu(
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF12213A),
            ),
            decoration: InputDecoration(
              hintText: 'پروفائل کا نام درج کریں...',
              hintStyle: GoogleFonts.notoNastaliqUrdu(
                fontSize: 12,
                color: isDark ? Colors.white30 : Colors.grey[400],
              ),
              hintTextDirection: TextDirection.rtl,
              filled: true,
              fillColor: isDark ? const Color(0x0CFFFFFF) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFF5A623),
                  width: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopProfilePreviewCard() {
    final isDark = context.isDark;
    final name = _profileNameCtrl.text.trim().isNotEmpty
        ? _profileNameCtrl.text.trim()
        : 'شلوار قمیض';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121B2F) : const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF5C842).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5C842), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Center(
                  child: Icon(Icons.straighten_rounded, color: Color(0xFF12213A), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پروفائل پیش نظارہ',
                      style: GoogleFonts.notoNastaliqUrdu(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    Text(
                      'Profile Summary',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: GoogleFonts.notoNastaliqUrdu(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF12213A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'یہ نام اس گاہک کے ناپ ریکارڈ اور آرڈر بکنگ میں منتخب کرنے کے لیے دستیاب ہوگا۔ آگے بڑھنے کے لیے "Next" پر کلک کریں۔',
            style: GoogleFonts.notoNastaliqUrdu(
              fontSize: 11,
              height: 1.7,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 2: NAAP (MOBILE - RTL) ─────────────────────────────────────────
  Widget _buildStep2NaapMobile() {
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
        ),
        boxShadow: context.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: k15MeasurementFields.asMap().entries.map((entry) {
          final idx = entry.key;
          final field = entry.value;
          final isLast = idx == k15MeasurementFields.length - 1;
          return _buildMeasurementRow(field, isLast: isLast, iconSize: 38, inputWidth: 68);
        }).toList(),
      ),
    );
  }

  // ── STEP 2: NAAP (DESKTOP - RTL) ────────────────────────────────────────
  Widget _buildStep2NaapDesktop() {
    final isDark = context.isDark;
    // In Urdu reading order:
    // Right Column: First 8 fields (لمبائی, تیرو, بازو, چھاتی, بغل, کمر, دامن, کالر)
    // Left Column: Remaining 7 fields (شلوار, پانچے, کف, جیب, گول, آسن, گریبان)
    final rightColumnFields = k15MeasurementFields.sublist(0, 8);
    final leftColumnFields = k15MeasurementFields.sublist(8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Right Column in RTL: First 8 fields
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
              ),
              boxShadow: context.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: rightColumnFields.asMap().entries.map((entry) {
                final idx = entry.key;
                final field = entry.value;
                final isLast = idx == rightColumnFields.length - 1;
                return _buildMeasurementRow(field, isLast: isLast, iconSize: 42, inputWidth: 76);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Left Column in RTL: Next 7 fields
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
              ),
              boxShadow: context.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: leftColumnFields.asMap().entries.map((entry) {
                final idx = entry.key;
                final field = entry.value;
                final isLast = idx == leftColumnFields.length - 1;
                return _buildMeasurementRow(field, isLast: isLast, iconSize: 42, inputWidth: 76);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── MEASUREMENT ROW IN URDU DIRECTION (SHAPE & URDU NAME RIGHT, INPUT LEFT) ─
  Widget _buildMeasurementRow(
    MeasurementFieldConfig field, {
    required bool isLast,
    required double iconSize,
    required double inputWidth,
  }) {
    final isDark = context.isDark;
    final ctrl = _controllers[field.key]!;
    final focus = _focusNodes[field.key]!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0x0CFFFFFF) : const Color(0xFFF1F5F9),
                  width: 1.0,
                ),
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // 1. FIRST IN RTL = FAR RIGHT: Shape Icon Container
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF261D07) : const Color(0xFFFFF9EE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0x44F5A623) : const Color(0xFFFDE68A),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: CustomPaint(
              painter: MeasurementShapePainter(
                keyName: field.key,
                color: const Color(0xFFD97706),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 2. SECOND IN RTL = NEXT TO SHAPE: Urdu & English Labels
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                field.nameUrdu,
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                field.nameEng,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const Spacer(),

          // 3. THIRD IN RTL = FAR LEFT: Numeric Input Box + Unit Label
          SizedBox(
            width: inputWidth,
            height: 40,
            child: TextField(
              controller: ctrl,
              focusNode: focus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              onChanged: (_) => _onFieldChanged(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF12213A),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0x14FFFFFF) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0x1EFFFFFF) : const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0x1EFFFFFF) : const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: Color(0xFFF5A623),
                    width: 2.0,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          Text(
            '"',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: SILAI & DESIGN (MOBILE) ─────────────────────────────────────
  Widget _buildStep3SilaiMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSilaiChecklistCard(),
        const SizedBox(height: 12),
        _buildDesignOptionsCard(),
        const SizedBox(height: 12),
        _buildSpecialInstructionsCard(),
      ],
    );
  }

  // ── STEP 3: SILAI & DESIGN (DESKTOP - RTL) ──────────────────────────────
  Widget _buildStep3SilaiDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Right side in RTL: Silai Checklist
        Expanded(
          flex: 6,
          child: _buildSilaiChecklistCard(),
        ),
        const SizedBox(width: 16),
        // Left side in RTL: Design Options + Notes
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDesignOptionsCard(),
              const SizedBox(height: 12),
              _buildSpecialInstructionsCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSilaiChecklistCard() {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
        ),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سلائی کی تفصیل (Stitching Options)',
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Select Stitching',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: _silaiOptions.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, idx) {
              final opt = _silaiOptions[idx];
              final label = opt['label'] as String;
              final isChecked = opt['checked'] as bool;

              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _silaiOptions[idx] = {'label': label, 'checked': !isChecked};
                  });
                  _onFieldChanged();
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? (isDark ? const Color(0xFF2A2008) : const Color(0xFFFFFBEB))
                        : (isDark ? const Color(0x0CFFFFFF) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChecked
                          ? const Color(0xFFF5A623)
                          : (isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0)),
                      width: isChecked ? 1.8 : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isChecked ? const Color(0xFFF5A623) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isChecked
                                ? const Color(0xFFF5A623)
                                : (isDark ? Colors.white38 : const Color(0xFFCBD5E1)),
                            width: 1.6,
                          ),
                        ),
                        child: isChecked
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.notoNastaliqUrdu(
                            fontSize: 11,
                            fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                            color: isChecked
                                ? const Color(0xFFD97706)
                                : (isDark ? Colors.white : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesignOptionsCard() {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
        ),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ڈیزائن کے اختیارات (Design Options)',
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Custom Design',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildDesignRow(
                  title: 'Collar Type',
                  urduTitle: 'کالر کی قسم',
                  currentValue: _collarType,
                  options: ['Standard', 'Mandarin', 'Peshawari', 'Spread'],
                  onSelected: (val) => setState(() => _collarType = val),
                ),
                _buildDesignRow(
                  title: 'Neck Style',
                  urduTitle: 'گلے کا سٹائل',
                  currentValue: _neckStyle,
                  options: ['Round', 'Open', 'Closed'],
                  onSelected: (val) => setState(() => _neckStyle = val),
                ),
                _buildDesignRow(
                  title: 'Kaf Style',
                  urduTitle: 'کف کا سٹائل',
                  currentValue: _kafStyle,
                  options: ['Standard', 'Embroidery', 'Button', 'Double'],
                  onSelected: (val) => setState(() => _kafStyle = val),
                ),
                _buildDesignRow(
                  title: 'Front Style',
                  urduTitle: 'سامنے کا سٹائل',
                  currentValue: _frontStyle,
                  options: ['Standard', 'Embroidery', 'Covered', 'None'],
                  onSelected: (val) => setState(() => _frontStyle = val),
                ),
                _buildDesignRow(
                  title: 'Pocket Type',
                  urduTitle: 'جیب کی قسم',
                  currentValue: _pocketType,
                  options: ['Chest', 'Side', 'None'],
                  onSelected: (val) => setState(() => _pocketType = val),
                ),
                _buildDesignRow(
                  title: 'Shape',
                  urduTitle: 'شکل / فٹنگ',
                  currentValue: _shape,
                  options: ['Straight', 'Fitting', 'Loose'],
                  onSelected: (val) => setState(() => _shape = val),
                ),
                _buildDesignRow(
                  title: 'Shalwar Style',
                  urduTitle: 'شلوار کا سٹائل',
                  currentValue: _shalwarStyle,
                  options: ['Straight', 'Churidar', 'Patiala', 'Peshawari'],
                  onSelected: (val) => setState(() => _shalwarStyle = val),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignRow({
    required String title,
    required String urduTitle,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String> onSelected,
    bool isLast = false,
  }) {
    final isDark = context.isDark;

    return InkWell(
      onTap: () => _openDesignPicker(
        title: '$urduTitle ($title)',
        currentValue: currentValue,
        options: options,
        onSelected: onSelected,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0x0CFFFFFF) : const Color(0xFFF1F5F9),
                  ),
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              urduTitle,
              style: GoogleFonts.notoNastaliqUrdu(
                fontSize: 11.5,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ),
            Row(
              children: [
                Text(
                  currentValue,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF5A623),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Color(0xFFF5A623), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialInstructionsCard() {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0),
        ),
        boxShadow: context.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'خاص ہدایات (Special Instructions)',
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Notes',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            textDirection: TextDirection.rtl,
            onChanged: (_) => _onFieldChanged(),
            style: GoogleFonts.notoNastaliqUrdu(
              fontSize: 12.5,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: 'کوئی خاص ہدایت لکھیں... (مثلاً: بازو باریک رکھنا ہے)',
              hintStyle: GoogleFonts.notoNastaliqUrdu(
                fontSize: 11,
                color: isDark ? Colors.white30 : Colors.grey[400],
              ),
              hintTextDirection: TextDirection.rtl,
              filled: true,
              fillColor: isDark ? const Color(0x0CFFFFFF) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFF5A623),
                  width: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM NAVIGATION BAR ───────────────────────────────────────────────
  Widget _buildBottomBar(String customerId, String customerName, bool isDesktop) {
    final isDark = context.isDark;

    Widget content;
    if (_currentStep == 0) {
      content = SizedBox(
        width: double.infinity,
        height: 48,
        child: InkWell(
          onTap: _goToNextStep,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF12213A), Color(0xFF1E3A5F)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF12213A).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Next',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_currentStep == 1) {
      // In Urdu reading order (RTL):
      // Forward / Next is on the LEFT (with arrow pointing Left <- towards Step 2)
      // Back is on the RIGHT (with arrow pointing Right -> towards Step 0)
      content = Row(
        children: [
          // Next button on the LEFT (flex: 2)
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: InkWell(
                onTap: _goToNextStep,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF12213A), Color(0xFF1E3A5F)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF12213A).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Next',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Back button on the RIGHT (flex: 1)
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _goToPrevStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                  side: BorderSide(
                    color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Back',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Step 2:
      // Save Profile is on the LEFT (flex: 2)
      // Back is on the RIGHT (flex: 1)
      content = Row(
        children: [
          // Save Profile button on the LEFT
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: InkWell(
                onTap: _isSaving ? null : () => _saveMeasurements(customerId, customerName),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF5C842), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF5A623).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF12213A),
                          ),
                        )
                      else ...[
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF12213A), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Save Profile',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF12213A),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Back button on the RIGHT
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _goToPrevStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                  side: BorderSide(
                    color: isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Back',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A2E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
          child: content,
        ),
      ),
    );
  }

  // ── CUSTOMER SELECTOR FALLBACK ──────────────────────────────────────────
  Widget _buildCustomerSelector(AsyncValue<List<CustomerModel>> customersAsync) {
    final isDark = context.isDark;
    final bg = isDark ? AppColors.bgDark : Colors.white;
    final text1 = isDark ? Colors.white : const Color(0xFF0A0F1C);
    final text2 = isDark ? Colors.white54 : const Color(0xFF4A5568);
    final allMeasurements = ref.watch(measurementsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: bg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Profile',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: text1),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a client to add or edit their measurement profile',
              style: GoogleFonts.inter(fontSize: 12, color: text2),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.inter(color: text1),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: isDark ? const Color(0x14FFFFFF) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (customers) {
                  final filtered = customers.where((c) {
                    return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        c.phone.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: ElevatedButton.icon(
                        onPressed: () => AddCustomerModal.show(context),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add New Customer'),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final c = filtered[idx];
                      final rawMeasurements = allMeasurements.where((m) => m.customerId == c.id).toList();

                      // Deduplicate by profileName (keeping the latest one for each profile)
                      final Map<String, MeasurementModel> uniqueMap = {};
                      for (final m in rawMeasurements) {
                        final key = m.profileName.trim().toLowerCase();
                        if (!uniqueMap.containsKey(key) || m.updatedAt.isAfter(uniqueMap[key]!.updatedAt)) {
                          uniqueMap[key] = m;
                        }
                      }
                      final cMeasurements = uniqueMap.values.toList();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (cMeasurements.isNotEmpty) {
                              _showNaapDetailModal(context, c, cMeasurements.first);
                            } else {
                              _startNewMeasurement(c.id);
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer Header Row
                              Row(
                                children: [
                                  CustomerAvatar(name: c.name, size: 42, borderRadius: 10),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                c.name,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: text1,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: cMeasurements.isNotEmpty
                                                    ? (isDark ? const Color(0x1F10CBA0) : const Color(0xFFE6FFFA))
                                                    : (isDark ? const Color(0x1A94A3B8) : const Color(0xFFF1F5F9)),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                cMeasurements.isNotEmpty
                                                    ? '${cMeasurements.length} Naap'
                                                    : 'No Naap',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: cMeasurements.isNotEmpty
                                                      ? const Color(0xFF0D9488)
                                                      : text2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          c.phone,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 12,
                                            color: text2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(c.gender.emoji, style: const TextStyle(fontSize: 18)),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Quick Action Buttons (Naap Profiles & + Naya Naap)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ...cMeasurements.map((m) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          _showNaapDetailModal(context, c, m);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0x1F10CBA0) : const Color(0xFFECFDF5),
                                            border: Border.all(
                                              color: isDark ? const Color(0x4D10CBA0) : const Color(0x8010CBA0),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.straighten_rounded, size: 13, color: Color(0xFF0D9488)),
                                              const SizedBox(width: 5),
                                              Text(
                                                m.profileName.isNotEmpty ? m.profileName : 'ناپ',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Icon(
                                                Icons.visibility_rounded,
                                                size: 12,
                                                color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                  // + Naya Naap / Add Button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _startNewMeasurement(c.id);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0x1AF5A623) : const Color(0xFFFFFBEB),
                                          border: Border.all(
                                            color: isDark ? const Color(0x4DF5A623) : const Color(0x99F5A623),
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add_rounded, size: 14, color: Color(0xFFD97706)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '+ نیا ناپ',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFFF5A623) : const Color(0xFFB45309),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── NAAP QUICK VIEW MODAL (WITH PRINT & EDIT BUTTONS) ───────────────────
  void _showNaapDetailModal(BuildContext context, CustomerModel customer, MeasurementModel measurement) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final text1 = isDark ? Colors.white : const Color(0xFF0F172A);
    final text2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Extract non-empty measurement fields
    final fieldsList = <Map<String, String>>[];
    for (final section in measurement.sections) {
      if (section.title != 'Design Options') {
        for (final field in section.fields) {
          if (field.value.trim().isNotEmpty) {
            final config = k15MeasurementFields.where((f) => f.key == field.key).firstOrNull;
            fieldsList.add({
              'key': field.key,
              'urdu': config?.nameUrdu ?? field.label,
              'eng': config?.nameEng ?? field.key,
              'value': field.value.trim(),
            });
          }
        }
      }
    }

    // Extract design options
    final designOptions = <Map<String, String>>[];
    for (final section in measurement.sections) {
      if (section.title == 'Design Options') {
        for (final f in section.fields) {
          if (f.value.trim().isNotEmpty && f.value != 'None' && f.value != 'Standard') {
            designOptions.add({
              'label': f.label,
              'value': f.value,
            });
          }
        }
      }
    }

    // Silai options
    final activeSilaiOpts = (measurement.silaiOptions ?? [])
        .where((opt) => opt['checked'] == true)
        .map((opt) => opt['label'] as String? ?? '')
        .where((l) => l.isNotEmpty)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: bg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10CBA0).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10CBA0).withValues(alpha: 0.3)),
                        ),
                        child: const Center(
                          child: Icon(Icons.straighten_rounded, color: Color(0xFF10CBA0), size: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customer.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: text1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5A623).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    measurement.profileName,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${customer.phone} · ${measurement.category.label}',
                              style: GoogleFonts.inter(fontSize: 12, color: text2),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('پروفائل ڈیلیٹ کریں؟'),
                              content: Text('${customer.name} کا "${measurement.profileName}" ناپ ڈیلیٹ ہو جائے گا۔'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('منسوخ (Cancel)')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3A58)),
                                  onPressed: () => Navigator.of(dCtx).pop(true),
                                  child: const Text('ڈیلیٹ کریں (Delete)', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && ctx.mounted) {
                            Navigator.of(ctx).pop();
                            await ref.read(measurementsProvider.notifier).deleteMeasurement(measurement.id);
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3A58), size: 20),
                        tooltip: 'Delete Profile',
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close_rounded, color: text2),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // Content (Scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Measurement values grid
                        Text(
                          'پیمائش کی تفصیلات (Measurements)',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (fieldsList.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ابھی کوئی پیمائش درج نہیں ہے / No measurement values recorded',
                              style: GoogleFonts.inter(fontSize: 12, color: text2),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: fieldsList.map((f) {
                              return Container(
                                width: 120,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f['urdu']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: text2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      f['eng']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: text2.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${f['value']!}"',
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                        // Design Options
                        if (designOptions.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            'ڈیزائن کی ترتیبات (Design Options)',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: text1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: designOptions.map((opt) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${opt['label']}: ',
                                      style: GoogleFonts.inter(fontSize: 11, color: text2),
                                    ),
                                    Text(
                                      opt['value']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: text1,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        // Silai options
                        if (activeSilaiOpts.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            'سلائی کی تفصیل (Stitching Details)',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: text1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: activeSilaiOpts.map((s) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10CBA0).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10CBA0).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10CBA0)),
                                    const SizedBox(width: 5),
                                    Text(
                                      s,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        // Notes
                        if (measurement.silaiNotes != null && measurement.silaiNotes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            'خصوصی ہدایات (Notes)',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: text1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              measurement.silaiNotes!,
                              style: GoogleFonts.inter(fontSize: 12, color: text1, height: 1.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer Action Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      // 1. Print Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _printSpecificMeasurement(customer, measurement);
                          },
                          icon: const Icon(Icons.print_rounded, size: 17),
                          label: Text(
                            'پرنٹ کارڈ (Print)',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10CBA0),
                            side: const BorderSide(color: Color(0xFF10CBA0)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 2. Edit/Update Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            HapticFeedback.lightImpact();
                            _loadCustomerData(customer.id, measurement);
                            ref.read(selectedMeasurementCustomerIdProvider.notifier).state = customer.id;
                          },
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: Text(
                            'اپڈیٹ کریں (Edit / Update)',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5A623),
                            foregroundColor: const Color(0xFF1A0A00),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
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
    );
  }

  // ── PRINT SPECIFIC MEASUREMENT NAAP CARD ────────────────────────────────
  Future<void> _printSpecificMeasurement(CustomerModel customer, MeasurementModel measurement) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final customerOrders = ref.read(ordersProvider).valueOrNull
          ?.where((o) => o.customerId == customer.id)
          .toList() ?? [];
      if (customerOrders.isNotEmpty) {
        customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      }
      final latestOrder = customerOrders.firstOrNull;

      final effectiveOrder = latestOrder ?? OrderModel(
        id: 'naap_${DateTime.now().millisecondsSinceEpoch}',
        customerId: customer.id,
        customerName: customer.name,
        tokenNumber: 'NAAP',
        orderNumber: 1,
        orderDate: DateTime.now(),
        status: OrderStatus.pending,
        totalAmount: 0,
        items: const [],
        payments: const [],
      );

      List<int> pdfBytes;
      try {
        final pngBytes = await CardImageCapturer.captureOnDemand(
          context,
          cardWidget: NaapCardWidget(
            order: effectiveOrder,
            customer: customer,
            measurement: measurement,
          ),
        );
        pdfBytes = await DarziPdfBuilder.buildPdfFromImageBytes(
          pngBytes,
          pageFormat: PdfPageFormat.a5,
        );
      } catch (captureErr) {
        debugPrint('NaapCard captureOnDemand failed, using direct pdf builder: $captureErr');
        pdfBytes = await DarziPdfBuilder.buildTraditionalNaapCard(
          effectiveOrder,
          customer,
          measurement,
        );
      }

      await Printing.layoutPdf(
        name: 'Naap_${customer.name}_${measurement.profileName}.pdf',
        onLayout: (_) async => Uint8List.fromList(pdfBytes),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print Error: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFFFF3A58),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }
}
