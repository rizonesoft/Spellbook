# Changelog

All notable changes to Spellbook are recorded here.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and Spellbook follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Release headings name the tag they came from, for example `## [v0.1.0] - 2026-11-01`; `scripts/release.ps1` writes them and the release workflow lifts that section as the release notes.

## [Unreleased]

### Fixed

- Package the complete self-contained WinUI folder with third-party terms, verified checksums, and an extracted-app smoke test; gate MSBuild source coverage and cache pinned NuGet packages in CI.
- Preserve the previous portable package when checksum publication fails, retain recovery files if restoration fails, and reject source declarations that can bypass app compilation coverage.

- Provision missing WinUI C++ tools on disposable GitHub-hosted runners before setup; local and self-hosted installation remains operator-owned.

### Added

- VS 2026 v145 and WinUI C++ toolchain checks, pinned NuGet provisioning, and Windows App SDK/C++/WinRT package pins for the upcoming WinUI shell.

- Sequential independent Codex review using global model/effort settings, followed by a quick latest-Sonnet review at high effort, for either primary writer.
- A primary-writer selector for switching between Codex and Claude while preserving their separate workflows and paused run state.
- An independent Codex writer workflow with its own skills, hooks, supervised plan runner, pause/recovery controls, and fresh-context review.
- The Spellbook icon: a fanned deck of teal prompt cards with an AI sparkle, with a simpler drawing at small sizes, and new README banners.
- The Spellbook window: a WinUI 3 shell with Mica, a themed custom title bar, its existing icon, and an empty-grimoire welcome. The unpackaged application folder includes its Windows App SDK runtime and preserves the existing library, migration, and logging behavior.
- The local database: `%LOCALAPPDATA%\Spellbook\spellbook.db` is created on first launch and kept at the current schema, with a full-text search index ready for M3.
- Logging to `%LOCALAPPDATA%\Spellbook\logs\spellbook.log`.
- Build from source with four commands (`setup`, `build`, `test`, `run`); the toolchain is pinned and provisioned into the repository.
