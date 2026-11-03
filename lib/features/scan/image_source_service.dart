import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around image_picker + permission_handler (PRD Phase 3).
/// Handles denied / permanently-denied permission flows with a friendly
/// dialog instead of a crash (FR-8).
class ImageSourceService {
  final ImagePicker _picker = ImagePicker();

  /// Returns the picked image file, or null if the user cancelled.
  Future<File?> pickFromCamera(BuildContext context) async {
    return _pick(context, ImageSource.camera);
  }

  Future<File?> pickFromGallery(BuildContext context) async {
    return _pick(context, ImageSource.gallery);
  }

  Future<File?> _pick(BuildContext context, ImageSource source) async {
    // Camera needs explicit permission; gallery uses the OS photo picker on
    // modern Android and needs none.
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          await _showSettingsDialog(
            context,
            'Camera permission is permanently disabled. '
            'Enable it in Settings to take photos.',
          );
        }
        return null;
      }
      if (!status.isGranted) {
        if (context.mounted) {
          await _showSettingsDialog(
            context,
            'Camera permission is needed to take leaf photos.',
          );
        }
        return null;
      }
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85, // keep files small (NFR-3 APK/size concerns)
        maxWidth: 1600,
      );
      if (picked == null) return null; // user cancelled the picker
      return File(picked.path);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get the image. Please try again.')),
        );
      }
      return null;
    }
  }

  Future<void> _showSettingsDialog(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permission needed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

final imageSourceServiceProvider =
    Provider<ImageSourceService>((ref) => ImageSourceService());
