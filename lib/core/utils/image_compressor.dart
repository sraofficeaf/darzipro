import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class ImageCompressor {
  static final _picker = ImagePicker();

  /// Picks an image from gallery, validates size < 1MB,
  /// then compresses to under 20KB.
  /// Throws [Exception] with user-friendly message on failure.
  static Future<Uint8List?> pickAndCompress() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final originalBytes = await picked.readAsBytes();

    // Gate: reject if original > 1MB (1,000,000 bytes)
    if (originalBytes.length > 1000000) {
      throw Exception('Image too large — please select an image under 1MB');
    }

    Uint8List compressed = originalBytes;
    int quality = 85;
    int minDimension = 800;

    // Iteratively reduce quality + dimensions until under 20KB
    while (compressed.length > 20000 && quality >= 10) {
      final result = await FlutterImageCompress.compressWithList(
        originalBytes,
        quality: quality,
        minWidth: minDimension,
        minHeight: minDimension,
        format: CompressFormat.jpeg,
      );
      compressed = result;
      quality -= 15;
      if (minDimension > 400) minDimension = (minDimension * 0.7).toInt();
    }

    if (compressed.length > 20000) {
      throw Exception(
        'Could not compress image enough — please try a simpler or smaller image',
      );
    }

    debugPrint('ImageCompressor: ${originalBytes.length} bytes → ${compressed.length} bytes (quality: $quality)');
    return compressed;
  }
}
