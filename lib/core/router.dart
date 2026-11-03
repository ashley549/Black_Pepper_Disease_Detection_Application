import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
import '../features/history/scan_detail_screen.dart';
import '../features/history/scan_record.dart';
import '../features/result/result_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/home/home_screen.dart';
import '../features/scan/crop_screen.dart';

/// Declarative routes: /, /result, /history, /settings (PRD Phase 1).
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/crop',
      name: 'crop',
      builder: (context, state) {
        final sourcePath = state.extra;
        if (sourcePath is String && FileFromPathHelper.existsSync(sourcePath)) {
          return CropScreen(sourcePath: sourcePath);
        }
        // Bad/lost extra: bounce back home.
        return const HomeScreen();
      },
    ),
    GoRoute(
      path: '/result',
      name: 'result',
      builder: (context, state) => const ResultScreen(),
    ),
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/history/detail',
      name: 'history_detail',
      builder: (context, state) {
        final record = state.extra;
        if (record is ScanRecord) {
          return ScanDetailScreen(record: record);
        }
        // Deep-linked/lost state: bounce back to the list.
        return const HistoryScreen();
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

/// Small helper so screens navigate without importing go_router everywhere.
void goToResult(BuildContext context) => context.pushNamed('result');

/// Tiny existence check used by the /crop route guard.
class FileFromPathHelper {
  static bool existsSync(String path) {
    final f = File(path);
    return f.existsSync();
  }
}