import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../disease_info/disease_info_model.dart';
import '../disease_info/disease_info_repository.dart';
import 'history_repository.dart';
import 'scan_record.dart';

/// Full view of one past scan (PRD FR-9 detail): the saved photo, the label +
/// confidence recorded at scan time, the static guidance for that disease and
/// a delete action. Reached by tapping an entry on the history list.
class ScanDetailScreen extends ConsumerStatefulWidget {
  final ScanRecord record;

  const ScanDetailScreen({super.key, required this.record});

  @override
  ConsumerState<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends ConsumerState<ScanDetailScreen> {
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this scan?'),
        content: const Text(
            'This entry will be removed from your scan history. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      if (widget.record.id != null) {
        await ref.read(historyRepositoryProvider).deleteScan(widget.record.id!);
      }
      if (mounted) context.go('/history');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.record;
    final pct = (record.confidence * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Detail'),
        actions: [
          IconButton(
            tooltip: 'Delete scan',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: FutureBuilder<DiseaseInfo>(
        future:
            ref.read(diseaseInfoRepositoryProvider).getByLabel(record.label),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final info = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The photo saved with this scan. If the temporary file was
                // cleaned up by the OS since, show a placeholder instead of
                // crashing (history must stay robust).
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: File(record.imagePath).existsSync()
                      ? Image.file(File(record.imagePath),
                          height: 220, fit: BoxFit.cover)
                      : Container(
                          height: 220,
                          color:
                              theme.colorScheme.surfaceContainerHighest,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported, size: 48),
                              SizedBox(height: 8),
                              Text('Original photo no longer available'),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                Text(info?.displayName ?? _prettyLabel(record.label),
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: record.confidence.clamp(0.0, 1.0),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$pct%', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Scanned on ${_formatDate(record.timestamp)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (info != null) ...[
                  const SizedBox(height: 16),
                  Text(info.description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
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
                ],
                const SizedBox(height: 8),
                Text(
                  'This guidance is indicative only. For serious cases, please '
                  'consult your local agriculture officer.',
                  style:
                      theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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

  static String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Expandable info section, same style as the result screen.
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
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [Align(alignment: Alignment.centerLeft, child: Text(body))],
      ),
    );
  }
}
