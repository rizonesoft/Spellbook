---
name: add-migration
description: Write and apply a database schema change safely -- a new migrations/NNNN_name.sql, a test on a database from the previous version, and the docs. Use whenever a table, column, index, trigger, or FTS definition must change.
---

# Add a Migration

The database holds the user's prompts. A wrong migration does not fail a test, it damages a library that cannot be recreated. So migrations are append-only, transactional, and tested on real old data.

## The rules

1. **A shipped migration is never edited.** `migrations/0001_init.sql` is frozen. A change is a new file, even to fix a typo in a comment.
2. **Name:** `migrations/NNNN_lower_snake.sql`, the next number with no gap. `cmake/EmbedMigrations.cmake` fails the build on a gap or a bad name.
3. **No transaction statements in the file.** `src/storage/src/migrator.cpp` wraps each file in `BEGIN IMMEDIATE ... COMMIT` and sets `PRAGMA user_version` to NNNN inside the same transaction. A `BEGIN` or `COMMIT` in the file breaks that guarantee.
4. **Additive where possible:** add tables, columns (`ALTER TABLE ... ADD COLUMN`, nullable or with a default), and indexes. SQLite can drop a column but cannot change its type or constraints in place; for a reshape, create the new table, copy the rows, drop the old one, and rename, all in the one file, then recreate the indexes and triggers that referenced it.
5. **FTS5 and triggers:** changing `prompts_fts` means dropping and recreating the virtual table and its three triggers, then `INSERT INTO prompts_fts(prompts_fts) VALUES ('rebuild')`.
6. **Foreign keys** are on for every connection (`PRAGMA foreign_keys = ON`), and SQLite ignores a change to that pragma inside a transaction. Reshaping a table that other tables reference needs foreign keys off for the copy (the procedure on sqlite.org, "Making Other Kinds Of Table Schema Changes"), so that section first extends `migrator.cpp` with a per-migration flag that turns them off around the transaction and runs `PRAGMA foreign_key_check` before committing.
7. **Downgrades are refused, never written.** An older Spellbook refuses a newer database; there are no down migrations.

## Steps

1. Write `migrations/NNNN_name.sql` with a header comment: what changes, why, and the TODO section.
2. Create the previous-version fixture if none exists: `tests/fixtures/db/vNNNN-1.db`, made by `pwsh scripts/migrate.ps1 -Reset` on the commit before your change and seeded with representative rows (non-ASCII text, nested folders, tags, revisions). Record how in `tests/fixtures/db/README.md`.
3. Add tests in `tests/storage/migrator_tests.cpp` or a new `tests/storage/migration_NNNN_tests.cpp`:
   - a new database reaches version NNNN (`latest_schema_version()` moves on its own);
   - the fixture upgrades with every row intact and the new structure present;
   - the FTS index still finds the fixture's prompts after the upgrade.
4. Update `src/core/include/spellbook/core/domain.hpp` if a domain field changed, and `docs/architecture.md` (the schema section).
5. Apply it to a dev database and read it back:

   ```powershell
   pwsh scripts/migrate.ps1 -Reset      # every migration from version 0
   pwsh scripts/migrate.ps1             # upgrade the existing dev database
   ```

6. Run `pwsh scripts/test.ps1 -Filter "storage:"`, then `pwsh scripts/check-all.ps1`.
7. Add a `CHANGELOG.md` line if users notice (a new capability; never "schema changed").

## Freeze check (owed by every migration section)

`storage: a failing step rolls back and leaves the last complete version` already proves the runner. The section adds its own: the fixture database upgraded with one statement forced to fail stays at the previous version with every row intact.

## The first planned migration

`migrations/0002_import_batches.sql` in `D02 T01 §3` is the first use of this skill.
