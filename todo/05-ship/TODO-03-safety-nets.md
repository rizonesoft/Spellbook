---
schema_version: 1
id: safety-nets
domain: 05-ship
status: draft
title: "TODO-03 -- Safety Nets: Automatic Backups, Restore, Crash Recovery, and the Update Check"
depends_on: []
frozen: true
---

# TODO-03 -- Safety Nets: Automatic Backups, Restore, Crash Recovery, and the Update Check

> **Goal:** The user's grimoire survives anything: the database is backed up automatically every day and before every migration, any backup can be restored from inside the app; a crash leaves a local dump and a calm explanation on the next start, with a database integrity check; and Spellbook tells the user when a new version is out, through one documented network call that a Privacy page in Settings can turn off.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** Nothing here exists. Operator decisions 2026-10-04 (ADR 0003): automatic backups and crash safety are in v0.1.0; the update check is **on by default** and is the only network call outside the opt-in AI features (`D06 T01`); a **Privacy** page in Settings holds the update-check switch and, later, the AI sharing controls ("should be configurable in a Privacy Settings page"). Backups land in Phase 2, before the operator imports the real library (`D99 T01 §3`). The data folder is `%LOCALAPPDATA%\Spellbook` or, for a portable copy, `Data\` beside the exe (`D05 T02 §6`); everything here writes under it. The update check reads `https://api.github.com/repos/rizonesoft/Spellbook/releases/latest`.

## Inputs

- SQLite: "SQLite Backup API" (`sqlite3_backup_init`, `_step`, `_finish`) and `PRAGMA quick_check`
- Microsoft Learn: `SetUnhandledExceptionFilter`, `MiniDumpWriteDump` (DbgHelp), WinUI `Application.UnhandledException`, WinHTTP (`WinHttpOpen`, `WinHttpSendRequest`)
- GitHub REST API: "Get the latest release" (`tag_name`, `html_url`, `prerelease`, `draft`)
- -> XREF: D99 T01 §3 -- the real import, which backups must precede
- -> XREF: D05 T01 §2 -- the settings store and the Settings dialog the Privacy page joins
- -> XREF: D06 T01 §2 -- the AI controls that join the Privacy page
- -> XREF: D05 T02 §6 -- portable mode, which moves every file this section writes

## Outcome

- `<data>\backups\spellbook-<UTC yyyyMMdd-HHmmss>.db` is written daily (the first start of each day) and before every migration; the newest 10 daily and every pre-migration backup from the last 90 days are kept.
- File > Restore from backup lists backups with date, size, and spell count, and restores one after saving the current database as `pre-restore-<time>.db`.
- An unhandled exception writes `<data>\crashes\spellbook-<time>.dmp` and a log line; the next start shows what happened and runs `PRAGMA quick_check`.
- Once a day at most, a newer release on GitHub shows an InfoBar with Download, Skip this version, and Later; Settings > Privacy turns the check off, and `docs/user/privacy.md` states exactly what is sent.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | Automatic and pre-migration backups | D01 T01 §3 |  [ ]   |
|   2   |   §2    | Restore from a backup | §1, D01 T01 §6 |  [ ]   |
|   3   |   §3    | Crash dumps and recovery on the next start | §2 |  [ ]   |
|   4   |   §4    | The update check and the Privacy page | D05 T01 §2 |  [ ]   |
|   5   |   §5    | The backups, recovery, and privacy guide | §2, §3, §4 |  [ ]   |

---

## 1. Automatic and Pre-Migration Backups

- [ ] `Database::backup_to(path)` in storage through the SQLite online backup API (pages copied in steps of 256, the destination opened, filled, and closed before the file is renamed from `.tmp`). Done when: a storage test backs up a database under concurrent reads and opens the copy with every row.
- [ ] `src/core/include/spellbook/core/backup_policy.hpp`: given the backup folder listing and now, decides whether today's backup is due and which files to delete (keep the newest 10 daily backups; keep pre-migration backups 90 days). Done when: core tests with a fake clock cover due, not due, rotation, and a folder holding foreign files (never deleted).
- [ ] The migrator takes a `pre-migration-v<from>-to-<to>` backup before applying any step to an existing database; a failed backup stops the migration with a message. Done when: a storage test upgrades a fixture and finds the backup, and a read-only backup folder stops the upgrade with the database unchanged.
- [ ] The app runs the daily check on start, off the UI thread, and logs "Backup written: <file> (<size>)" or the reason it failed. Done when: two starts on the same day write one backup.
- [ ] Commit: `"storage, core, app: automatic and pre-migration backups (D05 T03 §1)"`

**Test checkpoint:** Unit test plus driven run: the backup cases pass; `pwsh scripts/run.ps1 -Smoke` twice on one data folder leaves exactly one daily backup (listed in the evidence).

**Freeze check:** the migrator change is a frozen behaviour (`src/storage/src/migrator.cpp`): `storage: a failing step rolls back and leaves the last complete version` still passes, and a new test proves a migration never starts without its backup.

## 2. Restore from a Backup

**Job:** the user can roll the whole library back to an earlier day.
**Treatment:** File > Restore from backup opens a dialog listing backups (date, kind, size, spell count read from a read-only open), newest first; Restore confirms naming the backup and the current spell count, saves the current database as `pre-restore-<time>.db`, swaps the files with the database closed, reopens, and refreshes every pane. Cheaper substitute that fails the checkpoint: telling the user which file to copy.
**Chrome:** consume `backup_to`, the backup listing, the confirmation pattern of `D01 T01 §6`, and the vocabulary table. Do not restore while an autosave is pending: flush first.

- [ ] The dialog and the swap (`ReplaceFileW` with the backup copy, never the backup itself), AutomationIds `restore-backup`, `backup-list`, `backup-restore`. Done when: a restored library reads back as the backup's contents and the pre-restore file exists.
- [ ] `tests/ui/scenarios/restore-backup.ps1`: seed 5 spells, back up, add 3, restore, assert 5 via `dbread.py` and the pre-restore file holds 8. Done when: it exits 0.
- [ ] Commit: `"app: restore from a backup (D05 T03 §2)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario restore-backup` exits 0.

**Freeze check:** the swap never touches the backup file; the scenario hashes the chosen backup before and after and asserts they match.

## 3. Crash Dumps and Recovery on the Next Start

**Job:** the user is told the truth after a crash and loses nothing.
**Treatment:** an unhandled exception writes a minidump and a log line, then the process ends; the next start sees the unclean-exit marker and shows an InfoBar: "Spellbook closed unexpectedly at 14:32. Your spells were saved up to the last autosave. A crash report was saved on this PC; nothing was sent." with Open folder; it also runs `PRAGMA quick_check` and, on failure, offers Restore from backup. Cheaper substitute that fails the checkpoint: a log line only.
**Chrome:** consume the data folder, the log, and §2's restore dialog. Do not upload anything.

- [ ] `src/app/crash.cpp`: `SetUnhandledExceptionFilter` plus WinUI `UnhandledException` write `<data>\crashes\spellbook-<time>.dmp` (`MiniDumpWithIndirectlyReferencedMemory`), keep the newest 5, and log the exception code. A `session.lock` file is created on start and removed on a clean exit. Done when: a crash leaves a dump and the lock.
- [ ] A hidden test hook `--crash-test` (ignored unless `SPELLBOOK_TEST_HOOKS=1`) raises an access violation after the window opens. Done when: documented in `docs/dev/` and refused without the variable.
- [ ] `tests/ui/scenarios/crash-recovery.ps1`: edit a spell, wait for autosave, crash with the hook, relaunch, assert the dump exists, the InfoBar is shown, the edit is intact, and the log has the quick-check result. Done when: it exits 0.
- [ ] Commit: `"app: crash dumps and recovery on the next start (D05 T03 §3)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario crash-recovery` exits 0; the capture of the InfoBar under `docs/captures/crash-recovery/`.

## 4. The Update Check and the Privacy Page

**Job:** the user learns about new versions and controls what Spellbook sends.
**Treatment:** at most once every 24 hours, 10 s after start, off the UI thread, Spellbook requests the latest release; when it is newer than the running version (SemVer, prereleases ignored unless the user runs a prerelease) an InfoBar offers Download (opens the release page), Skip this version, and Later. Settings gains a Privacy page: "Check for updates" (on), with a one-paragraph plain statement of what is sent and a link to `docs/user/privacy.md`; Help > Check for updates runs it now. A portable copy checks too. Cheaper substitute that fails the checkpoint: a check with no way to turn it off.
**Chrome:** consume the settings store of `D05 T01 §2`, the version in `spellbook::core::version`, the vocabulary table, and the theme resources. Do not download or run anything.

- [ ] `src/core/include/spellbook/core/update_check.hpp`: `parse_latest_release(std::string_view json) -> std::optional<Release>` (skips drafts), `is_newer(SemVer current, SemVer candidate, bool allow_prerelease)`, and `UpdatePolicy` (due after 24 h, honours skipped versions). Done when: tests cover the GitHub fixture JSON in `tests/fixtures/update/`, prereleases, a malformed body, and the 24-hour boundary.
- [ ] `src/app/update_client.cpp`: WinHTTP GET with `User-Agent: Spellbook/<version>` and `Accept: application/vnd.github+json`, 10 s timeout, no cookies, no other headers; the base URL comes from the setting `update.base_url` (default `https://api.github.com`) so tests can point it at a local server. Done when: a request to a stopped server logs a quiet failure and never shows an error to the user.
- [ ] The Privacy page in the Settings dialog (AutomationIds `settings-privacy`, `privacy-update-check`) and Help > Check for updates. Done when: turning the switch off stops the request (the mock server records no hit).
- [ ] `tests/ui/mock_github.py` (stdlib `http.server`, serves a fixture release) and `tests/ui/scenarios/update-check.ps1`: newer release shows the InfoBar; Skip hides it across a restart; switch off means no request. Done when: it exits 0.
- [ ] Commit: `"core, app: the update check and the Privacy page (D05 T03 §4)"`

**Test checkpoint:** Unit test plus driven run with evidence: the update tests pass and `pwsh scripts/drive.ps1 -Scenario update-check` exits 0 with the mock server's request log quoted (one request, the two headers only).

## 5. The Backups, Recovery, and Privacy Guide

- [ ] `docs/user/backups-and-recovery.md` (where backups live, rotation, restore, crash reports) and `docs/user/privacy.md` (the update request exactly, what is never sent, the AI section placeholder that `D06 T01` fills). Done when: linked from `docs/user/README.md` and the README.
- [ ] `CHANGELOG.md` Unreleased lists backups, restore, crash recovery, and the update check. Done when: present.
- [ ] Commit: `"docs: backups, recovery, and privacy (D05 T03 §5)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0
- [ ] `pwsh scripts/drive.ps1 -Scenario restore-backup`, `crash-recovery`, and `update-check` exit 0
- [ ] `python scripts/todo-graph.py validate` clean
