import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/batch.dart';
import '../domain/food_photo.dart';
import '../domain/guidance/find_guidance_rule.dart';
import '../domain/guidance/guidance_selection.dart';
import '../domain/recent_stock_action.dart';
import '../domain/stock_event.dart';
import '../domain/inventory_report.dart';
import '../domain/reminder.dart';

/// Explicit SQL for the initial schema, with versioned migrations.
class InventoryDatabase extends GeneratedDatabase {
  final _changes = StreamController<void>.broadcast();
  Stream<void> get inventoryChanges => _changes.stream;
  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await super.close();
  }

  InventoryDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'freshkeep',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );
  @override
  int get schemaVersion => 7;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''
    CREATE TABLE batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),
      starting_qty INTEGER NOT NULL CHECK(starting_qty BETWEEN 1 AND 1000000000),
      unit TEXT NOT NULL CHECK(unit IN ('pieces', 'g', 'mL')),
      storage TEXT NOT NULL CHECK(storage IN ('Pantry', 'Fridge', 'Freezer')),
      printed_date TEXT,
      date_source TEXT NOT NULL CHECK(date_source IN ('printed', 'unknown')),
      printed_time TEXT,
      guidance_rule_id TEXT,
      guidance_catalog_version TEXT,
      guidance_anchor_event TEXT,
      guidance_anchor_date TEXT,
      suggested_date TEXT,
      created_at TEXT NOT NULL
    )
  ''');
      await _createEvents();
      await _createReminderSettings();
      await _createBatchEdits();
      await _createBatchPhotos();
    },
    onUpgrade: (_, from, to) async {
      await transaction(() async {
        if (from < 2) await _createEvents();
        if (from < 3) await _createReminderSettings();
        if (from < 4) await _createBatchEdits();
        if (from < 5) {
          await _createBatchPhotos();
          if (from >= 4) {
            await customStatement(
              'ALTER TABLE batch_edits ADD COLUMN photo_change TEXT',
            );
          }
        }
        if (from < 6) {
          await customStatement(
            'ALTER TABLE batches ADD COLUMN printed_time TEXT',
          );
        }
        if (from < 7) {
          await customStatement(
            'ALTER TABLE batches ADD COLUMN guidance_rule_id TEXT',
          );
          await customStatement(
            'ALTER TABLE batches ADD COLUMN guidance_catalog_version TEXT',
          );
          await customStatement(
            'ALTER TABLE batches ADD COLUMN guidance_anchor_event TEXT',
          );
          await customStatement(
            'ALTER TABLE batches ADD COLUMN guidance_anchor_date TEXT',
          );
          await customStatement(
            'ALTER TABLE batches ADD COLUMN suggested_date TEXT',
          );
          if (from >= 4) {
            await customStatement(
              'ALTER TABLE batch_edits ADD COLUMN guidance_change TEXT',
            );
          }
        }
      });
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> _createBatchPhotos() =>
      customStatement('''CREATE TABLE batch_photos (
    batch_id INTEGER PRIMARY KEY REFERENCES batches(id),
    bytes BLOB NOT NULL CHECK(length(bytes) BETWEEN 1 AND 5242880))''');

  Future<void> _writePhoto(int id, FoodPhoto? photo) async {
    if (photo == null) {
      await customStatement('DELETE FROM batch_photos WHERE batch_id=?', [id]);
    } else {
      await customStatement(
        'INSERT OR REPLACE INTO batch_photos(batch_id,bytes) VALUES(?,?)',
        [id, photo.bytes],
      );
    }
  }

  Future<void> _createBatchEdits() async {
    await customStatement(
      '''CREATE TABLE batch_edits (
      id INTEGER PRIMARY KEY AUTOINCREMENT, batch_id INTEGER NOT NULL REFERENCES batches(id),
      old_name TEXT NOT NULL, new_name TEXT NOT NULL, old_storage TEXT NOT NULL, new_storage TEXT NOT NULL,
      old_date TEXT, new_date TEXT, created_at TEXT NOT NULL, photo_change TEXT, guidance_change TEXT)''',
    );
    await customStatement(
      'CREATE INDEX batch_edits_batch ON batch_edits(batch_id)',
    );
    await customStatement(
      "CREATE TRIGGER batch_edits_no_update BEFORE UPDATE ON batch_edits BEGIN SELECT RAISE(ABORT,'Details history is append-only'); END",
    );
    await customStatement(
      "CREATE TRIGGER batch_edits_no_delete BEFORE DELETE ON batch_edits BEGIN SELECT RAISE(ABORT,'Details history is append-only'); END",
    );
  }

  Future<void> editBatchDetails(
    int id,
    BatchDetailsDraft details, {
    required BatchDraft expected,
    bool updatePhoto = false,
    FoodPhoto? photo,
    bool updateGuidance = false,
    BatchGuidance? guidance,
  }) => transaction(() async {
    final current = (await loadBatch(id)).draft;
    if (current.name != expected.name ||
        current.storage != expected.storage ||
        current.printedDate != expected.printedDate ||
        current.printedTime != expected.printedTime) {
      throw const StockValidationException(
        'Batch details changed while this form was open. Close it and try again.',
      );
    }
    final samePhoto = current.photo == null
        ? expected.photo == null
        : current.photo!.sameAs(expected.photo);
    if (updatePhoto && !samePhoto) {
      throw const StockValidationException(
        'The photo changed while this form was open. Close it and try again.',
      );
    }
    final sameGuidance = current.guidance == null
        ? expected.guidance == null
        : current.guidance!.sameAs(expected.guidance);
    if (updateGuidance && !sameGuidance) {
      throw const StockValidationException(
        'Storage guidance changed while this form was open. Close it and try again.',
      );
    }
    final effectiveGuidance = updateGuidance ? guidance : current.guidance;
    if (effectiveGuidance != null) {
      final rule = findGuidanceRule(effectiveGuidance.ruleId);
      if (rule != null && rule.storage != details.storage) {
        throw StockValidationException(
          'Saved storage guidance does not match ${details.storage}. Clear or update guidance first.',
        );
      }
    }
    final changedPhoto =
        updatePhoto &&
        !(current.photo == null ? photo == null : current.photo!.sameAs(photo));
    final changedGuidance =
        updateGuidance &&
        !(current.guidance == null
            ? guidance == null
            : current.guidance!.sameAs(guidance));
    if (details.matches(current) && !changedPhoto && !changedGuidance) return;
    final photoChange = !changedPhoto
        ? null
        : photo == null
        ? 'Photo removed'
        : current.photo == null
        ? 'Photo added'
        : 'Photo changed';
    final guidanceChange = !changedGuidance
        ? null
        : guidance == null
        ? 'Guidance cleared'
        : current.guidance == null
        ? 'Guidance applied: ${findGuidanceRule(guidance.ruleId)?.food ?? guidance.ruleId} (suggested ${guidance.suggestedDate})'
        : 'Guidance updated: ${findGuidanceRule(guidance.ruleId)?.food ?? guidance.ruleId} (suggested ${guidance.suggestedDate})';
    if (changedPhoto) await _writePhoto(id, photo);
    await customStatement(
      '''UPDATE batches SET name=?,storage=?,printed_date=?,date_source=?,printed_time=?,
        guidance_rule_id=?,guidance_catalog_version=?,guidance_anchor_event=?,guidance_anchor_date=?,suggested_date=? WHERE id=?''',
      [
        details.name,
        details.storage,
        details.printedDate,
        details.printedDate == null ? 'unknown' : 'printed',
        details.printedTime,
        effectiveGuidance?.ruleId,
        effectiveGuidance?.catalogVersion,
        effectiveGuidance?.anchorEvent,
        effectiveGuidance?.anchorDate,
        effectiveGuidance?.suggestedDate,
        id,
      ],
    );
    await customStatement(
      '''INSERT INTO batch_edits(batch_id,old_name,new_name,old_storage,new_storage,old_date,new_date,created_at,photo_change,guidance_change)
      VALUES(?,?,?,?,?,?,?,?,?,?)''',
      [
        id,
        current.name,
        details.name,
        current.storage,
        details.storage,
        current.printedDate,
        details.printedDate,
        DateTime.now().toUtc().toIso8601String(),
        photoChange,
        guidanceChange,
      ],
    );
  }).then((_) => _changed());

  Future<List<BatchEdit>> loadDetailsHistory(int batchId) async {
    final rows = await customSelect(
      'SELECT * FROM batch_edits WHERE batch_id=? ORDER BY id DESC',
      variables: [Variable.withInt(batchId)],
    ).get();
    return rows
        .map(
          (row) => BatchEdit(
            id: row.read<int>('id'),
            photoChange: row.readNullable<String>('photo_change'),
            guidanceChange: row.readNullable<String>('guidance_change'),
            before: BatchDetailsDraft(
              name: row.read<String>('old_name'),
              storage: row.read<String>('old_storage'),
              printedDate: row.readNullable<String>('old_date'),
              printedTime: null, // audit table stores date only; time not separately audited
            ),
            after: BatchDetailsDraft(
              name: row.read<String>('new_name'),
              storage: row.read<String>('new_storage'),
              printedDate: row.readNullable<String>('new_date'),
              printedTime: null, // audit table stores date only; time not separately audited
            ),
            createdAt: DateTime.parse(row.read<String>('created_at')),
          ),
        )
        .toList();
  }

  Future<void> _createReminderSettings() =>
      customStatement('''CREATE TABLE reminder_settings (
    id INTEGER PRIMARY KEY CHECK(id=1), enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
    hour INTEGER NOT NULL CHECK(hour BETWEEN 0 AND 23), minute INTEGER NOT NULL CHECK(minute BETWEEN 0 AND 59),
    lead_days INTEGER NOT NULL CHECK(lead_days IN (1,3)))''');

  Future<ReminderSettings> loadReminderSettings() async {
    final rows = await customSelect(
      'SELECT * FROM reminder_settings WHERE id=1',
    ).get();
    if (rows.isEmpty) return ReminderSettings();
    final row = rows.single;
    return ReminderSettings(
      enabled: row.read<int>('enabled') == 1,
      hour: row.read<int>('hour'),
      minute: row.read<int>('minute'),
      leadDays: row.read<int>('lead_days'),
    );
  }

  Future<void> saveReminderSettings(ReminderSettings settings) =>
      customStatement(
        '''
    INSERT INTO reminder_settings(id,enabled,hour,minute,lead_days) VALUES(1,?,?,?,?)
    ON CONFLICT(id) DO UPDATE SET enabled=excluded.enabled,hour=excluded.hour,minute=excluded.minute,lead_days=excluded.lead_days
  ''',
        [
          settings.enabled ? 1 : 0,
          settings.hour,
          settings.minute,
          settings.leadDays,
        ],
      );

  Future<void> _createEvents() async {
    await customStatement('''CREATE TABLE events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      batch_id INTEGER NOT NULL REFERENCES batches(id),
      type TEXT NOT NULL CHECK(type IN ('consume','dispose','correct','reverse')),
      delta INTEGER NOT NULL CHECK(delta != 0),
      reason TEXT,
      created_at TEXT NOT NULL,
      reverses_id INTEGER UNIQUE REFERENCES events(id),
      CHECK((type = 'reverse' AND reverses_id IS NOT NULL) OR
            (type != 'reverse' AND reverses_id IS NULL)),
      CHECK(type NOT IN ('consume','dispose') OR delta < 0)
    )''');
    await customStatement('CREATE INDEX events_batch ON events(batch_id)');
    await customStatement(
      "CREATE TRIGGER events_no_update BEFORE UPDATE ON events BEGIN SELECT RAISE(ABORT, 'Events are append-only'); END",
    );
    await customStatement(
      "CREATE TRIGGER events_no_delete BEFORE DELETE ON events BEGIN SELECT RAISE(ABORT, 'Events are append-only'); END",
    );
  }

  static const _inventoryQuery = '''SELECT b.*,p.bytes AS photo_bytes,
    b.starting_qty + COALESCE((SELECT SUM(e.delta) FROM events e WHERE e.batch_id = b.id),0) AS remaining
    FROM batches b LEFT JOIN batch_photos p ON p.batch_id=b.id''';
  Future<List<InventoryBatch>> loadBatches() async {
    final rows = await customSelect('$_inventoryQuery ORDER BY b.id DESC')
        .get();
    return rows.map((row) {
      final ruleId = row.readNullable<String>('guidance_rule_id');
      final anchorDate = row.readNullable<String>('guidance_anchor_date');
      final suggestedDate = row.readNullable<String>('suggested_date');
      final guidance =
          ruleId != null && anchorDate != null && suggestedDate != null
          ? BatchGuidance.stored(
              ruleId: ruleId,
              catalogVersion:
                  row.readNullable<String>('guidance_catalog_version') ??
                  'unknown',
              anchorEvent:
                  row.readNullable<String>('guidance_anchor_event') ?? 'Stored',
              anchorDate: anchorDate,
              suggestedDate: suggestedDate,
            )
          : null;
      return InventoryBatch(
        id: row.read<int>('id'),
        remaining: row.read<int>('remaining'),
        draft: BatchDraft(
          name: row.read<String>('name'),
          quantity: row.read<int>('starting_qty'),
          unit: row.read<String>('unit'),
          storage: row.read<String>('storage'),
          printedDate: row.readNullable<String>('printed_date'),
          printedTime: row.readNullable<String>('printed_time'),
          guidance: guidance,
          photo: row.readNullable<Uint8List>('photo_bytes') == null
              ? null
              : FoodPhoto(row.read<Uint8List>('photo_bytes')),
        ),
      );
    }).toList();
  }

  Future<InventoryBatch> loadBatch(int id) async =>
      (await loadBatches()).firstWhere((batch) => batch.id == id);

  Future<int> recordAction(
    int batchId,
    StockAction action,
    int quantity, {
    String? reason,
    int? expectedRemaining,
  }) =>
      transaction(() async {
        final batch = await loadBatch(batchId);
        if (expectedRemaining != null && batch.remaining != expectedRemaining) {
          throw const StockValidationException(
            'Stock changed while this form was open. Close it and try again.',
          );
        }
        final delta = stockDelta(action, quantity, batch.remaining);
        final note = reason?.trim();
        if (note != null && note.length > 200) {
          throw const StockValidationException(
            'Keep the reason under 200 characters.',
          );
        }
        await customStatement(
          '''INSERT INTO events
      (batch_id,type,delta,reason,created_at) VALUES (?,?,?,?,?)''',
          [
            batchId,
            action.name,
            delta,
            action == StockAction.dispose && (note == null || note.isEmpty)
                ? 'Unspecified'
                : (note == null || note.isEmpty ? null : note),
            DateTime.now().toUtc().toIso8601String(),
          ],
        );
        return (await customSelect(
          'SELECT last_insert_rowid() AS id',
        ).getSingle()).read<int>('id');
      }).then((id) {
        _changed();
        return id;
      });

  Future<List<StockEvent>> loadHistory(int batchId) async {
    final rows = await customSelect(
      '''SELECT e.*,
      EXISTS(SELECT 1 FROM events r WHERE r.reverses_id=e.id) AS reversed
      FROM events e WHERE batch_id=? ORDER BY id DESC''',
      variables: [Variable.withInt(batchId)],
    ).get();
    return rows
        .map(
          (r) => StockEvent(
            id: r.read<int>('id'),
            type: r.read<String>('type'),
            delta: r.read<int>('delta'),
            reason: r.readNullable<String>('reason'),
            createdAt: DateTime.parse(r.read<String>('created_at')),
            reversed: r.read<int>('reversed') != 0,
          ),
        )
        .toList();
  }

  /// Reverse a mistaken entry without deleting history or counting it as new waste.
  Future<void> undoEvent(int batchId, int eventId) => transaction(() async {
    final batch = await loadBatch(batchId);
    final event = (await loadHistory(batchId))
        .firstWhere((e) => e.id == eventId);
    if (event.reversed || event.type == 'reverse') {
      throw const StockValidationException(
        'This entry cannot be undone again.',
      );
    }
    final restored = batch.remaining - event.delta;
    if (restored < 0 || restored > 1000000000) {
      throw const StockValidationException(
        'Undo would put stock outside the allowed range. Correct the stock first.',
      );
    }
    await customStatement(
      '''INSERT INTO events
      (batch_id,type,delta,reason,created_at,reverses_id) VALUES (?,'reverse',?,?,?,?)''',
      [
        batchId,
        -event.delta,
        'Undo entry #${event.id}',
        DateTime.now().toUtc().toIso8601String(),
        event.id,
      ],
    );
  }).then((_) => _changed());

  Future<int> disposedQuantity(int batchId) async {
    final row = await customSelect(
      '''SELECT COALESCE(-SUM(e.delta),0) AS qty
      FROM events e WHERE batch_id=? AND type='dispose'
      AND NOT EXISTS(SELECT 1 FROM events r WHERE r.reverses_id=e.id)''',
      variables: [Variable.withInt(batchId)],
    ).getSingle();
    return row.read<int>('qty');
  }

  Future<void> addBatch(BatchDraft draft) =>
      transaction(() => _insertBatch(draft)).then((_) => _changed());

  Future<void> _insertBatch(BatchDraft draft) async {
    await customStatement(
      '''
      INSERT INTO batches (name, starting_qty, unit, storage, printed_date,
        date_source, printed_time, guidance_rule_id, guidance_catalog_version,
        guidance_anchor_event, guidance_anchor_date, suggested_date, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        draft.name,
        draft.quantity,
        draft.unit,
        draft.storage,
        draft.printedDate,
        draft.printedDate == null ? 'unknown' : 'printed',
        draft.printedTime,
        draft.guidance?.ruleId,
        draft.guidance?.catalogVersion,
        draft.guidance?.anchorEvent,
        draft.guidance?.anchorDate,
        draft.guidance?.suggestedDate,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    if (draft.photo != null) {
      final id = (await customSelect(
        'SELECT last_insert_rowid() AS id',
      ).getSingle()).read<int>('id');
      await _writePhoto(id, draft.photo);
    }
  }

  Future<void> addBatches(List<BatchDraft> drafts) {
    // Snapshot the reviewed rows before awaiting any database work.
    final reviewed = List<BatchDraft>.of(drafts);
    if (reviewed.isEmpty) throw ArgumentError('Add at least one grocery row.');
    return transaction(() async {
      for (final draft in reviewed) {
        await _insertBatch(draft);
      }
    }).then((_) => _changed());
  }

  Future<List<String>> previousFoodNames() async {
    final rows = await customSelect('SELECT name FROM batches ORDER BY id DESC')
        .get();
    final seen = <String>{};
    return [
      for (final row in rows)
        if (seen.add(row.read<String>('name').trim().toLowerCase()))
          row.read<String>('name').trim(),
    ];
  }

  /// Read both sides of the report from one consistent database snapshot.
  Future<InventoryReport> loadReport() => transaction(() async {
    final batches = await loadBatches();
    final rows = await customSelect('''SELECT e.id, e.batch_id, b.name, b.unit,
      -e.delta AS quantity, e.reason, e.created_at
      FROM events e JOIN batches b ON b.id=e.batch_id
      WHERE e.type='dispose' AND NOT EXISTS
        (SELECT 1 FROM events r WHERE r.reverses_id=e.id)
      ORDER BY e.created_at DESC, e.id DESC''').get();
    return InventoryReport(
      batches: batches,
      disposals: rows
          .map(
            (row) => WasteEntry(
              id: row.read<int>('id'),
              batchId: row.read<int>('batch_id'),
              food: row.read<String>('name'),
              unit: row.read<String>('unit'),
              quantity: row.read<int>('quantity'),
              reason: row.readNullable<String>('reason') ?? 'Unspecified',
              createdAt: DateTime.parse(row.read<String>('created_at')),
            ),
          )
          .toList(),
    );
  });

  /// Returns newest-first unreversed stock actions across all batches so the
  /// user can undo mistaken entries even after a quick toast disappears.
  Future<List<RecentStockAction>> loadRecentUndoableEvents({
    int limit = 20,
  }) async {
    final rows = await customSelect(
      '''SELECT e.id, e.batch_id, b.name, b.unit, e.type, e.delta, e.reason, e.created_at
      FROM events e
      JOIN batches b ON b.id = e.batch_id
      WHERE e.type != 'reverse'
        AND NOT EXISTS (SELECT 1 FROM events r WHERE r.reverses_id = e.id)
      ORDER BY e.id DESC
      LIMIT ?''',
      variables: [Variable.withInt(limit)],
    ).get();
    return rows
        .map(
          (row) => RecentStockAction(
            eventId: row.read<int>('id'),
            batchId: row.read<int>('batch_id'),
            food: row.read<String>('name'),
            unit: row.read<String>('unit'),
            type: row.read<String>('type'),
            delta: row.read<int>('delta'),
            reason: row.readNullable<String>('reason'),
            createdAt: DateTime.parse(row.read<String>('created_at')),
          ),
        )
        .toList();
  }
}
