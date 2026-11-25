import 'inventory_database.dart';

/// Migrates existing v1–v8 SQLite tables to schema v9 inside an active
/// transaction (with `PRAGMA foreign_keys = OFF` set prior to the transaction):
/// - Adds `category` to `batches` (default `'Other'`) and widens `starting_qty`
///   to `REAL` (`> 0` up to `1,000,000,000`) for decimal measured units.
/// - Widens `events.delta` to `REAL` while preserving all append-only triggers
///   and indexes.
/// - Adds `old_category` and `new_category` to `batch_edits` when upgrading
///   from v4–v8.
Future<void> migrateToV9CategoriesAndDecimals(
  InventoryDatabase db, {
  required int from,
}) async {
  await db.customStatement('''
    CREATE TABLE batches_v9 (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),
      starting_qty REAL NOT NULL CHECK(starting_qty > 0 AND starting_qty <= 1000000000),
      unit TEXT NOT NULL CHECK(unit IN ('pieces', 'g', 'mL')),
      storage TEXT NOT NULL CHECK(storage IN ('Pantry', 'Fridge', 'Freezer')),
      category TEXT NOT NULL DEFAULT 'Other',
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
  await db.customStatement('''
    INSERT INTO batches_v9 (
      id, name, starting_qty, unit, storage, category, printed_date,
      date_source, printed_time, guidance_rule_id, guidance_catalog_version,
      guidance_anchor_event, guidance_anchor_date, suggested_date, created_at
    )
    SELECT
      id, name, starting_qty, unit, storage, 'Other', printed_date,
      date_source, printed_time, guidance_rule_id, guidance_catalog_version,
      guidance_anchor_event, guidance_anchor_date, suggested_date, created_at
    FROM batches
  ''');
  await db.customStatement('DROP TABLE batches');
  await db.customStatement('ALTER TABLE batches_v9 RENAME TO batches');

  await db.customStatement('DROP TRIGGER IF EXISTS events_no_update');
  await db.customStatement('DROP TRIGGER IF EXISTS events_no_delete');
  await db.customStatement('''
    CREATE TABLE events_v9 (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      batch_id INTEGER NOT NULL REFERENCES batches(id),
      type TEXT NOT NULL CHECK(type IN ('consume','dispose','correct','reverse')),
      delta REAL NOT NULL CHECK(delta != 0),
      reason TEXT,
      created_at TEXT NOT NULL,
      reverses_id INTEGER UNIQUE REFERENCES events_v9(id),
      CHECK((type = 'reverse' AND reverses_id IS NOT NULL) OR
            (type != 'reverse' AND reverses_id IS NULL)),
      CHECK(type NOT IN ('consume','dispose') OR delta < 0)
    )
  ''');
  await db.customStatement('''
    INSERT INTO events_v9 (id, batch_id, type, delta, reason, created_at, reverses_id)
    SELECT id, batch_id, type, delta, reason, created_at, reverses_id FROM events
  ''');
  await db.customStatement('DROP TABLE events');
  await db.customStatement('ALTER TABLE events_v9 RENAME TO events');
  await db.customStatement('CREATE INDEX events_batch ON events(batch_id)');
  await db.customStatement(
    "CREATE TRIGGER events_no_update BEFORE UPDATE ON events BEGIN SELECT RAISE(ABORT, 'Events are append-only'); END",
  );
  await db.customStatement(
    "CREATE TRIGGER events_no_delete BEFORE DELETE ON events BEGIN SELECT RAISE(ABORT, 'Events are append-only'); END",
  );

  if (from >= 4) {
    final editColumns = await db
        .customSelect('PRAGMA table_info(batch_edits)')
        .get();
    final names = editColumns.map((row) => row.read<String>('name')).toSet();
    if (!names.contains('old_category')) {
      await db.customStatement(
        "ALTER TABLE batch_edits ADD COLUMN old_category TEXT NOT NULL DEFAULT 'Other'",
      );
    }
    if (!names.contains('new_category')) {
      await db.customStatement(
        "ALTER TABLE batch_edits ADD COLUMN new_category TEXT NOT NULL DEFAULT 'Other'",
      );
    }
  }
}
