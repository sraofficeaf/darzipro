import 'dart:io' show File, Directory, Platform, Process;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class DarziShareHelper {
  DarziShareHelper._();

  /// Explicitly saves PDF to Downloads/Documents folder, opens the file automatically, and shows SnackBar with "Open Folder".
  static Future<void> savePdfToDownloads(
    BuildContext context, {
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    try {
      if (kIsWeb) {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
        return;
      }

      Directory? targetDir;
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
      targetDir ??= await getApplicationDocumentsDirectory();

      final sep = Platform.pathSeparator;
      final filePath = '${targetDir.path}$sep$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes, flush: true);

      // Open the downloaded PDF file immediately
      try {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else if (Platform.isWindows) {
          await Process.run('explorer.exe', [filePath]);
        }
      } catch (e) {
        debugPrint('DarziShareHelper: Open file failed — $e');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📥 PDF Downloaded & Opened: $fileName'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10CBA0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'Open Folder',
              textColor: Colors.white,
              onPressed: () async {
                final folderUri = Uri.directory(targetDir!.path);
                if (await canLaunchUrl(folderUri)) {
                  await launchUrl(folderUri);
                } else if (Platform.isWindows) {
                  await Process.run('explorer.exe', [targetDir.path]);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('DarziShareHelper: save PDF failed — $e');
      try {
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      } catch (_) {}
    }
  }

  /// Sends/shares message and PDF to WhatsApp.
  static Future<void> shareWhatsApp(
    BuildContext context, {
    required Uint8List pdfBytes,
    required String fileName,
    required String phone,
    required String message,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isNotEmpty) {
      final waUri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      }
    }
    if (context.mounted) {
      await shareOrSavePdf(context, pdfBytes: pdfBytes, fileName: fileName, text: message);
    }
  }

  /// Shares or saves PDF bytes based on the target platform.
  /// On Desktop (Windows/Linux/macOS): Saves explicitly to Documents folder and shows a SnackBar with "Open Folder" action.
  /// On Mobile (Android/iOS) & Web: Uses OS native share sheet via share_plus.
  static Future<void> shareOrSavePdf(
    BuildContext context, {
    required Uint8List pdfBytes,
    required String fileName,
    String? text,
  }) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // Desktop: Save explicitly to Documents folder
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}\\$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📄 Saved to: $filePath'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1A2A40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'Open Folder',
              textColor: const Color(0xFFF5A623),
              onPressed: () async {
                final uri = Uri.directory(dir.path);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
        );
      }
    } else {
      // Mobile & Web: Use Native OS Share Sheet
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      final xFile = XFile(file.path, mimeType: 'application/pdf');
      await Share.shareXFiles([xFile], text: text);
    }
  }
}
