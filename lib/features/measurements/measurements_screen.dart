import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/app_providers.dart';

class MeasurementsScreen extends ConsumerStatefulWidget {
  final String? customerId;
  final String? customerName;
  final MeasurementCategory? category;

  const MeasurementsScreen({
    super.key,
    this.customerId,
    this.customerName,
    this.category,
  });

  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen> {
  MeasurementCategory _category = MeasurementCategory.men;
  List<MeasurementSectionModel> _sections = [];
  final Map<String, TextEditingController> _controllers = {};
  String? _loadedCustomerId;
  MeasurementCategory? _loadedCategory;
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() => setState(() {}));
    if (widget.customerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedMeasurementCustomerIdProvider.notifier).state = widget.customerId;
          if (widget.category != null) {
            setState(() {
              _category = widget.category!;
            });
          }
        }
      });
    }
  }

  List<MeasurementSectionModel> _buildSectionsFromTemplateFields(List<dynamic> templateFields) {
    final Map<String, List<MeasurementFieldModel>> grouped = {};
    for (final fieldJson in templateFields) {
      final sectionName = fieldJson['section'] as String? ?? 'General';
      final field = MeasurementFieldModel(
        key: fieldJson['key'] as String? ?? '',
        label: fieldJson['label'] as String? ?? '',
        unit: fieldJson['unit'] as String? ?? 'in',
        value: '',
      );
      grouped.putIfAbsent(sectionName, () => []).add(field);
    }

    return grouped.entries.map((e) {
      return MeasurementSectionModel(
        title: e.key,
        fields: e.value,
      );
    }).toList();
  }

  void _changeCategory(MeasurementCategory cat) {
    setState(() => _category = cat);
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveMeasurements(String customerId, String customerName) async {
    if (_sections.isEmpty) return;

    final updatedSections = _sections.map((section) {
      return MeasurementSectionModel(
        title: section.title,
        fields: section.fields.map((field) {
          final ctrl = _controllers[field.key];
          return field.copyWith(value: ctrl?.text ?? '');
        }).toList(),
      );
    }).toList();

    final existingMeasurements = ref.read(customerMeasurementsProvider).valueOrNull ?? [];
    final existing = existingMeasurements.where((m) => m.category == _category).firstOrNull;

    final measurementId = existing?.id ?? const Uuid().v4();

    final measurement = MeasurementModel(
      id: measurementId,
      customerId: customerId,
      title: existing?.title ?? 'Naap - ${_category.label}',
      category: _category,
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    try {
      await ref.read(measurementsProvider.notifier).addOrUpdateMeasurement(measurement);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💾 Measurements saved for $customerName!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving measurements: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _addCustomField() async {
    if (_sections.isEmpty) return;

    final labelController = TextEditingController();
    final unitController = TextEditingController(text: 'in');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surf = isDark ? AppColors.surfDark : AppColors.surfLight;
        final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

        return AlertDialog(
          backgroundColor: surf,
          title: Text('Add Custom Field', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: t1)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(label: 'Field Label (e.g. Asseen/Ghera)', controller: labelController),
              AppTextField(label: 'Unit', controller: unitController),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (confirm == true && labelController.text.trim().isNotEmpty) {
      final label = labelController.text.trim();
      final key = label.toLowerCase().replaceAll(' ', '_');
      final field = MeasurementFieldModel(
        key: key,
        label: label,
        unit: unitController.text.trim().isEmpty ? 'in' : unitController.text.trim(),
        value: '',
      );

      setState(() {
        _sections[0] = MeasurementSectionModel(
          title: _sections[0].title,
          fields: [..._sections[0].fields, field],
        );
        _controllers[key] = TextEditingController(text: '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerId = ref.watch(selectedMeasurementCustomerIdProvider);
    final customersAsync = ref.watch(customersProvider);
    final templates = ref.watch(measurementTemplatesProvider).valueOrNull ?? [];
    final existingMeasurements = ref.watch(customerMeasurementsProvider).valueOrNull ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.bgDark : AppColors.bgLight;
    final t1 = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final t2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    // Load reactive data into controllers
    final hasData = (customerId == null) || (existingMeasurements.isNotEmpty || templates.isNotEmpty);
    if (hasData && (_loadedCustomerId != customerId || _loadedCategory != _category)) {
      _loadedCustomerId = customerId;
      _loadedCategory = _category;

      for (final ctrl in _controllers.values) {
        ctrl.dispose();
      }
      _controllers.clear();

      if (customerId != null) {
        final existing = existingMeasurements.where((m) => m.category == _category).firstOrNull;

        if (existing != null) {
          _sections = existing.sections;
          for (final section in _sections) {
            for (final field in section.fields) {
              _controllers[field.key] = TextEditingController(text: field.value);
            }
          }
        } else {
          final template = templates.where((t) => t['category'] == _category.name).firstOrNull;
          if (template != null) {
            final templateFields = template['fields'] as List<dynamic>? ?? [];
            _sections = _buildSectionsFromTemplateFields(templateFields);
            for (final section in _sections) {
              for (final field in section.fields) {
                _controllers[field.key] = TextEditingController(text: '');
              }
            }
          } else {
            _sections = [];
          }
        }
      } else {
        _sections = [];
      }
    }

    // Customer Selector view if customerId is null
    if (customerId == null) {
      return Scaffold(
        backgroundColor: bg,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Naap Card (Measurements)',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: t1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a client to add or edit their measurement card',
                style: GoogleFonts.inter(fontSize: 13, color: t2),
              ),
              const SizedBox(height: 16),
              // Search input: AppCard style focus glow search bar
              _buildSearchContainer(isDark, t1, t3),
              const SizedBox(height: 16),
              Expanded(
                child: customersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading clients: $err', style: const TextStyle(color: AppColors.red))),
                  data: (customers) {
                    final filtered = customers.where((c) {
                      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          c.phone.contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const EmptyState(emoji: '👥', title: 'No Clients Found');
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final c = filtered[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(selectedMeasurementCustomerIdProvider.notifier).state = c.id;
                            },
                            child: Row(
                              children: [
                                CustomerAvatar(name: c.name, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: t1,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(c.phone, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: t2)),
                                    ],
                                  ),
                                ),
                                Text(c.gender.emoji, style: const TextStyle(fontSize: 18)),
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

    final selectedCustomer = customersAsync.valueOrNull?.firstWhere(
      (c) => c.id == customerId,
      orElse: () => CustomerModel(
        id: customerId,
        name: 'Client',
        phone: '',
        address: '',
        gender: CustomerGender.male,
        createdAt: DateTime.now(),
      ),
    );

    final isAutoFilled = existingMeasurements.any((m) => m.category == _category);

    return Scaffold(
      backgroundColor: bg,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header with Client Info & Action Buttons
          Row(
            children: [
              if (widget.customerId != null) ...[
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: t1),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
              ],
              CustomerAvatar(name: selectedCustomer?.name ?? 'Client', size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedCustomer?.name ?? 'Client',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: t1,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          selectedCustomer?.phone ?? '',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: t2),
                        ),
                        if (isAutoFilled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tealS,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.teal.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Auto-filled ✓',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.customerId == null)
                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(selectedMeasurementCustomerIdProvider.notifier).state = null;
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.accent : AppColors.accentL,
                      backgroundColor: isDark
                          ? AppColors.accent.withValues(alpha: 0.12)
                          : AppColors.accentL.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: (isDark ? AppColors.accent : AppColors.accentL).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Change Client',
                      style: TextStyle(
                        color: isDark ? AppColors.accent : AppColors.accentL,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Category Chips: Men/Women/Children matching FilterChip style
          Row(
            children: [
              _buildCategoryChip(
                label: '👔 Men',
                isActive: _category == MeasurementCategory.men,
                onTap: () => _changeCategory(MeasurementCategory.men),
                isDark: isDark,
                text2: t2,
              ),
              _buildCategoryChip(
                label: '👗 Women',
                isActive: _category == MeasurementCategory.women,
                onTap: () => _changeCategory(MeasurementCategory.women),
                isDark: isDark,
                text2: t2,
              ),
              _buildCategoryChip(
                label: '👕 Children',
                isActive: _category == MeasurementCategory.children,
                onTap: () => _changeCategory(MeasurementCategory.children),
                isDark: isDark,
                text2: t2,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Measurement sections list
          if (_sections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No templates configured for this category.',
                  style: GoogleFonts.inter(color: t2),
                ),
              ),
            )
          else
            ..._sections.map((section) => _MeasurementSection(
                  section: section,
                  controllers: _controllers,
                )),

          const SizedBox(height: 10),

          // Save button: GoldButton full width
          GoldButton(
            width: double.infinity,
            height: 46,
            borderRadius: 16,
            onPressed: () => _saveMeasurements(customerId, selectedCustomer?.name ?? 'Client'),
            child: Text(
              'SAVE NAAP CARD',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A0F00),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Add Custom Field button
          SizedBox(
            height: 46,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _addCustomField();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColors.accent : AppColors.accentL,
                backgroundColor: isDark
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : AppColors.accentL.withValues(alpha: 0.08),
                side: BorderSide(color: (isDark ? AppColors.accent : AppColors.accentL).withValues(alpha: 0.3), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('＋  ', style: TextStyle(fontSize: 16, color: isDark ? AppColors.accent : AppColors.accentL)),
                  Text(
                    'Custom Field',
                    style: TextStyle(
                      color: isDark ? AppColors.accent : AppColors.accentL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSearchContainer(bool isDark, Color t1, Color t3) {
    return AppTextField(
      focusNode: _searchFocusNode,
      prefix: Icon(Icons.search_rounded, size: 18, color: t3),
      hint: 'Search clients by name or phone…',
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
    required Color text2,
  }) {
    final activeGradient = const LinearGradient(
      colors: [Color(0xFFF5A623), Color(0xFFD4791A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final bg = isDark ? const Color(0x09FFFFFF) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A);

    Widget chipContent = Center(
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isActive ? const Color(0xFF1A0F00) : text2,
        ),
      ),
    );

    Widget container = Container(
      decoration: BoxDecoration(
        color: isActive ? null : bg,
        gradient: isActive ? activeGradient : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.transparent : borderCol,
          width: 1.5,
        ),
        boxShadow: isActive
            ? const [
                BoxShadow(
                  color: Color(0x59F5A623),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: chipContent,
    );

    if (isDark && !isActive) {
      container = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: container,
        ),
      );
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: container,
        ),
      ),
    );
  }
}

class _MeasurementSection extends StatelessWidget {
  final MeasurementSectionModel section;
  final Map<String, TextEditingController> controllers;

  const _MeasurementSection({required this.section, required this.controllers});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.accent : AppColors.accentL;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                section.title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: accentColor,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: isDark ? const Color(0x12FFFFFF) : const Color(0x0D0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: section.fields
              .map((field) => _NaapField(
                    field: field,
                    controller: controllers[field.key],
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _NaapField extends StatefulWidget {
  final MeasurementFieldModel field;
  final TextEditingController? controller;

  const _NaapField({required this.field, this.controller});

  @override
  State<_NaapField> createState() => _NaapFieldState();
}

class _NaapFieldState extends State<_NaapField> {
  static const Map<String, String> _urduLabels = {
    'lambai': 'لمبائی',
    'teerwa': 'تیرو',
    'shoulder': 'تیرو',
    'bazo': 'بازو',
    'sleeve_lambai': 'بازو',
    'chhaati': 'چھاتی',
    'chaati': 'چھاتی',
    'baghal': 'بغل',
    'kamar': 'کمر',
    'daman': 'دامن',
    'collar': 'کالر',
    'gardan': 'کالر',
    'shalwar': 'شلوار',
    'shalwar_lambai': 'شلوار',
    'panche': 'پانچے',
    'pauncha': 'پانچے',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text2 = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final t3 = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    final String? urduLabel = _urduLabels[widget.field.key];
    final String englishLabel = widget.field.label;

    Widget labelWidget;
    if (urduLabel != null) {
      labelWidget = Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              englishLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: text2,
              ),
            ),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                urduLabel,
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF5A623), // accent gold
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      labelWidget = Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          englishLabel.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: text2,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        labelWidget,
        AppTextField(
          label: '',
          controller: widget.controller,
          keyboardType: TextInputType.number,
          suffix: Text(
            widget.field.unit,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: t3,
            ),
          ),
        ),
      ],
    );
  }
}
