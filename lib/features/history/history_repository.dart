import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'scan_record.dart';

/// Local scan history (PRD Phase 6): SQLite table with id, image path,
/// label, confidence, timestamp. History persists across app restarts.
class HistoryRepository {
  static const _dbName = 'pepper_scans.db';
  static const _tableName = 'scans';

  Database? _db;

  Future<Database> _getDatabase() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            imagePath TEXT NOT NULL,
            label TEXT NOT NULL,
            confidence REAL NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> addScan({
    required String imagePath,
    required String label,
    required double confidence,
  }) async {
    try {
      final db = await _getDatabase();
      await db.insert(_tableName, ScanRecord(
        imagePath: imagePath,
        label: label,
        confidence: confidence,
        timestamp: DateTime.now(),
      ).toMap());
    } catch (_) {
      // History saving is best effort; never break the scan flow over it.
    }
  }

  Future<List<ScanRecord>> listScans() async {
    try {
      final db = await _getDatabase();
      final rows = await db.query(_tableName, orderBy: 'timestamp DESC');
      return rows.map(ScanRecord.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteScan(int id) async {
    try {
      final db = await _getDatabase();
      await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      final db = await _getDatabase();
      await db.delete(_tableName);
    } catch (_) {}
  }
}

final historyRepositoryProvider =
    Provider<HistoryRepository>((ref) => HistoryRepository());
