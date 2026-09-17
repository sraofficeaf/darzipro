import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import 'package:pdf/pdf.dart';
import '../../core/constants/app_enums.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';
import '../customers/add_customer_modal.dart';
import '../printing/pdf_builder.dart';
import '../printing/widgets/card_image_capturer.dart';
import '../printing/widgets/naap_card_widget.dart';

export 'measurement_field_config.dart';
import 'measurement_field_config.dart';

// ── COLOR PALETTE & DESIGN SYSTEM (MATCHING HTML DESIGN) ───────────────────────
abstract class _NaapColors {
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF7B8494);
  static const faint = Color(0xFFAAB2BF);
  static const line = Color(0xFFE8EAF0);
  static const paper = Color(0xFFF5F6F8);
  static const dark = Color(0xFF151922);
  static const darkCard = Color(0xFF181D27);
  static const darkSurface = Color(0xFF1D222D);
  static const darkLine = Color(0xFF333946);

  static const gold = Color(0xFFE9A227);
  static const gold2 = Color(0xFFFFC65A);
  static const goldBg = Color(0xFFFFF6E5);
  static const goldLine = Color(0xFFF3DDA8);

  static const green = Color(0xFF18B887);
  static const greenBg = Color(0xFFEAFBF5);
  static const greenLine = Color(0xFFCFEFE3);

  static const rose = Color(0xFFEF5261);

  static const blue = Color(0xFF5478E8);
  static const blueBg = Color(0xFFEEF2FF);
}

// ── STATIC TYPOGRAPHY FOR ZERO GC CHURN ───────────────────────────────────────
abstract class _NaapStyles {
  static final heroTitle = GoogleFonts.manrope(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.5,
  );
  static final heroSubtitle = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: const Color(0xFFAEB5C2),
  );
  static final sectionTitle = GoogleFonts.manrope(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
  );
  static final sectionSubtitle = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: _NaapColors.muted,
  );
  static final cardTag = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.1,
    color: _NaapColors.faint,
  );
  static final monoMetric = GoogleFonts.ibmPlexMono(
    fontSize: 23,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
  );
}

// ── MAIN MEASUREMENTS SCREEN (3-STEP FLOW MATCHING HTML DESIGN) ───────────────
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
  // Step indicator: 0: Setup, 1: Naap, 2: Silai & Design
  int _currentStep = 0;

  // Controllers & Focus Nodes (retained across steps)
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final TextEditingController _profileNameCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // High-performance state notifiers (avoids rebuilding entire screen on typing)
  final ValueNotifier<int> _filledCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> _profileNameNotifier = ValueNotifier<String>('شلوار قمیض');

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
    final initialName = widget.profileName ?? 'شلوار قمیض';
    _profileNameCtrl.text = initialName;
    _profileNameNotifier.value = initialName;

    if (widget.profileName != null && !_profilePresetTypes.contains(widget.profileName)) {
      _selectedProfileType = 'custom';
    } else if (widget.profileName != null) {
      _selectedProfileType = widget.profileName!;
    }

    if (widget.category != null) {
      _selectedCategory = widget.category!;
    }

    _profileNameCtrl.addListener(() {
      final name = _profileNameCtrl.text.trim();
      _profileNameNotifier.value = name.isNotEmpty ? name : 'شلوار قمیض';
    });

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
      final ctrl = TextEditingController();
      _controllers[field.key] = ctrl;
      _focusNodes[field.key] = FocusNode();
    }
  }

  void _recalcFilledCount() {
    int count = 0;
    for (final c in _controllers.values) {
      if (c.text.trim().isNotEmpty) count++;
    }
    _filledCountNotifier.value = count;
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
    _filledCountNotifier.dispose();
    _profileNameNotifier.dispose();
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
      _profileNameNotifier.value = specificMeasurement.profileName;
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
      _recalcFilledCount();
      _initialized = true;
      if (mounted) setState(() {});
      return;
    }

    // Load from Hive Draft
    final Box draftBox = Hive.box('naap_drafts_box');
    dynamic draft;
    try {
      final draftKey = widget.measurementId != null
          ? 'draft_${customerId}_${widget.measurementId}'
          : 'draft_$customerId';
      draft = draftBox.get(draftKey) ?? draftBox.get('draft_$customerId');
    } catch (e) {
      debugPrint('Error reading draft: $e');
    }

    if (draft is Map) {
      try {
        final data = Map<String, dynamic>.from(draft);
        _selectedCategory = MeasurementCategory.values.firstWhere(
          (c) => c.name == data['category'],
          orElse: () => widget.category ?? MeasurementCategory.men,
        );

        if (data['profile_name'] != null) {
          _profileNameCtrl.text = data['profile_name'] as String;
          _profileNameNotifier.value = _profileNameCtrl.text;
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
      } catch (e) {
        debugPrint('Error parsing draft: $e');
      }
    } else {
      // Pre-fill from existing measurement if available
      try {
        final allMeasurements = ref.read(measurementsProvider).valueOrNull ?? [];
        final existing = widget.measurementId != null
            ? allMeasurements.where((m) => m.id == widget.measurementId).firstOrNull
            : allMeasurements.where((m) => m.customerId == customerId).firstOrNull;

        if (existing != null) {
          _currentMeasurementId = existing.id;
          _selectedCategory = existing.category;
          _profileNameCtrl.text = existing.profileName;
          _profileNameNotifier.value = existing.profileName;
          if (_profilePresetTypes.contains(existing.profileName)) {
            _selectedProfileType = existing.profileName;
          } else {
            _selectedProfileType = 'custom';
          }

          for (final section in existing.sections) {
            if (section.title != 'Design Options') {
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
        }
      } catch (_) {}
    }

    _recalcFilledCount();
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
    _profileNameNotifier.value = 'شلوار قمیض';
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
      {'label': 'ڈبل سلائی', 'checked': true},
      {'label': 'زنجیری سلائی', 'checked': false},
      {'label': 'سٹیل بٹن', 'checked': true},
      {'label': 'کف پلیٹ نہیں', 'checked': false},
      {'label': 'چاک پٹی کاج', 'checked': false},
      {'label': 'کپڑا بٹن', 'checked': false},
      {'label': 'پلاسٹک بٹن', 'checked': false},
      {'label': 'امبرائیڈری', 'checked': false},
    ];
    _recalcFilledCount();
    _initialized = true;
    ref.read(selectedMeasurementCustomerIdProvider.notifier).state = customerId;
    if (mounted) setState(() {});
  }

  // ── AUTO-SAVE DRAFT (DEBOUNCED TO PREVENT CPU LAG) ──────────────────────────
  void _onFieldChanged() {
    _recalcFilledCount();
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

  // ── SAVE PROFILE TO DATABASE ────────────────────────────────────────────
  Future<void> _saveMeasurements(String customerId, String customerName) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final measurement = _buildCurrentMeasurementModel(customerId);
      await ref.read(measurementsProvider.notifier).addOrUpdateMeasurement(measurement);

      try {
        final Box draftBox = Hive.box('naap_drafts_box');
        final draftKey = widget.measurementId != null
            ? 'draft_${customerId}_${widget.measurementId}'
            : 'draft_$customerId';
        await draftBox.delete(draftKey);
        await draftBox.delete('draft_$customerId');
      } catch (_) {}

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      final profileName = measurement.profileName;

      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.measurements);
      }

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Naap saved! ($profileName)',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: _NaapColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: _NaapColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted && _isSaving) setState(() => _isSaving = false);
    }
  }

  // ── RESET ALL MEASUREMENTS ──────────────────────────────────────────────
  void _resetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset measurements? · تمام ناپ صاف کریں؟',
          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to clear all entered values for this profile?',
          style: GoogleFonts.dmSans(fontSize: 13, color: _NaapColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _NaapColors.rose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final ctrl in _controllers.values) {
        ctrl.clear();
      }
      _notesCtrl.clear();
      for (var s in _silaiOptions) {
        s['checked'] = false;
      }
      _recalcFilledCount();
      if (!mounted) return;
      setState(() => _currentStep = 0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All measurements reset'),
          backgroundColor: _NaapColors.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
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

      final pngBytes = await CardImageCapturer.captureOnDemand(
        context,
        cardWidget: NaapCardWidget(
          order: effectiveOrder,
          customer: customer,
          measurement: currentMeasurement,
        ),
        pixelRatio: 1.25,
      );

      final pdfBytes = await DarziPdfBuilder.buildPdfFromImageBytes(
        pngBytes,
        pageFormat: PdfPageFormat.a5,
      );

      await Printing.layoutPdf(
        name: 'Naap_${customer?.name ?? "Client"}.pdf',
        onLayout: (_) async => Uint8List.fromList(pdfBytes),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print Error: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: _NaapColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
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
                    'Please enter Length (لمبائی) measurement first',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: _NaapColors.gold,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        _focusNodes['lambai']?.requestFocus();
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
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.measurements);
      }
    }
  }

  void _jumpToStep(int n) {
    if (n < 0 || n > 2) return;
    if (n > _currentStep) {
      if (_currentStep == 1 && (_controllers['lambai']?.text.trim().isEmpty ?? true)) {
        _goToNextStep();
        return;
      }
    }
    HapticFeedback.lightImpact();
    _saveDraft();
    setState(() => _currentStep = n);
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    return Scaffold(
      backgroundColor: _NaapColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Top Hero Header matching HTML
            RepaintBoundary(
              child: _buildHeroHeader(customerId, selectedCustomer, isDesktop),
            ),

            // Main Body: Responsive Desktop vs Mobile
            Expanded(
              child: isDesktop
                  ? _buildDesktopLayout(customerId, selectedCustomer)
                  : _buildMobileLayout(customerId, selectedCustomer),
            ),

            // Floating Bottom Navigation Bar Dock
            RepaintBoundary(
              child: _buildBottomDock(customerId, selectedCustomer?.name ?? 'Client', isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  // ── HERO HEADER (MATCHING HTML: DARK ROUNDED BANNER + GOLD BRAND MARK) ──────
  Widget _buildHeroHeader(String customerId, CustomerModel? customer, bool isDesktop) {
    final customerName = customer?.name ?? widget.customerName ?? 'Client';
    final customerIdShort = customer != null
        ? (customer.id.length <= 6 ? customer.id : customer.id.substring(0, 5).toUpperCase())
        : '1045';

    return Container(
      margin: EdgeInsets.fromLTRB(16, isDesktop ? 16 : 8, 16, 12),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 22 : 14, vertical: isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: _NaapColors.dark,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28151922),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button to return to previous screen / Customer Details
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.measurements);
                }
              },
              borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
              child: Container(
                width: isDesktop ? 40 : 36,
                height: isDesktop ? 40 : 36,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _NaapColors.darkSurface,
                  border: Border.all(color: _NaapColors.darkLine),
                  borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFFE9ECF2),
                    size: 19,
                  ),
                ),
              ),
            ),
          ),

          // Brand Mark: Gold Gradient 'D'
          Container(
            width: isDesktop ? 42 : 36,
            height: isDesktop ? 42 : 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_NaapColors.gold2, _NaapColors.gold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isDesktop ? 13 : 11),
            ),
            child: const Center(
              child: Text(
                'D',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF241605),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle + Customer Chip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Naap Studio', style: _NaapStyles.heroTitle.copyWith(fontSize: isDesktop ? 20 : 16)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$customerIdShort · $customerName',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _NaapColors.gold2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Record measurements in 3 simple steps · ناپ ریکارڈ کریں',
                  style: _NaapStyles.heroSubtitle.copyWith(fontSize: isDesktop ? 11.5 : 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Hero Action Buttons (Print, Reset, Save)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeroButton(
                icon: Icons.print_outlined,
                label: 'Print',
                isPrimary: false,
                isDesktop: isDesktop,
                onTap: _isPrinting ? null : () => _printNaapCard(customerId, customer),
              ),
              const SizedBox(width: 8),
              _buildHeroButton(
                icon: Icons.refresh_rounded,
                label: 'Reset',
                isPrimary: false,
                isDesktop: isDesktop,
                onTap: _resetAll,
              ),
              const SizedBox(width: 8),
              _buildHeroButton(
                icon: Icons.check_rounded,
                label: 'Save Naap',
                isPrimary: true,
                isDesktop: isDesktop,
                onTap: _isSaving ? null : () => _saveMeasurements(customerId, customerName),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required bool isDesktop,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 13 : 9),
          decoration: BoxDecoration(
            color: isPrimary ? _NaapColors.gold : _NaapColors.darkSurface,
            border: Border.all(
              color: isPrimary ? _NaapColors.gold : _NaapColors.darkLine,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isPrimary ? const Color(0xFF211500) : const Color(0xFFE9ECF2),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? const Color(0xFF211500) : const Color(0xFFE9ECF2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── DESKTOP LAYOUT (2 COLUMNS: STICKY SIDEBAR + MAIN CONTENT) ────────────────
  Widget _buildDesktopLayout(String customerId, CustomerModel? customer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDEBAR (WIDTH 320PX)
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 90),
              child: RepaintBoundary(
                child: _buildDesktopSidebar(),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // RIGHT MAIN VIEW
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopNavbar(),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 90),
                    child: _buildActiveStepContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── DESKTOP SIDEBAR WIDGET ──────────────────────────────────────────────────
  Widget _buildDesktopSidebar() {
    final activeFields = getFieldsForProfile(_profileNameCtrl.text);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NaapColors.line),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E111827),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cover Card with Golden Tape Icon
          Container(
            height: 126,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_NaapColors.darkCard, Color(0xFF1F2633)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_NaapColors.gold2, _NaapColors.gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _NaapColors.gold.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.straighten_rounded, color: Color(0xFF241505), size: 26),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Naap Profile',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _profileNameNotifier,
                    builder: (context, name, child) {
                      return Text(
                        '$name · ${_selectedCategory.label}',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFAEB5C2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 2. Vertical Steps Navigator (vsteps)
                _buildVStep(0, 'Setup', 'Category & type', 'سیٹ اپ'),
                const SizedBox(height: 6),
                _buildVStep(1, 'Naap', '${activeFields.length} measurements', 'ناپ'),
                const SizedBox(height: 6),
                _buildVStep(2, 'Silai & Design', 'Stitching options', 'سلائی و ڈیزائن'),

                const SizedBox(height: 16),

                // 3. Overall Progress Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _NaapColors.paper,
                    border: Border.all(color: _NaapColors.line),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'OVERALL PROGRESS',
                            style: GoogleFonts.dmSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                              color: _NaapColors.muted,
                            ),
                          ),
                          Text(
                            '${((_currentStep + 1) * 33.33).round()}%',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _NaapColors.gold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          height: 6,
                          color: Colors.white,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: (_currentStep + 1) / 3,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_NaapColors.gold, _NaapColors.gold2],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Live Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _NaapColors.goldBg,
                    border: Border.all(color: _NaapColors.goldLine),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LIVE SUMMARY',
                            style: GoogleFonts.dmSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                              color: const Color(0xFF8B6C22),
                            ),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _filledCountNotifier,
                            builder: (context, filled, child) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$filled/${activeFields.length}',
                                  style: GoogleFonts.ibmPlexMono(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF8B6C22),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: _profileNameNotifier,
                        builder: (context, name, child) {
                          return Text(
                            name,
                            style: GoogleFonts.notoNastaliqUrdu(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: _NaapColors.ink,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: _NaapColors.goldLine),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  ValueListenableBuilder<int>(
                                    valueListenable: _filledCountNotifier,
                                    builder: (context, count, child) => Text(
                                      '$count',
                                      style: GoogleFonts.ibmPlexMono(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _NaapColors.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'FILLED',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: _NaapColors.muted,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: _NaapColors.goldLine),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${_silaiOptions.where((s) => s['checked'] == true).length}',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _NaapColors.ink,
                                    ),
                                  ),
                                  Text(
                                    'STITCHES',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: _NaapColors.muted,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Live mini items
                      ValueListenableBuilder<int>(
                        valueListenable: _filledCountNotifier,
                        builder: (context, filled, child) {
                          final filledEntries = _controllers.entries
                              .where((e) => e.value.text.trim().isNotEmpty)
                              .take(4)
                              .toList();

                          if (filledEntries.isEmpty) {
                            return Text(
                              'Measurements will appear here as you fill them',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
                                fontSize: 10.5,
                                color: const Color(0xFF8B6C22).withValues(alpha: 0.75),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              ...filledEntries.map((e) {
                                final f = k15MeasurementFields.firstWhere(
                                  (cfg) => cfg.key == e.key,
                                  orElse: () => MeasurementFieldConfig(key: e.key, nameUrdu: e.key, nameEng: e.key),
                                );
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: _NaapColors.goldLine),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        f.nameUrdu,
                                        style: GoogleFonts.notoNastaliqUrdu(fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        '${e.value.text.trim()}"',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF8B6C22),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (filled > 4)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '+${filled - 4} more',
                                    style: GoogleFonts.ibmPlexMono(fontSize: 10, color: const Color(0xFF8B6C22)),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 5. Quick Tips Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _NaapColors.paper,
                    border: Border.all(color: _NaapColors.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUICK TIPS',
                        style: GoogleFonts.dmSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                          color: _NaapColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTipItem('Measure over a well-fitted shirt for accuracy'),
                      _buildTipItem('Keep the tape snug but not tight'),
                      _buildTipItem('Length (لمبائی) is required before moving on'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: const BoxDecoration(
              color: _NaapColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(fontSize: 11, color: _NaapColors.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVStep(int stepIdx, String title, String sub, String urdu) {
    final isActive = _currentStep == stepIdx;
    final isDone = _currentStep > stepIdx;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _jumpToStep(stepIdx),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _NaapColors.dark : (isDone ? Colors.white : const Color(0xFFFAFAFB)),
            border: Border.all(
              color: isActive
                  ? _NaapColors.dark
                  : (isDone ? _NaapColors.greenLine : _NaapColors.line),
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _NaapColors.dark.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDone
                      ? _NaapColors.green
                      : (isActive ? _NaapColors.gold : Colors.white),
                  border: Border.all(
                    color: isDone
                        ? _NaapColors.green
                        : (isActive ? _NaapColors.gold : _NaapColors.line),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${stepIdx + 1}',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isActive ? const Color(0xFF211500) : _NaapColors.muted,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isActive ? Colors.white : _NaapColors.ink,
                      ),
                    ),
                    Text(
                      sub,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive ? const Color(0xFFAEB5C2) : _NaapColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                urdu,
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? _NaapColors.gold2 : _NaapColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── DESKTOP NAVBAR TABS ─────────────────────────────────────────────────────
  Widget _buildDesktopNavbar() {
    final activeFields = getFieldsForProfile(_profileNameCtrl.text);

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NaapColors.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildNavTab(0, 'Setup'),
              const SizedBox(width: 4),
              _buildNavTab(1, 'Naap', badgeCount: activeFields.length),
              const SizedBox(width: 4),
              _buildNavTab(2, 'Silai & Design'),
            ],
          ),
          Row(
            children: [
              _buildNavIconSquare(
                icon: Icons.print_outlined,
                tooltip: 'Print Naap',
                onTap: () {
                  final customerId = ref.read(selectedMeasurementCustomerIdProvider) ?? widget.customerId;
                  if (customerId != null) {
                    final c = ref.read(customersProvider).valueOrNull?.firstWhere((x) => x.id == customerId);
                    _printNaapCard(customerId, c);
                  }
                },
              ),
              const SizedBox(width: 6),
              _buildNavIconSquare(
                icon: Icons.refresh_rounded,
                tooltip: 'Reset Fields',
                onTap: _resetAll,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab(int idx, String title, {int? badgeCount}) {
    final isActive = _currentStep == idx;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _jumpToStep(idx),
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _NaapColors.dark : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _NaapColors.dark.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : _NaapColors.muted,
                ),
              ),
              if (badgeCount != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$badgeCount',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isActive ? _NaapColors.gold2 : _NaapColors.muted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIconSquare({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: _NaapColors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _NaapColors.muted),
          ),
        ),
      ),
    );
  }

  // ── ACTIVE STEP CONTENT SWITCHER ──────────────────────────────────────────
  Widget _buildActiveStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Setup();
      case 1:
        return _buildStep2Naap();
      case 2:
        return _buildStep3Silai();
      default:
        return const SizedBox();
    }
  }

  // ── STEP 1: SETUP (MATCHING HTML BENTO GRID) ──────────────────────────────
  Widget _buildStep1Setup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          title: 'Setup your naap profile',
          subtitle: 'Choose the gender, garment type, and give this profile a name.',
          stepBadge: 'Step 1 of 3',
        ),
        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: _buildGenderCategoryBentoCard(),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<String>(
                          valueListenable: _profileNameNotifier,
                          builder: (context, name, child) {
                            return _buildMetricCard(
                              icon: Icons.edit_note_rounded,
                              iconColor: _NaapColors.gold,
                              iconBg: _NaapColors.goldBg,
                              bigText: name,
                              isUrdu: true,
                              smallLabel: 'Profile name',
                              trendLabel: 'Auto-generated',
                              trendColor: _NaapColors.gold,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: _NaapColors.blue,
                          iconBg: _NaapColors.blueBg,
                          bigText: _selectedProfileType == 'custom' ? 'Custom' : _selectedProfileType,
                          isUrdu: _selectedProfileType != 'custom',
                          smallLabel: 'Garment',
                          trendLabel: 'Selected',
                          trendColor: _NaapColors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGarmentTypeGridCard(),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _NaapColors.line),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08111827),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PROFILE NAME · عنوان', style: _NaapStyles.cardTag),
              const SizedBox(height: 10),
              TextField(
                controller: _profileNameCtrl,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _NaapColors.ink,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFFAFAFB),
                  hintText: 'پروفائل کا نام درج کریں...',
                  hintStyle: GoogleFonts.notoNastaliqUrdu(
                    fontSize: 13,
                    color: _NaapColors.faint,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: _NaapColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: _NaapColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: const BorderSide(color: _NaapColors.gold, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF8F1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEED59E)),
                ),
                child: Text(
                  'This name will appear in order booking and naap history. Leave it as the preset name or type a custom one.',
                  style: GoogleFonts.dmSans(fontSize: 11.5, color: const Color(0xFF78633A)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderCategoryBentoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NaapColors.line),
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GENDER CATEGORY · صنف', style: _NaapStyles.cardTag),
          const SizedBox(height: 14),
          _buildGenderOption('👔', 'مرد', 'Men', MeasurementCategory.men),
          const SizedBox(height: 9),
          _buildGenderOption('👗', 'عورت', 'Women', MeasurementCategory.women),
          const SizedBox(height: 9),
          _buildGenderOption('🧒', 'بچے', 'Kids', MeasurementCategory.children),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String emoji, String urdu, String eng, MeasurementCategory cat) {
    final isSelected = _selectedCategory == cat;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedCategory = cat);
          _onFieldChanged();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _NaapColors.dark : const Color(0xFFFAFAFB),
            border: Border.all(
              color: isSelected ? _NaapColors.dark : _NaapColors.line,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.white.withValues(alpha: 0.15) : _NaapColors.line,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urdu,
                      style: GoogleFonts.notoNastaliqUrdu(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : _NaapColors.ink,
                      ),
                    ),
                    Text(
                      eng,
                      style: GoogleFonts.dmSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isSelected ? const Color(0xFFAEB5C2) : _NaapColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _NaapColors.gold : _NaapColors.line,
                    width: 2,
                  ),
                  color: isSelected ? _NaapColors.gold : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String bigText,
    required bool isUrdu,
    required String smallLabel,
    required String trendLabel,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NaapColors.line),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06111827),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            bigText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isUrdu
                ? GoogleFonts.notoNastaliqUrdu(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _NaapColors.ink,
                  )
                : _NaapStyles.monoMetric.copyWith(fontSize: 18, color: _NaapColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            smallLabel.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: _NaapColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            trendLabel,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGarmentTypeGridCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NaapColors.line),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GARMENT TYPE · لباس کی قسم', style: _NaapStyles.cardTag),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 1.7,
            children: [
              ..._profilePresetTypes.map((type) => _buildGarmentOption(type, false)),
              _buildGarmentOption('اپنا نام', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGarmentOption(String type, bool isCustom) {
    final isSelected = isCustom
        ? _selectedProfileType == 'custom'
        : _selectedProfileType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            if (isCustom) {
              _selectedProfileType = 'custom';
            } else {
              _selectedProfileType = type;
              _profileNameCtrl.text = type;
              _profileNameNotifier.value = type;
            }
          });
          _onFieldChanged();
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _NaapColors.dark : const Color(0xFFFAFAFB),
            border: Border.all(
              color: isSelected ? _NaapColors.dark : _NaapColors.line,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.white.withValues(alpha: 0.15) : _NaapColors.line,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    isCustom ? '＋' : '◈',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isCustom ? _NaapColors.gold : _NaapColors.ink),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoNastaliqUrdu(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: isSelected ? Colors.white : _NaapColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 2: NAAP (2 CARDS: UPPER BODY & LOWER BODY) ───────────────────────
  Widget _buildStep2Naap() {
    final profileName = _profileNameCtrl.text;
    final upperFields = getUpperFieldsForProfile(profileName);
    final lowerFields = getLowerFieldsForProfile(profileName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          title: 'Record measurements',
          subtitle: 'Enter each measurement in inches. Fields highlight in gold as you fill them.',
          stepBadge: 'Step 2 of 3',
        ),
        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildMeasurementCard(
                badgeSymbol: '◈',
                badgeColor: _NaapColors.gold,
                badgeBg: _NaapColors.goldBg,
                titleEng: 'Upper body',
                titleUrdu: 'اُوپری حصہ',
                fields: upperFields,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMeasurementCard(
                badgeSymbol: '◐',
                badgeColor: _NaapColors.green,
                badgeBg: _NaapColors.greenBg,
                titleEng: 'Lower body',
                titleUrdu: 'نِچلا حصہ',
                fields: lowerFields,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMeasurementCard({
    required String badgeSymbol,
    required Color badgeColor,
    required Color badgeBg,
    required String titleEng,
    required String titleUrdu,
    required List<MeasurementFieldConfig> fields,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _NaapColors.line),
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06111827),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(
                        badgeSymbol,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$titleEng · $titleUrdu',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _NaapColors.ink,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<int>(
                valueListenable: _filledCountNotifier,
                builder: (context, filled, child) {
                  final filledInGroup = fields
                      .where((f) => _controllers[f.key]?.text.trim().isNotEmpty ?? false)
                      .length;
                  final isFull = filledInGroup == fields.length && fields.isNotEmpty;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFull ? _NaapColors.greenBg : const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$filledInGroup/${fields.length}',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isFull ? _NaapColors.green : _NaapColors.muted,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No fields for this garment',
                  style: GoogleFonts.dmSans(fontSize: 12, color: _NaapColors.muted),
                ),
              ),
            )
          else
            Column(
              children: fields.map((f) {
                return MeasurementInputRow(
                  field: f,
                  controller: _controllers[f.key]!,
                  focusNode: _focusNodes[f.key]!,
                  onChanged: _onFieldChanged,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── STEP 3: SILAI & DESIGN (MATCHING HTML DESIGN) ─────────────────────────
  Widget _buildStep3Silai() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          title: 'Stitching & design',
          subtitle: 'Select stitching options and design preferences for this profile.',
          stepBadge: 'Step 3 of 3',
        ),
        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _NaapColors.line),
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06111827),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STITCHING OPTIONS · سلائی', style: _NaapStyles.cardTag),
                    const SizedBox(height: 12),
                    GridView.builder(
                      itemCount: _silaiOptions.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.7,
                      ),
                      itemBuilder: (ctx, i) {
                        final item = _silaiOptions[i];
                        final label = item['label'] as String;
                        final isChecked = item['checked'] as bool;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _silaiOptions[i] = {'label': label, 'checked': !isChecked};
                              });
                              _onFieldChanged();
                            },
                            borderRadius: BorderRadius.circular(13),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isChecked ? Colors.white : const Color(0xFFFAFAFB),
                                border: Border.all(
                                  color: isChecked ? _NaapColors.gold : _NaapColors.line,
                                ),
                                borderRadius: BorderRadius.circular(13),
                                boxShadow: isChecked
                                    ? [
                                        BoxShadow(
                                          color: _NaapColors.gold.withValues(alpha: 0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isChecked ? _NaapColors.gold : Colors.white,
                                      border: Border.all(
                                        color: isChecked ? _NaapColors.gold : const Color(0xFFCBD5E1),
                                        width: 1.8,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: isChecked
                                        ? const Center(
                                            child: Icon(Icons.check, size: 13, color: Colors.white),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: GoogleFonts.notoNastaliqUrdu(
                                        fontSize: 11.5,
                                        fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
                                        color: isChecked ? _NaapColors.ink : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _NaapColors.line),
                      borderRadius: BorderRadius.circular(21),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06111827),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DESIGN OPTIONS · ڈیزائن', style: _NaapStyles.cardTag),
                        const SizedBox(height: 10),
                        _buildDesignRow(
                          urdu: 'کالر',
                          eng: 'Collar Type',
                          current: _collarType,
                          options: ['Standard', 'Mandarin', 'Peshawari', 'Spread'],
                          onSelect: (v) => setState(() => _collarType = v),
                        ),
                        _buildDesignRow(
                          urdu: 'گلہ',
                          eng: 'Neck Style',
                          current: _neckStyle,
                          options: ['Round', 'Open', 'Closed'],
                          onSelect: (v) => setState(() => _neckStyle = v),
                        ),
                        _buildDesignRow(
                          urdu: 'کف',
                          eng: 'Kaf Style',
                          current: _kafStyle,
                          options: ['Standard', 'Embroidery', 'Button', 'Double'],
                          onSelect: (v) => setState(() => _kafStyle = v),
                        ),
                        _buildDesignRow(
                          urdu: 'فرنٹ',
                          eng: 'Front Style',
                          current: _frontStyle,
                          options: ['Standard', 'Embroidery', 'Covered', 'None'],
                          onSelect: (v) => setState(() => _frontStyle = v),
                        ),
                        _buildDesignRow(
                          urdu: 'جیب',
                          eng: 'Pocket Type',
                          current: _pocketType,
                          options: ['Chest', 'Side', 'None'],
                          onSelect: (v) => setState(() => _pocketType = v),
                        ),
                        _buildDesignRow(
                          urdu: 'فٹنگ',
                          eng: 'Shape',
                          current: _shape,
                          options: ['Straight', 'Fitting', 'Loose'],
                          onSelect: (v) => setState(() => _shape = v),
                        ),
                        _buildDesignRow(
                          urdu: 'شلوار',
                          eng: 'Shalwar Style',
                          current: _shalwarStyle,
                          options: ['Straight', 'Churidar', 'Patiala', 'Peshawari'],
                          onSelect: (v) => setState(() => _shalwarStyle = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _NaapColors.line),
                      borderRadius: BorderRadius.circular(21),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06111827),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SPECIAL INSTRUCTIONS · ہدایات', style: _NaapStyles.cardTag),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          textDirection: TextDirection.rtl,
                          onChanged: (_) => _onFieldChanged(),
                          style: GoogleFonts.notoNastaliqUrdu(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _NaapColors.ink,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFFAFAFB),
                            hintText: 'کوئی خاص ہدایت لکھیں... (مثلاً: بازو باریک رکھنا ہے)',
                            hintStyle: GoogleFonts.notoNastaliqUrdu(
                              fontSize: 11,
                              color: _NaapColors.faint,
                            ),
                            hintTextDirection: TextDirection.rtl,
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(color: _NaapColors.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(color: _NaapColors.line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(color: _NaapColors.gold, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesignRow({
    required String urdu,
    required String eng,
    required String current,
    required List<String> options,
    required ValueChanged<String> onSelect,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        border: Border.all(color: _NaapColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                urdu,
                style: GoogleFonts.notoNastaliqUrdu(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              Text(
                eng.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: _NaapColors.muted,
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final idx = options.indexOf(current);
                final nextVal = options[(idx + 1) % options.length];
                onSelect(nextVal);
                _onFieldChanged();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _NaapColors.goldBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      current,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF8B6C22),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF8B6C22)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION HEADER (REUSABLE) ───────────────────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required String stepBadge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _NaapStyles.sectionTitle),
            const SizedBox(height: 2),
            Text(subtitle, style: _NaapStyles.sectionSubtitle),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: _NaapColors.greenBg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _NaapColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                stepBadge,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: _NaapColors.green,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT (< 850PX) ────────────────────────────────────────────────
  Widget _buildMobileLayout(String customerId, CustomerModel? customer) {
    final activeFields = getFieldsForProfile(_profileNameCtrl.text);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mobile Naap Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _NaapColors.dark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_NaapColors.gold2, _NaapColors.gold],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Center(
                    child: Icon(Icons.straighten_rounded, color: Color(0xFF241505), size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: _profileNameNotifier,
                        builder: (context, name, child) => Text(
                          name,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedCategory.label} · Naap profile',
                        style: GoogleFonts.ibmPlexMono(fontSize: 10, color: const Color(0xFFAEB5C2)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'STEP ${_currentStep + 1}/3',
                          style: GoogleFonts.dmSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: _NaapColors.gold2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Mobile Stepper Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _NaapColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildMobileStepChip(0, 'Setup'),
                _buildMobileStepBar(0),
                _buildMobileStepChip(1, 'Naap'),
                _buildMobileStepBar(1),
                _buildMobileStepChip(2, 'Silai'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Mobile Progress Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _NaapColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PROGRESS', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w900, color: _NaapColors.muted)),
                    Text('${((_currentStep + 1) * 33.33).round()}%', style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w800, color: _NaapColors.gold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 5,
                    color: _NaapColors.paper,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (_currentStep + 1) / 3,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [_NaapColors.gold, _NaapColors.gold2]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Mobile Section Tabs
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFE9EBEF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                _buildMobileTab(0, 'Setup'),
                _buildMobileTab(1, 'Naap', countText: '${_filledCountNotifier.value}/${activeFields.length}'),
                _buildMobileTab(2, 'Silai'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Active Mobile Content
          _buildActiveStepContent(),
        ],
      ),
    );
  }

  Widget _buildMobileStepChip(int idx, String title) {
    final isActive = _currentStep == idx;
    final isDone = _currentStep > idx;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _jumpToStep(idx),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? _NaapColors.green : (isActive ? _NaapColors.dark : const Color(0xFFF4F5F7)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isActive ? Colors.white : _NaapColors.muted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: isActive ? _NaapColors.dark : _NaapColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileStepBar(int leftIdx) {
    final isDone = _currentStep > leftIdx;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDone ? _NaapColors.green : _NaapColors.line,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildMobileTab(int idx, String title, {String? countText}) {
    final isActive = _currentStep == idx;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _jumpToStep(idx),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive
                  ? [
                      const BoxShadow(
                        color: Color(0x12111827),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                countText != null ? '$title $countText' : title,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isActive ? _NaapColors.ink : _NaapColors.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── FLOATING BOTTOM NAVIGATION DOCK (MATCHING HTML DESIGN) ──────────────────
  Widget _buildBottomDock(String customerId, String customerName, bool isDesktop) {
    final activeFields = getFieldsForProfile(_profileNameCtrl.text);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, isDesktop ? 16 : 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _NaapColors.line),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12111827),
                  blurRadius: 35,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Step Dots
                Row(
                  children: List.generate(3, (i) {
                    final isActive = _currentStep == i;
                    final isDone = _currentStep > i;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: isActive ? 34 : 22,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: isDone
                            ? _NaapColors.green
                            : (isActive ? _NaapColors.gold : _NaapColors.line),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),

                // Center Info Text
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _filledCountNotifier,
                    builder: (context, filled, child) {
                      return Text(
                        'Step ${_currentStep + 1} of 3 · $filled / ${activeFields.length} filled',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _NaapColors.muted,
                        ),
                      );
                    },
                  ),
                ),

                // Action Buttons (Back, Next, Save Naap)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentStep > 0) ...[
                      OutlinedButton(
                        onPressed: _goToPrevStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _NaapColors.ink,
                          side: const BorderSide(color: _NaapColors.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_back_rounded, size: 15),
                            const SizedBox(width: 5),
                            Text('Back', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (_currentStep < 2)
                      ElevatedButton(
                        onPressed: _goToNextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _NaapColors.dark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 0,
                        ),
                        child: Row(
                          children: [
                            Text('Next', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12)),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 15),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _isSaving ? null : () => _saveMeasurements(customerId, customerName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _NaapColors.gold,
                          foregroundColor: const Color(0xFF211500),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          elevation: 0,
                        ),
                        child: Row(
                          children: [
                            if (_isSaving)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF211500)),
                              )
                            else ...[
                              const Icon(Icons.check_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text('Save Naap', style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 12.5)),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── CUSTOMER SELECTOR FALLBACK (WHEN NO CUSTOMER IS SELECTED) ─────────────
  Widget _buildCustomerSelector(AsyncValue<List<CustomerModel>> customersAsync) {
    final text1 = _NaapColors.ink;
    final text2 = _NaapColors.muted;
    final allMeasurements = ref.watch(measurementsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: _NaapColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Select Client · گاہک منتخب کریں',
          style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: text1),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search customer by name or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _NaapColors.line),
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
                      final cMeasurements = allMeasurements.where((m) => m.customerId == c.id).toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _NaapColors.line),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (cMeasurements.isNotEmpty) {
                              _loadCustomerData(c.id, cMeasurements.first);
                            } else {
                              _startNewMeasurement(c.id);
                            }
                            ref.read(selectedMeasurementCustomerIdProvider.notifier).state = c.id;
                          },
                          leading: CustomerAvatar(name: c.name, size: 40, borderRadius: 10),
                          title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: text1)),
                          subtitle: Text(c.phone, style: GoogleFonts.ibmPlexMono(fontSize: 12, color: text2)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cMeasurements.isNotEmpty ? _NaapColors.greenBg : _NaapColors.paper,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cMeasurements.isNotEmpty ? '${cMeasurements.length} Naap' : 'New',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cMeasurements.isNotEmpty ? _NaapColors.green : _NaapColors.muted,
                              ),
                            ),
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
}

// ── ISOLATED MEASUREMENT INPUT ROW WIDGET (MAXIMUM CPU OPTIMIZATION) ─────────
// This widget manages its own highlight state locally without causing the
// parent screen to rebuild whenever a single character is typed!
class MeasurementInputRow extends StatefulWidget {
  final MeasurementFieldConfig field;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  const MeasurementInputRow({
    super.key,
    required this.field,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  State<MeasurementInputRow> createState() => _MeasurementInputRowState();
}

class _MeasurementInputRowState extends State<MeasurementInputRow> {
  late bool _isFilled;

  @override
  void initState() {
    super.initState();
    _isFilled = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _isFilled) {
      if (mounted) {
        setState(() => _isFilled = hasText);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _isFilled ? Colors.white : const Color(0xFFFAFAFB),
        border: Border.all(
          color: _isFilled ? _NaapColors.goldLine : _NaapColors.line,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: _isFilled
            ? [
                BoxShadow(
                  color: _NaapColors.gold.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // 1. Vector Shape Box (turns SOLID GOLD when filled!)
          RepaintBoundary(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isFilled ? _NaapColors.gold : _NaapColors.goldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(7),
              child: CustomPaint(
                painter: MeasurementShapePainter(
                  keyName: widget.field.key,
                  color: _isFilled ? Colors.white : _NaapColors.gold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),

          // 2. Urdu Name & English Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.field.nameUrdu,
                  style: GoogleFonts.notoNastaliqUrdu(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _NaapColors.ink,
                  ),
                ),
                Text(
                  widget.field.nameEng.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _NaapColors.muted,
                  ),
                ),
              ],
            ),
          ),

          // 3. Numeric Input Box + Unit "
          Container(
            width: 66,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _NaapColors.line),
              borderRadius: BorderRadius.circular(11),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              onChanged: (_) => widget.onChanged(),
              style: GoogleFonts.ibmPlexMono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _NaapColors.ink,
              ),
              decoration: const InputDecoration(
                hintText: '—',
                hintStyle: TextStyle(color: _NaapColors.faint),
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 5),

          Text(
            '"',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _NaapColors.faint,
            ),
          ),
        ],
      ),
    );
  }
}
