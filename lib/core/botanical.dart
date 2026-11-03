import 'package:flutter/material.dart';

/// Shared "botanical" visual identity (per user's design reference):
/// near-black green gradient, translucent deep-green cards, lime accents.
///
/// Supports two palettes so the Settings "Dark Mode" toggle is actually
/// visible: dark = the original reference look, light = the same structure
/// on a pale green background. Choose with [BotanicalPaletteX.pal].
class BotanicalColors {
  BotanicalColors._();

  static const Color accent = Color(0xFF9CE872); // bright leaf green
  static const Color accentDeep = Color(0xFF4CAF50);
  static const Color ctaTop = Color(0xFFA8E063);
  static const Color ctaBottom = Color(0xFF56AB2F);
  static const Color bgTop = Color(0xFF0A1D10);
  static const Color bgBottom = Color(0xFF061209);
  static const Color cardFill = Color(0x141E4025); // translucent dark green
  static const Color cardBorder = Color(0x332E7D32);
  static const Color textPrimary = Color(0xFFF2F7EF);
  static const Color textSecondary = Color(0xFFB7C9B3);
  static const Color goodGreen = Color(0xFF66BB6A);
  static const Color badRed = Color(0xFFEF5350);

  /// Filled/outline styles for the leaf-shaped CTA. Identical in both modes
  /// (white text on green works everywhere).
  static LinearGradient get ctaGradient => const LinearGradient(
        colors: [ctaTop, ctaBottom],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
}

/// All colors a botanical screen needs, resolved for one brightness.
class BotanicalPalette {
  const BotanicalPalette({
    required this.bgTop,
    required this.bgBottom,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.cardFill,
    required this.cardBorder,
    required this.chipFill,
    required this.chipSelectedBg,
    required this.chipSelectedFg,
    required this.pillFill,
    required this.hillA,
    required this.hillB,
    required this.ringIdle,
    required this.goodGreen,
  });

  final Color bgTop;
  final Color bgBottom;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color cardFill;
  final Color cardBorder;
  final Color chipFill;
  final Color chipSelectedBg;
  final Color chipSelectedFg;
  final Color pillFill;
  final Color hillA;
  final Color hillB;
  final Color ringIdle;
  final Color goodGreen;

  static final BotanicalPalette dark = const BotanicalPalette(
    bgTop: BotanicalColors.bgTop,
    bgBottom: BotanicalColors.bgBottom,
    textPrimary: BotanicalColors.textPrimary,
    textSecondary: BotanicalColors.textSecondary,
    accent: BotanicalColors.accent,
    cardFill: BotanicalColors.cardFill,
    cardBorder: BotanicalColors.cardBorder,
    chipFill: Color(0xFF152B1C),
    chipSelectedBg: BotanicalColors.accent,
    chipSelectedFg: Color(0xFF12250F),
    pillFill: BotanicalColors.cardFill,
    hillA: Color(0x2B2E7D32),
    hillB: Color(0x401E5631),
    ringIdle: Color(0xFF57705C),
    goodGreen: BotanicalColors.goodGreen,
  );

  static final BotanicalPalette light = const BotanicalPalette(
    bgTop: Color(0xFFFBFDF9),
    bgBottom: Color(0xFFE4F2E5),
    textPrimary: Color(0xFF12281A),
    textSecondary: Color(0xFF4E6450),
    accent: Color(0xFF2E7D32),
    cardFill: Color(0xFFF4FAF4),
    cardBorder: Color(0xFFC6DFC9),
    chipFill: Color(0xFFEDF6EE),
    chipSelectedBg: Color(0xFF2E7D32),
    chipSelectedFg: Color(0xFFFFFFFF),
    pillFill: Color(0x0F2E7D32),
    hillA: Color(0x142E7D32),
    hillB: Color(0x1E3D8B39),
    ringIdle: Color(0xFF8FA795),
    goodGreen: Color(0xFF4CAF50),
  );
}

extension BotanicalPaletteX on BuildContext {
  BotanicalPalette get pal => Theme.of(this).brightness == Brightness.dark
      ? BotanicalPalette.dark
      : BotanicalPalette.light;
}

/// Scaffold background used by Home / History / Settings so all three
/// surfaces share the reference look: vertical gradient + soft painted
/// "hills" BEHIND the content (painted before children, never over text).
class BotanicalScaffold extends StatelessWidget {
  const BotanicalScaffold({super.key, required this.appBar, required this.child});

  final PreferredSizeWidget appBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pal.bgTop, pal.bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      // `painter` (not foregroundPainter) draws BEHIND the child tree, so the
      // hills sit under the scroll content instead of painting over text.
      child: CustomPaint(
        painter: _BotanicalDecorPainter(pal),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: child,
          extendBody: true,
        ),
      ),
    );
  }
}

/// Painted decorations: two soft "hill" curves near the bottom, matching the
/// reference mockups, rendered behind all content.
class _BotanicalDecorPainter extends CustomPainter {
  const _BotanicalDecorPainter(this.pal);

  final BotanicalPalette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final paintA = Paint()..color = pal.hillA;
    final paintB = Paint()..color = pal.hillB;

    // First hill
    final path1 = Path()
      ..moveTo(0, size.height * 0.94)
      ..quadraticBezierTo(
          size.width * 0.35, size.height * 0.84, size.width, size.height * 0.93)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path1, paintA);

    // Second, lower hill
    final path2 = Path()
      ..moveTo(0, size.height * 0.97)
      ..quadraticBezierTo(
          size.width * 0.6, size.height * 0.88, size.width, size.height * 0.96)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, paintB);
  }

  @override
  bool shouldRepaint(covariant _BotanicalDecorPainter old) {
    return old.pal != pal;
  }
}

/// Rounded circular icon chip used across the redesigned screens.
class BotanicalIconChip extends StatelessWidget {
  const BotanicalIconChip({
    super.key,
    required this.icon,
    this.size = 40,
    this.iconSize = 20,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pal.cardFill,
        border: Border.all(color: pal.cardBorder),
      ),
      child: Icon(icon, size: iconSize, color: pal.accent),
    );
  }
}

/// Card decoration shared by History rows, Settings cards etc.
BoxDecoration botanicalCard(BotanicalPalette pal, {double radius = 18}) {
  return BoxDecoration(
    color: pal.cardFill,
    border: Border.all(color: pal.cardBorder),
    borderRadius: BorderRadius.circular(radius),
  );
}
