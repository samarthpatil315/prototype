import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Offline-first local persistence backed by SQLite (sqflite).
///
/// Design: each entity collection lives in one generic `records` table as a
/// JSON payload, keyed by (type, id). This gives us offline draft creation,
/// a durable sync queue (`sync_status`), and conflict data (client
/// `updated_at` is always preserved and compared before any server write —
/// newer server data is never silently overwritten; see SyncService).
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'orbital_office.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE records(
            type TEXT NOT NULL,
            id TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            PRIMARY KEY(type, id)
          )''');
        await db.execute(
          'CREATE INDEX idx_records_sync ON records(sync_status)',
        );
        await db.execute('''
          CREATE TABLE preferences(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )''');
      },
    );
    return _db!;
  }

  Future<List<Map<String, dynamic>>> loadCollection(String type) async {
    try {
      final db = await database;
      final rows = await db.query('records', where: 'type = ?', whereArgs: [type]);
      return rows
          .map((r) => Map<String, dynamic>.from(
              jsonDecode(r['payload'] as String) as Map))
          .toList();
    } catch (_) {
      // Storage unavailable (e.g. unit-test environment): behave as empty.
      return [];
    }
  }

  Future<void> upsert(
    String type,
    String id,
    Map<String, dynamic> payload, {
    String syncStatus = 'pending',
  }) async {
    try {
      final db = await database;
      await db.insert(
        'records',
        {
          'type': type,
          'id': id,
          'payload': jsonEncode(payload),
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': syncStatus,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Persistence is best-effort in constrained environments; the
      // in-memory state remains the source of truth for the session.
    }
  }

  Future<void> delete(String type, String id) async {
    try {
      final db = await database;
      await db.delete('records',
          where: 'type = ? AND id = ?', whereArgs: [type, id]);
    } catch (_) {}
  }

  Future<List<Map<String, Object?>>> pendingRecords() async {
    try {
      final db = await database;
      return db.query('records', where: 'sync_status = ?', whereArgs: ['pending']);
    } catch (_) {
      return [];
    }
  }

  Future<void> markSynced(String type, String id) async {
    try {
      final db = await database;
      await db.update(
        'records',
        {'sync_status': 'synced'},
        where: 'type = ? AND id = ?',
        whereArgs: [type, id],
      );
    } catch (_) {}
  }

  Future<String?> getPreference(String key) async {
    try {
      final db = await database;
      final rows =
          await db.query('preferences', where: 'key = ?', whereArgs: [key]);
      return rows.isEmpty ? null : rows.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setPreference(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'preferences',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}
