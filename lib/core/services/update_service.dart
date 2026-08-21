import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;

  const UpdateInfo({
    required this.version,
    required this.build,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isMandatory = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
    version: json['version'] ?? '',
    build: json['build'] ?? 0,
    downloadUrl: json['download_url'] ?? '',
    releaseNotes: json['release_notes'] ?? '',
    isMandatory: json['mandatory'] ?? false,
  );
}

class UpdateService {
  static const String _versionUrl =
    'https://raw.githubusercontent.com/sraofficeaf/darzi-pro/main/version.json';

  Future<UpdateInfo?> checkForUpdate() async {
    // Only check on Windows and Web
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final response = await http
        .get(Uri.parse(_versionUrl))
        .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final update = UpdateInfo.fromJson(data);
        if (update.build > currentBuild) return update;
      }
    } catch (_) {
      // Silent fail — no internet is fine
    }
    return null;
  }

  Future<void> openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0';
    }
  }
}
