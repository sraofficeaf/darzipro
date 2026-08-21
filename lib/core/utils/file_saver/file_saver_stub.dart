import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

Future<void> savePdfToDownloadsImpl(
  BuildContext context, {
  required Uint8List pdfBytes,
  required String fileName,
}) async {
  await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
}

Future<void> shareOrSavePdfImpl(
  BuildContext context, {
  required Uint8List pdfBytes,
  required String fileName,
  String? text,
}) async {
  await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
}
