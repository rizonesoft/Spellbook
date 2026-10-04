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
> **Current state (verified 2026-10-04):** The designed icon (Prompt Deck, teal) replaced the placeholder in `assets/spellbook.ico` and `assets/banner-on-light.svg` / `banner-on-dark.svg` on 2026-10-04; §1 owes its captures and the GitHub checks. `scripts/package.ps1` builds the portable ZIP and `SHA256SUMS`; `-Installer` exits 1 naming §2. `.github/workflows/release.yml` publishes the ZIP on a `v*` tag and has never run. `scripts/release.ps1` moves the changelog and tags.

## Inputs

- [`standards/release.md`](../../standards/release.md) -- the release checklist this file must satisfy
- [`docs/adr/0001-tech-stack.md`](../../docs/adr/0001-tech-stack.md) -- why Inno Setup 7
- Isotone's `installer/common.iss` -- the per-user default, all-users option, and Windows 10 notice to copy
- -> XREF: D00 T02 §6 -- the WinUI 3 stack: the installer ships the self-contained app folder, not one exe

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

The operator chose the icon on 2026-10-04 after three rounds of concepts: "Prompt Deck", a fanned stack of three prompt cards whose front card carries a white AI sparkle (with a small companion sparkle) and two white lines of prompt text, in the Teal palette picked from six (front card `#2DD4BF` to `#0B6B63`, middle card `#8FE3D6`, back card `#CFF5EE`). It replaced the earlier open-book concepts. The full brand kit (guide PDF, every SVG and PNG version, web and GitHub files) lives outside the repository in the Rizonesoft branding drive, `Branding\Spellbook`, and is rebuilt by its `Source Files\build-kit.py`; the repository keeps the masters in `assets/brand/`. The app ships unpackaged (ADR 0002), so the `.ico` is the only icon format the app needs; there is no MSIX logo set.

- [x] Masters in `assets/brand/`: `spellbook-icon.svg` (40 px and up), `spellbook-icon-small.svg` (32 px and under: no companion sparkle, heavier text lines), `spellbook-icon-black.svg` and `spellbook-icon-white.svg` (one colour, the cards separated by cut gaps), `spellbook-logo.svg` and `spellbook-logo-reversed.svg` (icon plus the name outlined from Exo Bold, the Rizonesoft logo face), and `social-preview.png` (1280 by 640 px). Done when: the operator confirms the drawing and the palette. Cheaper substitute: one drawing scaled to every size.
- [x] `scripts/generate-icon.py` renders `assets/spellbook.ico` (16, 20, 24, 32, 40, 48, 64, 256 px) and `assets/spellbook-256.png` from the masters, the small drawing for 16 to 32 px, and fails if any frame is a resample. Done when: the script reports every frame and the `.ico` lists all eight sizes. Cheaper substitute: the 256 px render downscaled to 16 px.
- [ ] `assets/banner-on-light.svg` and `assets/banner-on-dark.svg`: the logo with the tagline below the name, all text outlined; the README's existing `<picture>` serves both. Done when: GitHub renders the right one per theme (after the push).
- [ ] Set `assets/brand/social-preview.png` as the repository's social preview (Settings, General, Social preview). Done when: a shared link to the repository shows it.
- [ ] Commit: `"brand: the Prompt Deck icon, logo, and README banners (D05 T02 §1)"`

**Test checkpoint:** Driven run with evidence: captures of the taskbar and Explorer at 100 and 200 percent in light and dark, under `docs/captures/`, showing the small drawing at 16 to 32 px and the full drawing above.

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
