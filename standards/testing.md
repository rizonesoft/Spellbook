# Testing Standards

How Spellbook proves its work. The proofs a TODO checkpoint may cite are defined in [`todo/README.md`](../todo/README.md).

## Test executables

- Catch2 v3 (`Catch2::Catch2WithMain`), one executable per production library: `spellbook_core_tests` (`tests/core/`) and `spellbook_storage_tests` (`tests/storage/`). `catch_discover_tests` registers each `TEST_CASE` with CTest under the prefix `core: ` or `storage: `.
- Run through `pwsh scripts/test.ps1` (`-Filter` is a CTest regex over those names). CI runs Debug and Release.
- Core tests link core only; `check-layering.py` fails a core test that includes a storage header.
- **Every public core function has a unit test.** A bug fix has a test that failed before the fix.

## Naming and shape

- Test files are `<unit>_tests.cpp`. A `TEST_CASE` name is a sentence stating the behavior: `"migrate refuses a database newer than this build"`. Tags name the unit: `[migrations]`.
- One behavior per case, arrange, act, assert. A case that asserts only "no exception" is not a test.
- No shared mutable state between cases.

## User data in tests

- **Nothing writes under the real `%LOCALAPPDATA%\Spellbook`.** Storage tests use `:memory:` or a fresh folder under the system temp directory (the `TempDir` helper in `tests/storage/database_tests.cpp`), removed afterwards. Driven runs use `--data-dir` (`scripts/run.ps1 -Smoke` defaults to `build/smoke/`; `scripts/migrate.ps1` to `build/dev-data/`).
- Paths in tests include non-ASCII characters where a path is involved, because user names do.

## Fixtures and round trips

- Fixtures live under `tests/fixtures/<area>/`, small and committed, with a `README.md` saying how each was produced.
- Every importer and exporter owes a round trip: the fixture goes in, the result is compared with the expected text or document byte for byte or field by field. "It did not throw" is not a round trip.
- Migrations are tested on a fixture database from the previous schema version, with its rows checked after the upgrade.

## Failure paths

Every write path is tested on its failure: a failing statement mid-transaction, a read-only database, a corrupt file, a missing folder. The test asserts the message and that nothing was damaged.

## Surfaces

Until a UI automation harness exists, a surface is proven by a driven run: build, launch with `--data-dir`, drive the surface, quote the log, read the database back, and commit captures under `docs/captures/<area>/`. The launch smoke (`pwsh scripts/run.ps1 -Smoke`) runs in check-all and CI on every change.

## Coverage

Coverage is not gated by a percentage. A section that adds logic adds the tests that pin it, and review refuses logic without them.
