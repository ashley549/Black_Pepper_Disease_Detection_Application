import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/botanical.dart';
import '../../l10n/app_strings.dart';
import '../settings/settings_screen.dart';
import 'history_repository.dart';
import 'scan_record.dart';

/// Past scans with thumbnail, disease, confidence, date (PRD Phase 6),
/// restyled to the botanical reference: filter chips, accent-striped
/// rounded cards, chevron detail affordance.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<ScanRecord>> _future;
  String _filter = _allKey;

  static const _allKey = '_all';

  @override
  void initState() {
    super.initState();
    _future = ref.read(historyRepositoryProvider).listScans();
  }

  void _reload() {
    setState(() {
      _future = ref.read(historyRepositoryProvider).listScans();
    });
  }

  Future<void> _confirmClearAll() async {
    final lang = ref.watch(languageProvider);
    String t(String key) => AppStrings.of(lang, key);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('clearAllTitle')),
        content: Text(t('clearAllBody')),
        // Per user feedback: Cancel shown as a full-width centred outlined
        // button above the primary action, instead of a corner text button.
        actions: [
          Center(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(t('cancel')),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(t('clear')),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
    if (confirmed == true) {
      await ref.read(historyRepositoryProvider).clearAll();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    String t(String key) => AppStrings.of(lang, key);

    return BotanicalScaffold(
      appBar: AppBar(
        title: Text(
          t('history'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: t('clearAll'),
            icon: const Icon(Icons.delete_sweep),
            onPressed: _confirmClearAll,
          ),
        ],
      ),
      child: FutureBuilder<List<ScanRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final scans = snapshot.data ?? const <ScanRecord>[];
          if (scans.isEmpty) {
            final pal = context.pal;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history,
                      size: 64, color: pal.accent.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text(t('noScans'),
                      style: TextStyle(color: pal.textPrimary)),
                  const SizedBox(height: 4),
                  Text(t('noScansHint'),
                      style: TextStyle(color: pal.textSecondary)),
                ],
              ),
            );
          }

          // Filter chips: All + each distinct label (data-driven, in the
          // order they appear in history).
          final labels = <String>[];
          for (final s in scans) {
            if (!labels.contains(s.label)) labels.add(s.label);
          }
          final visible = _filter == _allKey
              ? scans
              : scans.where((s) => s.label == _filter).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterChip(
                        label: t('all'),
                        selected: _filter == _allKey,
                        onTap: () => setState(() => _filter = _allKey),
                      ),
                      for (final label in labels)
                        _FilterChip(
                          label: _prettyLabel(label),
                          selected: _filter == label,
                          onTap: () => setState(() => _filter = label),
                        ),
                    ].map((w) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: w,
                        )).toList(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final record = visible[index];
                    return Dismissible(
                      key: ValueKey(record.id ?? record.timestamp),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: BotanicalColors.badRed.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        if (record.id != null) {
                          await ref
                              .read(historyRepositoryProvider)
                              .deleteScan(record.id!);
                        }
                        _reload();
                      },
                      child: _ScanCard(
                        record: record,
                        onTap: () async {
                          await context.push('/history/detail', extra: record);
                          // Returning from the detail (possibly after
                          // deleting it) refreshes the list.
                          if (context.mounted) _reload();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _prettyLabel(String label) {
    final spaced = label.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return label;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

/// Rounded scan card: severity accent stripe, thumbnail, name, confidence
/// with verified glyph, date, chevron.
class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.record, required this.onTap});

  final ScanRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    // Single green accent everywhere (user feedback: no red/yellow on the
    // history page).
    final accent = pal.goodGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: pal.cardFill,
            border: Border.all(color: pal.cardBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Severity accent stripe
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: File(record.imagePath).existsSync()
                    ? Image.file(File(record.imagePath), width: 56, height: 56, fit: BoxFit.cover)
                    : Container(
                        width: 56,
                        height: 56,
                        color: pal.cardBorder,
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pretty(record.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pal.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.verified, size: 15, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          '${(record.confidence * 100).toStringAsFixed(1)}% \u2022 '
                          '${_formatDate(record.timestamp)}',
                          style: TextStyle(
                            color: pal.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: pal.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  static String _pretty(String label) {
    final spaced = label.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return label;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Rounded full-width chip like the reference "All / Healthy / ..." row.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? pal.chipSelectedBg : pal.chipFill,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : pal.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? pal.chipSelectedFg : pal.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
