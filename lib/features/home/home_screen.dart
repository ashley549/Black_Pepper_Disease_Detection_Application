import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/botanical.dart';
import '../../l10n/app_strings.dart';
import '../scan/crop_screen.dart';
import '../scan/image_source_service.dart';
import '../scan/scan_controller.dart';
import '../settings/settings_screen.dart';

/// Entry screen (PRD Phase 3), restyled to the botanical reference:
/// bold two-tone headline, tips card, gradient CTA + outlined gallery pill.
/// Strings switch with the language chosen in Settings (FR-10).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageSource = ref.read(imageSourceServiceProvider);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppStrings.of(lang, key);

    Future<void> handlePick(ImageSource source) async {
      final file = source == ImageSource.camera
          ? await imageSource.pickFromCamera(context)
          : await imageSource.pickFromGallery(context);
      if (file == null) return; // cancelled or permission denied
      if (!context.mounted) return;

      // New crop step (user feedback): let the user focus on the leaf they
      // actually want before classification. Null = user cancelled cropping.
      final croppedPath = await CropScreen.push(context, file.path);
      if (croppedPath == null || !context.mounted) return;
      final croppedFile = File(croppedPath);

      // Navigate FIRST, then run inference: the result screen immediately
      // shows the animated processing state while the real TFLite Future
      // runs (startScan sets ScanStatus.analyzing synchronously). Waiting
      // here would leave the user on Home with a static image instead.
      unawaited(ref.read(scanControllerProvider.notifier).startScan(croppedFile));
      context.push('/result');
    }

    return BotanicalScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, color: context.pal.accent),
            const SizedBox(width: 8),
            Text(
              t('appTitle'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: t('history'),
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            tooltip: t('settings'),
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _Headline(lang: lang, t: t),
            const SizedBox(height: 16),
            Text(
              t('intro'),
              style: TextStyle(
                color: context.pal.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            _TipsCard(t: t),
            const SizedBox(height: 32),
            _GradientCta(
              label: t('takePhoto'),
              icon: Icons.photo_camera,
              onTap: () => handlePick(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _GalleryPill(
              label: t('chooseGallery'),
              onTap: () => handlePick(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Know your \n pepper leaf's health" with the green accent, then a short
/// green underline bar, matching the reference mockup. Non-English taglines
/// render as one accent heading because they have no guaranteed word split.
class _Headline extends StatelessWidget {
  const _Headline({required this.lang, required this.t});

  final String lang;
  final String Function(String) t;

  static const _taglineLine1 = 'Know your';
  static const _taglineRest =
      'health'; // tagline minus "Know your pepper leaf\u2019s "

  @override
  Widget build(BuildContext context) {
    final headingStyle = Theme.of(context).textTheme.headlineMedium;

    if (lang == 'en') {
      // Derive the final word from the actual localized string so any future
      // copy edit stays in sync.
      final tagline = t('tagline');
      final rest = _taglineRest;
      final taglineMinusRest = tagline.endsWith(rest)
          ? tagline.substring(0, tagline.length - rest.length).trim()
          : tagline;
      final green = taglineMinusRest.replaceFirst('$_taglineLine1 ', '');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$_taglineLine1\n', style: headingStyle),
                TextSpan(
                  text: '$green ',
                  style: headingStyle
                      ?.copyWith(color: context.pal.accent),
                ),
                if (rest.isNotEmpty)
                  TextSpan(text: rest, style: headingStyle),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 56,
            height: 5,
            decoration: BoxDecoration(
              color: context.pal.accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      );
    }

    // Fallback for Malayalam / Hindi (no safe split point).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('tagline'), style: headingStyle),
        const SizedBox(height: 10),
        Container(
          width: 56,
          height: 5,
          decoration: BoxDecoration(
            color: context.pal.accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

/// Photo tips card with camera title chip and green check rows.
class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.t});

  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.cardFill,
        border: Border.all(color: pal.cardBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              BotanicalIconChip(icon: Icons.photo_camera, size: 36, iconSize: 18),
              const SizedBox(width: 12),
              Text(
                t('tipsTitle'),
                style: TextStyle(
                  color: pal.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TipRow(text: t('tip1')),
          _TipRow(text: t('tip2')),
          _TipRow(text: t('tip3')),
          _TipRow(text: t('tip4')),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 20, color: pal.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: pal.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bright gradient "Take Photo" pill from the reference mockup.
class _GradientCta extends StatelessWidget {
  const _GradientCta({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            gradient: BotanicalColors.ctaGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: BotanicalColors.ctaBottom.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark translucent gallery pill sitting under the CTA.
class _GalleryPill extends StatelessWidget {
  const _GalleryPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0x141E4025)
            : const Color(0x0F2E7D32),
      ),
      icon: const Icon(Icons.photo_library, size: 22),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
