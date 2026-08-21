import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> savePdfToDownloadsImpl(
  BuildContext context, {
  required Uint8List pdfBytes,
  required String fileName,
}) async {
  try {
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

Future<void> shareOrSavePdfImpl(
  BuildContext context, {
  required Uint8List pdfBytes,
  required String fileName,
  String? text,
}) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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
    // Mobile: Use Native OS Share Sheet
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    final xFile = XFile(file.path, mimeType: 'application/pdf');
    await Share.shareXFiles([xFile], text: text);
  }
}
