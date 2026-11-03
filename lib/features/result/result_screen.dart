import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../scan/scan_controller.dart';
import '../../ml/disease_classifier.dart';

/// Shows classification outcome (PRD Phase 4). Disease prediction runs
/// on-device via TensorFlow Lite model, completely offline. No Gemini UI
/// or external API calls are shown or required — the app works fully offline.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(scanControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(scanControllerProvider.notifier).reset();
            context.go('/');
          },
        ),
      ),
      body: AnimatedSwitcher(
        // Smooth cross-fade between the processing animation and the
        // result/error/low-confidence views. Pure UI: it never delays or
        // alters the real inference timing.
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey<ScanStatus>(scan.status),
          child: switch (scan.status) {
            ScanStatus.idle => const _IdleView(),
            ScanStatus.analyzing => const _AnalyzingView(),
            ScanStatus.error => _ErrorView(scan: scan),
            ScanStatus.lowConfidence => _LowConfidenceView(scan: scan),
            ScanStatus.notLeaf => _NotLeafView(scan: scan),
            ScanStatus.success => _SuccessView(scan: scan),
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Idle (navigated here without a scan)
// ---------------------------------------------------------------------
class _IdleView extends StatelessWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_search, size: 72),
            const SizedBox(height: 16),
            const Text('No leaf analysed yet.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Processing (FR-3): shown IMMEDIATELY after an image is picked, while
// the real classifier Future runs (no artificial delay anywhere — no
// Timers, no Future.delayed). The uploaded image stays visible under a
// moving scan line, a soft glow pulses around it, and rotating status
// text explains what is happening so the state is understandable from
// text alone (a11y), not just the animation.
// ---------------------------------------------------------------------
class _AnalyzingView extends ConsumerStatefulWidget {
  const _AnalyzingView();

  @override
  ConsumerState<_AnalyzingView> createState() => _AnalyzingViewState();
}

class _AnalyzingViewState extends ConsumerState<_AnalyzingView>
    with TickerProviderStateMixin {
  /// Sweeps the scan line down the leaf, 0..1, looping.
  late final AnimationController _scan;

  /// Pulses the glow around the image (reverses at each end).
  late final AnimationController _glow;

  /// Spins the small arc indicator.
  late final AnimationController _spin;

  /// Cycles through the status messages.
  late final AnimationController _messages;

  static const List<String> _statusTexts = [
    'Analyzing your leaf...',
    'Detecting disease patterns...',
    'Processing image...',
  ];

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      value: 0.5,
    )..repeat(reverse: true);
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _messages = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    // Runs whether this view leaves because the prediction arrived OR
    // because inference failed, so controllers never leak and the app can
    // never get stuck animating a dead Future.
    _scan.dispose();
    _glow.dispose();
    _spin.dispose();
    _messages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = ref.watch(scanControllerProvider).image;
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null)
              _ScanningImage(image: image, scan: _scan, glow: _glow)
            else
              Icon(Icons.eco, size: 84, color: theme.colorScheme.primary),
            const SizedBox(height: 28),
            _ArcIndicator(spin: _spin),
            const SizedBox(height: 16),
            _CyclingStatusText(controller: _messages),
            const SizedBox(height: 8),
            Text(
              'Please wait while the model checks the image.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The uploaded leaf with a vertical scanning line sweeping over it and a
/// gentle glow pulsing around the frame — the "model is reading this image" cue.
class _ScanningImage extends StatelessWidget {
  final File image;
  final Animation<double> scan;
  final Animation<double> glow;

  const _ScanningImage({
    required this.image,
    required this.scan,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const imageHeight = 280.0;
    const bandHeight = 56.0;

    return AnimatedBuilder(
      animation: Listenable.merge([scan, glow]),
      builder: (context, child) {
        final sweep = scan.value; // 0..1 position of the scan line
        final pulse = 0.5 + 0.5 * glow.value; // 0..1..0 soft breathing

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35 * pulse),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.file(
                  image,
                  height: imageHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                // Slight dim so the scan line reads clearly on bright leaves.
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.08 + 0.12 * pulse),
                  ),
                ),
                // Soft scan band...
                Positioned(
                  top: sweep * (imageHeight - bandHeight),
                  left: 0,
                  right: 0,
                  child: Container(
                    height: bandHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primary.withValues(alpha: 0),
                          primary.withValues(alpha: 0.35),
                          primary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                // ...with a crisp leading edge line.
                Positioned(
                  top: sweep * (imageHeight - 2),
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    color: primary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small rotating arc with a leaf glyph in the middle — a modern,
/// lightweight stand-in for a plain spinner.
class _ArcIndicator extends StatelessWidget {
  final Animation<double> spin;

  const _ArcIndicator({required this.spin});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 48,
      height: 48,
      child: AnimatedBuilder(
        animation: spin,
        builder: (context, _) => CustomPaint(
          painter: _ArcPainter(progress: spin.value, color: color),
          child: const Center(child: Icon(Icons.eco, size: 20)),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color;

    // A 3/4 arc that rotates a full turn per cycle.
    canvas.drawArc(
      Offset.zero & size,
      -math.pi / 2 + progress * 2 * math.pi,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Cycles the status texts with soft fades ("Analyzing your leaf..." ->
/// "Detecting disease patterns..." -> "Processing image...").
class _CyclingStatusText extends StatelessWidget {
  final Animation<double> controller;

  const _CyclingStatusText({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        const fade = 0.15;
        final texts = _AnalyzingViewState._statusTexts;
        final seg = controller.value * texts.length;
        final index = seg.floor().clamp(0, texts.length - 1);
        final local = seg - seg.floorToDouble();
        final opacity = local < fade
            ? local / fade
            : local > 1 - fade
                ? (1 - local) / fade
                : 1.0;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Text(
            texts[index],
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// Error with retry
// ---------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final ScanState scan;
  const _ErrorView({required this.scan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(scan.errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Low confidence (FR-5)
// ---------------------------------------------------------------------
class _LowConfidenceView extends StatelessWidget {
  final ScanState scan;
  const _LowConfidenceView({required this.scan});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (scan.image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(scan.image!, height: 220, fit: BoxFit.cover),
            ),
          const SizedBox(height: 20),
          Icon(Icons.help_outline,
              size: 64, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 12),
          Text('Not sure about this one',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'The photo may be unclear. Please retake it with better light, '
            'fill the frame with the leaf, and keep the background plain.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Retake Photo'),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Not a leaf (offline vegetation gate): the photo was of an object, room,
// poster etc. — the classifier would have forced a disease label onto it.
// ---------------------------------------------------------------------
class _NotLeafView extends StatelessWidget {
  final ScanState scan;

  const _NotLeafView({required this.scan});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (scan.image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(scan.image!, height: 220, fit: BoxFit.cover),
            ),
          const SizedBox(height: 20),
          Icon(Icons.energy_savings_leaf,
              size: 64, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 12),
          Text("This doesn't look like a pepper leaf",
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'No leaf was detected in this photo, so no disease check '
                'was made. Point the camera at a single black pepper '
                'leaf and fill the frame with it.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Tips: good light • hold the leaf flat • avoid shadows and '
            'background clutter.',
            style: TextStyle(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Try Another Photo'),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Success (FR-4, FR-6, FR-12 — no Gemini advice)
// ---------------------------------------------------------------------
class _SuccessView extends ConsumerWidget {
  final ScanState scan;

  const _SuccessView({required this.scan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prediction = scan.prediction!;
    final info = scan.diseaseInfo!;
    final pct = (prediction.confidence * 100).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(scan.image!, height: 220, fit: BoxFit.cover),
          ),
          const SizedBox(height: 16),

          // Disease name + confidence bar (FR-4)
          Text(info.displayName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: prediction.confidence,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Text('$pct%', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(info.description, style: theme.textTheme.bodyMedium),

          const SizedBox(height: 16),
          // Top 3 predictions (FR-12)
          _Top3Card(prediction: prediction),
          const SizedBox(height: 16),

          // Static guidance sections (FR-6)
          _InfoSection(
            icon: Icons.coronavirus,
            title: 'Symptoms',
            body: info.symptoms,
          ),
          _InfoSection(
            icon: Icons.healing,
            title: 'Treatment',
            body: info.treatment,
          ),
          _InfoSection(
            icon: Icons.shield,
            title: 'Prevention',
            body: info.prevention,
          ),

          const SizedBox(height: 8),
          // Disclaimer (PRD Phase 5)
          Text(
            'This guidance is indicative only. For serious cases, please '
            'consult your local agriculture officer.',
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan Another Leaf'),
                  onPressed: () {
                    ref.read(scanControllerProvider.notifier).reset();
                    context.go('/');
                  },
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Top 3 predictions (FR-12)
// ---------------------------------------------------------------------
class _Top3Card extends StatelessWidget {
  final Prediction prediction;
  const _Top3Card({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final entries = prediction.top3;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top predictions',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(_prettyLabel(e.key))),
                      Text('${(e.value * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  static String _prettyLabel(String label) {
    final spaced = label.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return label;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

// ---------------------------------------------------------------------
// Expandable static info sections (FR-6)
// ---------------------------------------------------------------------
class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        iconColor: Theme.of(context).colorScheme.primary,
        leading: Icon(icon),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [Align(alignment: Alignment.centerLeft, child: Text(body))],
      ),
    );
  }
}
