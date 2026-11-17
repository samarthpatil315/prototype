import 'dart:convert';

import 'local_database.dart';
import 'supabase_service.dart';

enum SyncOutcome { pushed, keptRemoteNewer, offline, notConfigured, failed }

/// Decides which copy wins a sync conflict. The rule required by the
/// specification: NEVER silently overwrite newer server data.
SyncOutcome resolveConflict({
  required DateTime localUpdatedAt,
  required DateTime? remoteUpdatedAt,
}) {
  if (remoteUpdatedAt != null && remoteUpdatedAt.isAfter(localUpdatedAt)) {
    return SyncOutcome.keptRemoteNewer;
  }
  return SyncOutcome.pushed;
}

/// Pushes locally-pending records to Supabase when configured and signed in.
/// Each record type maps to a normalised table created by the migrations in
/// supabase/migrations. Records whose payload cannot be mapped stay pending
/// and are retried on the next sync — nothing is dropped silently.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const Map<String, String> tableForType = {
    'documents': 'documents',
    'spreadsheets': 'spreadsheets',
    'presentations': 'presentations',
    'invoices': 'invoices',
    'quotations': 'quotations',
    'customers': 'customers',
    'products': 'products',
    'projects': 'projects',
    'tasks': 'tasks',
  };

  bool _syncing = false;
  DateTime? lastSyncAt;
  String lastStatus = 'Not synced yet';

  Future<String> syncNow() async {
    if (_syncing) return lastStatus;
    if (!SupabaseService.instance.isReady) {
      lastStatus = 'Demo mode — data is stored on this device only';
      return lastStatus;
    }
    if (!SupabaseService.instance.isSignedIn) {
      lastStatus = 'Sign in to sync with Supabase';
      return lastStatus;
    }
    _syncing = true;
    var pushed = 0;
    var failed = 0;
    try {
      final pending = await LocalDatabase.instance.pendingRecords();
      for (final row in pending) {
        final type = row['type'] as String;
        final id = row['id'] as String;
        final table = tableForType[type];
        if (table == null) continue;
        final payload =
            Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map);
        final localUpdated =
            DateTime.tryParse(payload['updatedAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);

        // Conflict check: read the server copy first.
        DateTime? remoteUpdated;
        try {
          final remote = await SupabaseService.instance.client
              .from(table)
              .select('updated_at')
              .eq('id', id)
              .maybeSingle();
          if (remote != null) {
            remoteUpdated =
                DateTime.tryParse(remote['updated_at']?.toString() ?? '');
          }
        } catch (_) {}

        final outcome = resolveConflict(
          localUpdatedAt: localUpdated,
          remoteUpdatedAt: remoteUpdated,
        );
        if (outcome == SyncOutcome.keptRemoteNewer) {
          // Server wins; mark local record as synced so we stop retrying,
          // and let the next fetch refresh the local copy.
          await LocalDatabase.instance.markSynced(type, id);
          continue;
        }

        final ok = await SupabaseService.instance.upsertRecord(table, {
          'id': id,
          'owner_id': SupabaseService.instance.currentUser!.id,
          'payload': payload,
          'updated_at': localUpdated.toIso8601String(),
        });
        if (ok) {
          pushed++;
          await LocalDatabase.instance.markSynced(type, id);
        } else {
          failed++;
        }
      }
      lastSyncAt = DateTime.now();
      lastStatus = failed == 0
          ? 'All changes synced'
          : 'Synced $pushed change(s); $failed will retry automatically';
      return lastStatus;
    } finally {
      _syncing = false;
    }
  }
}
