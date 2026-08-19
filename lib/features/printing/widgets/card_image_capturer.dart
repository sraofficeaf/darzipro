import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Material, MaterialType;

class CardImageCapturer {
  CardImageCapturer._();

  /// Captures a [RepaintBoundary] identified by [key] as PNG byte data.
  /// [pixelRatio] defaults to 1.5 for fast, high-quality, lightweight print output.
  static Future<Uint8List> capture(GlobalKey key, {double pixelRatio = 1.5}) async {
    RenderRepaintBoundary? boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null || boundary.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
      boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    }

    if (boundary == null) {
      throw Exception('CardImageCapturer: Widget not mounted or not a RepaintBoundary.');
    }

    // Retry only if boundary still needs paint
    if (boundary.debugNeedsPaint) {
      for (int i = 0; i < 5; i++) {
        await WidgetsBinding.instance.endOfFrame;
        boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null && !boundary.debugNeedsPaint) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    final RenderRepaintBoundary resolved = boundary ??
        (throw Exception('CardImageCapturer: Widget unmounted during capture.'));

    if (resolved.debugNeedsPaint) {
      throw Exception('CardImageCapturer: Boundary still needs paint after retries.');
    }

    final ui.Image image = await resolved.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('CardImageCapturer: Failed to generate PNG byte data from image.');
    }

    return byteData.buffer.asUint8List();
  }

  /// Mounts [cardWidget] inside a temporary off-screen [OverlayEntry], captures it as a PNG,
  /// and removes it immediately to avoid background rebuild costs.
  static Future<Uint8List> captureOnDemand(
    BuildContext context, {
    required Widget cardWidget,
    double? pixelRatio,
  }) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final completer = Completer<Uint8List>();

    // Determine optimal pixel ratio (2.2 for HD crisp 300 DPI sharpness on zoom)
    final resolvedPixelRatio = pixelRatio ?? (kIsWeb ? 2.0 : 2.2);

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999, // Render off-screen
        top: 0,
        child: Material(
          type: MaterialType.transparency,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(794, 1123),
                devicePixelRatio: 1.0,
              ),
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 794,
                  child: cardWidget,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Wait for layout + paint to complete
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        RenderRepaintBoundary? boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

        if (boundary == null || boundary.debugNeedsPaint) {
          await WidgetsBinding.instance.endOfFrame;
          boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        }

        // Wait for rendering to complete if needed
        if (boundary == null || boundary.debugNeedsPaint) {
          for (int i = 0; i < 3; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
            if (boundary != null && !boundary.debugNeedsPaint) break;
          }
        }

        final resolved = boundary ??
            (throw Exception('CardImageCapturer: Widget unmounted during capture.'));

        final ui.Image image = await resolved.toImage(pixelRatio: resolvedPixelRatio);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          throw Exception('CardImageCapturer: Failed to generate PNG byte data.');
        }

        completer.complete(byteData.buffer.asUint8List());
      } catch (e) {
        completer.completeError(e);
      } finally {
        entry.remove(); // Clean up immediately
      }
    });

    return completer.future;
  }
}
