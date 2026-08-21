import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'file_saver/file_saver_stub.dart'
    if (dart.library.io) 'file_saver/file_saver_io.dart';

class DarziShareHelper {
  DarziShareHelper._();

  /// Explicitly saves PDF to Downloads/Documents folder, opens the file automatically, and shows SnackBar with "Open Folder".
  static Future<void> savePdfToDownloads(
    BuildContext context, {
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    await savePdfToDownloadsImpl(context, pdfBytes: pdfBytes, fileName: fileName);
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
  static Future<void> shareOrSavePdf(
    BuildContext context, {
    required Uint8List pdfBytes,
    required String fileName,
    String? text,
  }) async {
    await shareOrSavePdfImpl(context, pdfBytes: pdfBytes, fileName: fileName, text: text);
  }
}
