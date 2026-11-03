import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/botanical.dart';
import '../../l10n/app_strings.dart';

/// Currently selected language code, persisted in shared_preferences.
class LanguageNotifier extends StateNotifier<String> {
  static const _prefsKey = 'language_code';

  LanguageNotifier() : super('en') {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefsKey) ?? 'en';
  }

  Future<void> setLanguage(String code) async {
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String>(
  (ref) => LanguageNotifier(),
);

/// Whether dark mode is enabled, persisted in shared_preferences (FR-14).
class DarkModeNotifier extends StateNotifier<bool> {
  static const _prefsKey = 'dark_mode';

  DarkModeNotifier() : super(false) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>(
  (ref) => DarkModeNotifier(),
);

/// Settings: language selector, dark mode, about (PRD Phase 7), restyled to
/// the botanical reference: section headers with icons, language rows with a
/// highlight ring, dark-mode switch card and description tiles for About.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final darkMode = ref.watch(darkModeProvider);
    final currentLang = ref.watch(languageProvider);
    String t(String key) => AppStrings.of(currentLang, key);

    return BotanicalScaffold(
      appBar: AppBar(
        title: Text(
          t('settings'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _SectionHeader(
              icon: Icons.language, text: t('language'), topPadding: 8),
          _LanguageCard(
            selected: language,
            onChanged: (code) =>
                ref.read(languageProvider.notifier).setLanguage(code),
          ),
          const SizedBox(height: 18),
          _DarkModeCard(
            value: darkMode,
            label: t('darkMode'),
            onChanged: (v) => ref.read(darkModeProvider.notifier).setEnabled(v),
          ),
          const SizedBox(height: 18),
          _SectionHeader(icon: Icons.info_outline, text: t('about')),
          _AboutCard(
            icon: Icons.eco,
            title: t('appTitle'),
            body: t('appInfo'),
          ),
          const SizedBox(height: 10),
          _AboutCard(
            icon: Icons.memory,
            title: t('model'),
            body: t('modelInfo'),
          ),
          
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.text,
    this.topPadding = 0,
  });

  final IconData icon;
  final String text;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, topPadding, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: pal.accent.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
    Text(
            text.toUpperCase(),
            style: TextStyle(
              color: pal.accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// The three language rows inside one rounded card. The selected row gets a
/// darker fill + green ring like the reference mockup. Uses custom radio
/// dots for full styling control.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _options = <(String, String)>[
    ('en', 'English'),
    ('ml', '\u0D2E\u0D32\u0D2F\u0D3E\u0D33\u0D02 (Malayalam)'),
    ('hi', '\u0939\u093F\u0928\u094D\u0926\u0940 (Hindi)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: botanicalCard(context.pal),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            _LanguageRow(
              code: _options[i].$1,
              label: _options[i].$2,
              selected: selected == _options[i].$1,
              highlight: selected == _options[i].$1,
              onTap: () => onChanged(_options[i].$1),
            ),
            if (i != _options.length - 1)
              Container(height: 1, color: context.pal.cardBorder),
          ],
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.code,
    required this.label,
    required this.selected,
    required this.highlight,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          // Inset so the highlight forms a rounded bar inside the card
          // (matches the reference mockup, no square corners on the card).
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: highlight
                  ? pal.accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              border: Border.all(
                color: highlight
                    ? pal.accent.withValues(alpha: 0.55)
                    : Colors.transparent,
                width: 1.4,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _RadioDot(selected: selected),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: pal.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? pal.accent : pal.ringIdle,
          width: 2,
        ),
        color: Colors.transparent,
      ),
      child: selected
          ? Center(
              child: Icon(Icons.circle, size: 10, color: pal.accent),
            )
          : null,
    );
  }
}

/// Dark Mode toggle card: moon chip, label, trailing switch.
class _DarkModeCard extends StatelessWidget {
  const _DarkModeCard({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: botanicalCard(context.pal),
      child: Row(
        children: [
          BotanicalIconChip(icon: Icons.dark_mode, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.pal.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// About tile: icon chip, bold title, secondary body copy.
class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: botanicalCard(pal),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BotanicalIconChip(icon: icon, size: 42, iconSize: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: pal.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: pal.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
