import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/theme_extensions.dart';
import '../../shared/providers/admin_providers.dart';
import '../../core/services/admin_service.dart';
import 'widgets/admin_ui_kit.dart';

class AdminVersionsScreen extends ConsumerStatefulWidget {
  const AdminVersionsScreen({super.key});

  @override
  ConsumerState<AdminVersionsScreen> createState() => _AdminVersionsScreenState();
}

class _AdminVersionsScreenState extends ConsumerState<AdminVersionsScreen> {
  final _versionCtrl = TextEditingController(text: '1.0.1');
  final _buildCtrl = TextEditingController(text: '2');
  final _urlCtrl = TextEditingController(text: 'https://github.com/sraofficeaf/darzipro/releases');
  final _notesCtrl = TextEditingController();
  bool _isMandatory = false;
  bool _isPublishing = false;

  @override
  void dispose() {
    _versionCtrl.dispose();
    _buildCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Future<void> _handlePublishVersion() async {
    final version = _versionCtrl.text.trim();
    final buildText = _buildCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    if (version.isEmpty || buildText.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill version name, build number, and download URL.'),
          backgroundColor: AdminColors.rose,
        ),
      );
      return;
    }

    final buildNumber = int.tryParse(buildText) ?? 1;

    setState(() => _isPublishing = true);

    final success = await AdminService.instance.publishAppVersion(
      version: version,
      buildNumber: buildNumber,
      downloadUrl: url,
      releaseNotes: notes,
      isMandatory: _isMandatory,
    );

    setState(() => _isPublishing = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App update published successfully!')),
      );
      _versionCtrl.clear();
      _buildCtrl.clear();
      _urlCtrl.clear();
      _notesCtrl.clear();
      ref.invalidate(adminVersionsProvider);
    }
  }

  void _openDownloadUrl(String urlStr) async {
    if (urlStr.isEmpty) return;
    final uri = Uri.tryParse(urlStr);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: urlStr));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download URL copied to clipboard.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionsAsync = ref.watch(adminVersionsProvider);
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
            // Top Header Bar (RepaintBoundary for zero scroll cost)
            RepaintBoundary(
              child: AdminPageHeader(
                title: 'App Release Management',
                subtitle: 'Manage Android APK releases, force updates & changelog history',
                action: AdminIconBtn(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh Versions',
                  onPressed: () => ref.invalidate(adminVersionsProvider),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: versionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.indigo)),
                  error: (err, stack) => Text('Error loading versions: $err', style: const TextStyle(color: AdminColors.rose)),
                  data: (versions) {
                    final publishFormWidget = RepaintBoundary(
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
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AdminColors.indigo.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.add_task_rounded, size: 18, color: AdminColors.indigo),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Publish New Release',
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: text1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _versionCtrl,
                                    style: GoogleFonts.inter(fontSize: 13, color: text1),
                                    decoration: InputDecoration(
                                      labelText: 'Version Name (e.g. 1.0.1)',
                                      labelStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                                      filled: true,
                                      fillColor: bg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _buildCtrl,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.inter(fontSize: 13, color: text1),
                                    decoration: InputDecoration(
                                      labelText: 'Build Number (e.g. 2)',
                                      labelStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                                      filled: true,
                                      fillColor: bg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _urlCtrl,
                              style: GoogleFonts.inter(fontSize: 13, color: text1),
                              decoration: InputDecoration(
                                labelText: 'APK / Release Download URL',
                                labelStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                                filled: true,
                                fillColor: bg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 3,
                              style: GoogleFonts.inter(fontSize: 13, color: text1),
                              decoration: InputDecoration(
                                labelText: 'Release Notes (Changelog)',
                                labelStyle: GoogleFonts.inter(fontSize: 12, color: text2),
                                hintText: 'What is new in this update...',
                                hintStyle: GoogleFonts.inter(fontSize: 12, color: text2.withValues(alpha: 0.6)),
                                filled: true,
                                fillColor: bg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Mandatory Update', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: text1)),
                              subtitle: Text('Forces app update before allowing access', style: GoogleFonts.inter(fontSize: 11, color: text2)),
                              value: _isMandatory,
                              activeTrackColor: AdminColors.rose,
                              onChanged: (val) => setState(() => _isMandatory = val),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: AdminButton.primary(
                                label: _isPublishing ? 'Publishing...' : 'Publish Release',
                                icon: _isPublishing ? null : Icons.rocket_launch_rounded,
                                onPressed: _isPublishing ? null : _handlePublishVersion,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final versionListWidget = Container(
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
                            'RELEASED APP VERSIONS (${versions.length})',
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: text1),
                          ),
                          const SizedBox(height: 14),
                          if (versions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text('No released app versions found.', style: GoogleFonts.inter(color: text2, fontSize: 13)),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: versions.length,
                              separatorBuilder: (context, idx) => Divider(height: 1, color: border.withValues(alpha: 0.6)),
                              itemBuilder: (context, idx) {
                                final v = versions[idx];
                                final isMandatory = v['is_mandatory'] == true;
                                final versionStr = _str(v['version'], '1.0.0');
                                final buildNum = _str(v['build_number'], '1');
                                final downloadUrl = _str(v['download_url'], '');
                                final notes = _str(v['release_notes'], 'No release notes specified.');

                                DateTime releasedAt = DateTime.now();
                                final rawDate = v['released_at'] ?? v['created_at'];
                                if (rawDate != null) {
                                  releasedAt = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
                                }

                                return RepaintBoundary(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: (isMandatory ? AdminColors.rose : AdminColors.emerald).withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isMandatory ? Icons.warning_rounded : Icons.system_update_rounded,
                                                color: isMandatory ? AdminColors.rose : AdminColors.emerald,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'v$versionStr',
                                                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: text1),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '(Build $buildNum)',
                                                        style: GoogleFonts.inter(fontSize: 12, color: text2),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      if (isMandatory)
                                                        const AdminBadge(label: 'MANDATORY', color: AdminColors.rose),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Released: ${DateFormat('dd MMM yyyy · hh:mm a').format(releasedAt)}',
                                                    style: GoogleFonts.inter(fontSize: 11, color: text2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (downloadUrl.isNotEmpty)
                                              AdminIconBtn(
                                                icon: Icons.download_rounded,
                                                tooltip: 'Open Download Link',
                                                color: AdminColors.indigo,
                                                onPressed: () => _openDownloadUrl(downloadUrl),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: bg,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: border.withValues(alpha: 0.6)),
                                          ),
                                          child: Text(
                                            notes,
                                            style: GoogleFonts.inter(fontSize: 12, color: text1),
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

                    if (isMobile) {
                      return Column(
                        children: [
                          publishFormWidget,
                          const SizedBox(height: 16),
                          versionListWidget,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: versionListWidget),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: publishFormWidget),
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
