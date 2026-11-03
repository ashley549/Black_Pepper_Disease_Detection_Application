import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

import '../../l10n/app_strings.dart';
import '../settings/settings_screen.dart';

/// Full-screen crop step (added per user feedback): after picking/taking a
/// photo the user can move/resize a free-form rectangle so classification
/// focuses on the leaf they actually want, plus a rotate button for sideways
/// shots. Cancel returns home centred with the primary action.
///
/// Pushed with the picked file path as `extra`; pops with the cropped file
/// path (String) on success, or null when cancelled.
class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({super.key, required this.sourcePath});

  final String sourcePath;

  /// Convenience for navigation: returns cropped file path or null (cancel).
  static Future<String?> push(BuildContext context, String sourcePath) {
    return context.push<String>('/crop', extra: sourcePath);
  }

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  final _cropController = CropController();
  Uint8List? _imageBytes;
  bool _cropping = false;

  String t(String key) => AppStrings.of(ref.watch(languageProvider), key);

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      if (mounted) {
        setState(() => _imageBytes = bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('couldNotOpen')),
        ));
        context.pop();
      }
    }
  }

  Future<void> _rotate() async {
    if (_imageBytes == null || _cropping) return;
    setState(() => _cropping = true);
    try {
      final decoded = img.decodeImage(_imageBytes!);
      if (decoded != null) {
        final rotated = img.copyRotate(decoded, angle: 90);
        final encoded = img.encodeJpg(rotated, quality: 90);
        if (mounted) {
          setState(() => _imageBytes = encoded);
        }
      }
    } catch (_) {
      // Rotation is best-effort; never block the crop flow on it.
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _imageBytes;

    return PopScope(
      canPop: !_cropping,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(t('cropTitle')),
          actions: [
            IconButton(
              tooltip: t('rotate'),
              icon: const Icon(Icons.rotate_right),
              onPressed: _rotate,
            ),
          ],
        ),
        body: bytes == null
            ? const Center(child: CircularProgressIndicator())
            : Crop(
                image: bytes,
                controller: _cropController,
                onCropped: (result) async {
                  switch (result) {
                    case CropSuccess(:final croppedImage):
                      await _saveAndFinish(croppedImage);
                    case CropFailure():
                      if (mounted) {
                        setState(() => _cropping = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(t('cropFailed')),
                        ));
                      }
                  }
                },
                withCircleUi: false,
                baseColor: Colors.black.withValues(alpha: 0.75),
                maskColor: Colors.black54,
                radius: 8,
                initialRectBuilder: InitialRectBuilder.withBuilder(
                  (viewportRect, imageRect) => Rect.fromLTWH(
                    // Start with a generous centre box so the leaf is visible
                    // inside it from the start.
                    viewportRect.left + viewportRect.width * 0.15,
                    viewportRect.top + viewportRect.height * 0.15,
                    viewportRect.width * 0.70,
                    viewportRect.height * 0.70,
                  ),
                ),
                interactive: true,
                fixCropRect: false,
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                // Cancel sits centred between the two action buttons.
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        context.pop<String>(), // pops with null = cancelled
                    child: Text(t('cancel')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _cropping
                        ? null
                        : () {
                            setState(() => _cropping = true);
                            _cropController.crop();
                          },
                    child: _cropping
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t('useArea')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveAndFinish(Uint8List data) async {
    // Write beside the original so History thumbnails stay available even
    // after the source temp file is gone.
    final src = File(widget.sourcePath);
    final path =
        '${src.parent.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await File(path).writeAsBytes(data, flush: true);
      if (mounted) context.pop<String>(path);
    } catch (_) {
      if (mounted) {
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('couldNotSave')),
        ));
      }
    }
  }
}
