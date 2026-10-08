# Changelog

All notable changes to Spellbook are recorded here.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and Spellbook follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Release headings name the tag they came from, for example `## [v0.1.0] - 2026-11-01`; `scripts/release.ps1` writes them and the release workflow lifts that section as the release notes.

## [Unreleased]

### Added

- A primary-writer selector for switching between Codex and Claude while preserving their separate workflows and paused run state.
- An independent Codex writer workflow with its own skills, hooks, supervised plan runner, pause/recovery controls, and fresh-context review.
- The Spellbook icon: a fanned deck of teal prompt cards with an AI sparkle, with a simpler drawing at small sizes, and new README banners.
- The Spellbook window: a native Win32 window titled Spellbook with its icon, aware of display scaling on every monitor, with a dark title bar when Windows apps are set to dark.
- The local database: `%LOCALAPPDATA%\Spellbook\spellbook.db` is created on first launch and kept at the current schema, with a full-text search index ready for M3.
- Logging to `%LOCALAPPDATA%\Spellbook\logs\spellbook.log`.
- Build from source with four commands (`setup`, `build`, `test`, `run`); the toolchain is pinned and provisioned into the repository.
