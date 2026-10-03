---
schema_version: 1
id: ship-first-release
domain: 05-ship
status: draft
title: "TODO-02 -- The First Release: Icon, Installer, Release Pipeline, and v0.1.0"
depends_on: []
---

# TODO-02 -- The First Release: Icon, Installer, Release Pipeline, and v0.1.0

> **Goal:** Spellbook v0.1.0 is published: a designed icon and README banner replace the placeholders, an Inno Setup 7 installer and the portable ZIP are built by `scripts/package.ps1`, the `release` workflow publishes both with checksums from a pushed tag, and the release checklist in `standards/release.md` holds on a clean Windows 11 machine.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** `assets/spellbook.ico` is a placeholder drawn by `scripts/generate-icon.py`; `assets/banner.svg` is a placeholder. `scripts/package.ps1` builds the portable ZIP and `SHA256SUMS`; `-Installer` exits 1 naming §2. `.github/workflows/release.yml` publishes the ZIP on a `v*` tag and has never run. `scripts/release.ps1` moves the changelog and tags.

## Inputs

- [`standards/release.md`](../../standards/release.md) -- the release checklist this file must satisfy
- [`docs/adr/0001-tech-stack.md`](../../docs/adr/0001-tech-stack.md) -- why Inno Setup 7
- Isotone's `installer/common.iss` -- the per-user default, all-users option, and Windows 10 notice to copy

## Outcome

- A designed icon at every size and a README banner in light and dark.
- `Spellbook-<version>-win-x64-Setup.exe`: per-user by default with an all-users option, Start menu entry, optional start with Windows (for the hotkey), clean uninstall that keeps the user's data unless asked.
- v0.1.0 tagged, released, and smoke-tested from the downloaded assets.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | The designed icon and the README banner | D00 T01 §5 |  [ ]   |
|   2   |   §2    | The Inno Setup 7 installer | §1, D99 T01 §4 |  [ ]   |
|   3   |   §3    | A draft run of the release pipeline | §2, D00 T01 §10 |  [ ]   |
|   4   |   §4    | The complete user guide | T01 §5, D04 T01 §7 |  [ ]   |
|   5   |   §5    | Release v0.1.0 | §3, §4 |  [ ]   |

---

## 1. The Designed Icon and the README Banner

- [ ] Commission or draw the icon (an open book with glowing text), as SVG source in `assets/brand/` plus a 16 to 256 px `.ico` generated from it. Done when: the 16 and 24 px sizes are hand-tuned and legible on light and dark taskbars.
- [ ] Replace `assets/banner.svg` and add `assets/banner-dark.svg`; the README uses a `<picture>` element for both. Done when: GitHub renders the right one per theme.
- [ ] Commit: `"brand: the Spellbook icon and README banner"`

**Test checkpoint:** Driven run with evidence: captures of the taskbar and Explorer at 100 and 200 percent in light and dark.

## 2. The Inno Setup 7 Installer

- [ ] `installer/spellbook.iss`: `AppId` fixed (a GUID recorded here when first written), `PrivilegesRequiredOverridesAllowed=dialog`, `ArchitecturesInstallIn64BitMode=x64compatible`, version from `/DAppVersion`, Start menu entry, optional "Start with Windows" task, uninstall that leaves `%LOCALAPPDATA%\Spellbook` unless the user ticks "Remove my spells". Done when: ISCC compiles it.
- [ ] Pin Inno Setup 7 in `toolchain.json` (installer URL and SHA-256) and teach `scripts/setup.ps1` a leg for it. Done when: `setup.ps1 -Verify` reports it.
- [ ] `scripts/package.ps1 -Installer` builds `Spellbook-<version>-win-x64-Setup.exe` and adds it to `SHA256SUMS`; `release.yml` attaches it. Done when: a local run produces the file.
- [ ] Commit: `"installer: the Inno Setup 7 installer"`

**Test checkpoint:** Driven run with evidence: install per-user, launch, uninstall, on a clean Windows 11 VM; the data folder survives the uninstall by default and is removed when asked.

## 3. A Draft Run of the Release Pipeline

- [ ] Add a `workflow_dispatch` draft mode to `release.yml` (tag input, `--draft`), as Isotone's release workflow has. Done when: actionlint is clean.
- [ ] Dispatch a draft for `v0.1.0-rc.1`, download the assets, check the hashes, delete the draft. Done when: the run is green and the hashes match.
- [ ] Commit: `"ci: a draft mode for the release workflow"`

**Test checkpoint:** Driven run with evidence: the draft run id, and `Get-FileHash` of the downloaded assets matching `SHA256SUMS`.

## 4. The Complete User Guide

- [ ] `docs/user/` covers installing, the library, import, find and cast, runes, revisions, settings, export and restore, and troubleshooting (where the log is). Done when: every surface shipped by M1 to M5 has a page.
- [ ] Commit: `"docs: the complete user guide for v0.1.0"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`.

## 5. Release v0.1.0

- [ ] Run the checklist in `standards/release.md`, quoting each line's evidence here. Done when: every line holds.
- [ ] `pwsh scripts/release.ps1 -Version 0.1.0`, then push `main` and the tag. Done when: the `release` workflow is green and the release page lists the installer, the ZIP, and `SHA256SUMS`.
- [ ] Commit: `"release: v0.1.0"` (made by `scripts/release.ps1`)

**Test checkpoint:** Driven run with evidence: on a clean Windows 11 machine, the downloaded installer installs, Spellbook imports a sample `.txt` folder, casts a prompt, and uninstalls.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0 at the tagged commit
- [ ] `python scripts/todo-graph.py validate` clean
