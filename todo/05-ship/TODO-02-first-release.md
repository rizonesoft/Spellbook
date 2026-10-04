---
schema_version: 1
id: ship-first-release
domain: 05-ship
status: draft
title: "TODO-02 -- The First Release: Icon, Installer, Portable Mode, Channels, and v0.1.0"
depends_on: []
---

# TODO-02 -- The First Release: Icon, Installer, Portable Mode, Channels, and v0.1.0

> **Goal:** Spellbook v0.1.0 is published as a premium Windows app: the designed icon everywhere; one Inno Setup 7 installer whose first page offers Install for me, Install for all users, or Portable; a portable ZIP that is portable by design; install, upgrade, and uninstall proven unattended on the development PC and in CI; the `release` workflow publishing the installer, the ZIP, checksums, notices, and channel manifests from a tag the operator approved; and Spellbook available through winget, Scoop, and Chocolatey, with the Microsoft Store following once code signing exists.

> [!IMPORTANT]
> **Current state (verified 2026-10-04):** The designed icon (Prompt Deck, teal) replaced the placeholder in `assets/spellbook.ico` and `assets/banner-on-light.svg` / `banner-on-dark.svg` on 2026-10-04; §1 owes its captures and the GitHub checks. `scripts/package.ps1` builds the portable ZIP and `SHA256SUMS`; `-Installer` exits 1 naming §2. `.github/workflows/release.yml` publishes the ZIP on a `v*` tag and has never run. `scripts/release.ps1` moves the changelog and tags. Inno Setup 7.1.0 (2026-08-12, the latest) is installed machine-wide on the development PC at `C:\Program Files\Inno Setup 7` but is not yet pinned in `toolchain.json`. **Corrected 2026-10-04:** operator decisions (ADR 0003) replaced the single-mode installer: one installer with three modes plus the portable ZIP; a `Spellbook.portable` marker puts all data in `Data\` beside the exe; unsigned for v0.1.0; install tests run on this PC and in CI rather than a clean VM, with a by-hand clean-machine check as an operator step (`D99 T01 §6`); "Start with Windows" is opt in; channels winget, Scoop, and Chocolatey, the Store after signing; the tag waits for the operator's approval (`D99 T01 §7`). Inno Setup has no built-in portable mode (checked against the 7.x revision history), so the mode page is custom Pascal Script.

## Inputs

- [`standards/release.md`](../../standards/release.md) -- the release checklist this file must satisfy
- [`docs/adr/0003-v0.1.0-scope-and-distribution.md`](../../docs/adr/0003-v0.1.0-scope-and-distribution.md) -- every distribution decision
- Isotone's `installer/common.iss` (`R:\GitHub\Isotone\installer\common.iss`) -- the operator's conventions: `PrivilegesRequired=lowest`, `WizardStyle=modern dynamic`, `CloseApplications=yes`, the Windows 10 notice
- Inno Setup 7 documentation (`ISetup.chm` in the install folder, and jrsoftware.org): `[Setup]` directives, `CreateInputOptionPage`, `Uninstallable` and `CreateUninstallRegKey` as boolean expressions, `HKA`, `AppUserModelID` in `[Icons]`, `ChangesAssociations`, `/CURRENTUSER`, `/ALLUSERS`, wizard image sizes and dark variants
- winget-pkgs manifest schema 1.x, Scoop app manifest reference, Chocolatey package creation docs
- -> XREF: D00 T02 §6 -- the WinUI 3 stack: the installer ships the self-contained app folder, not one exe
- -> XREF: D03 T02 §3 -- the AppUserModelID the shortcuts must carry
- -> XREF: D02 T02 §2 -- the `.spell` type the installer registers
- -> XREF: D05 T03 §1 -- the data folder the portable marker moves
- -> XREF: D05 T04 §3 -- `THIRD-PARTY-NOTICES.txt`, shipped by the installer and the ZIP
- -> XREF: D99 T01 §6 -- the by-hand clean-machine check before the release
- -> XREF: D99 T01 §7 -- the operator's approval that unlocks the tag
- -> XREF: D99 T01 §8 -- the channel accounts and secrets
- -> XREF: D99 T01 §9 -- code signing and the Partner Center account

## Outcome

- A designed icon at every size and a README banner in light and dark.
- `Spellbook-<version>-win-x64-Setup.exe`: per-user by default, all users on request (elevating), or portable; Start menu entry with the AppUserModelID; `.spell` registered; "Start with Windows" offered unticked; upgrades in place; uninstall keeps the user's data unless asked; silent switches for every mode.
- `Spellbook-<version>-win-x64-portable.zip` runs portable straight from the extracted folder.
- `scripts/test-installer.ps1` proves install, upgrade, launch, and uninstall for each mode unattended; CI runs it including all-users.
- v0.1.0 is tagged after the operator's approval, released with installer, ZIP, `SHA256SUMS`, notices, and channel manifests, then published to winget, Scoop, and Chocolatey.

## Implementation Order

| Order | Section | Deliverable | Depends On | Status |
| :---: | :-----: | ----------- | ---------- | :----: |
|   1   |   §1    | The designed icon and the README banner | D00 T01 §5, D00 T03 §4 |  [ ]   |
|   2   |   §6    | Portable mode in the app | D00 T02 §3, D05 T01 §2 |  [ ]   |
|   3   |   §7    | Installer artwork from the brand masters | §1 |  [ ]   |
|   4   |   §2    | The Inno Setup 7 installer with three modes | §6, §7, D99 T01 §4, D02 T02 §2, D03 T02 §3, D05 T04 §3 |  [ ]   |
|   5   |   §8    | Install tests on this PC and in CI | §2 |  [ ]   |
|   6   |   §9    | Channel manifests: winget, Scoop, Chocolatey | §8 |  [ ]   |
|   7   |   §3    | A draft run of the release pipeline | §9, D00 T01 §10 |  [ ]   |
|   8   |   §4    | The complete user guide | T01 §5, D04 T02 §5, D06 T01 §10, T03 §5, T04 §4 |  [ ]   |
|   9   |   §5    | Release v0.1.0 | §3, §4, D99 T01 §6, D99 T01 §7 |  [ ]   |
|  10   |   §10   | Publish to winget, Scoop, and Chocolatey | §5, D99 T01 §8 |  [ ]   |
|  11   |   §11   | Code signing and the Microsoft Store | §10, D99 T01 §9 |  [ ]   |

---

## 1. The Designed Icon and the README Banner

The operator chose the icon on 2026-10-04 after three rounds of concepts: "Prompt Deck", a fanned stack of three prompt cards whose front card carries a white AI sparkle (with a small companion sparkle) and two white lines of prompt text, in the Teal palette picked from six (front card `#2DD4BF` to `#0B6B63`, middle card `#8FE3D6`, back card `#CFF5EE`). It replaced the earlier open-book concepts. The full brand kit (guide PDF, every SVG and PNG version, web and GitHub files) lives outside the repository in the Rizonesoft branding drive, `Branding\Spellbook`, and is rebuilt by its `Source Files\build-kit.py`; the repository keeps the masters in `assets/brand/`. The app ships unpackaged (ADR 0002), so the `.ico` is the only icon format the app needs; there is no MSIX logo set. **Corrected 2026-10-04:** setting the GitHub social preview is a repository setting only the operator can change, so it moved to `D99 T01 §2`; checks at other display scales moved to `D99 T01 §10`.

- [x] Masters in `assets/brand/`: `spellbook-icon.svg` (40 px and up), `spellbook-icon-small.svg` (32 px and under: no companion sparkle, heavier text lines), `spellbook-icon-black.svg` and `spellbook-icon-white.svg` (one colour, the cards separated by cut gaps), `spellbook-logo.svg` and `spellbook-logo-reversed.svg` (icon plus the name outlined from Exo Bold, the Rizonesoft logo face), and `social-preview.png` (1280 by 640 px). Done when: the operator confirms the drawing and the palette. Cheaper substitute: one drawing scaled to every size.
- [x] `scripts/generate-icon.py` renders `assets/spellbook.ico` (16, 20, 24, 32, 40, 48, 64, 256 px) and `assets/spellbook-256.png` from the masters, the small drawing for 16 to 32 px, and fails if any frame is a resample. Done when: the script reports every frame and the `.ico` lists all eight sizes. Cheaper substitute: the 256 px render downscaled to 16 px.
- [ ] `assets/banner-on-light.svg` and `assets/banner-on-dark.svg`: the logo with the tagline below the name, all text outlined; the README's existing `<picture>` serves both. Done when: after the push, `curl -sI` on both files' `raw.githubusercontent.com` URLs returns 200 and the README's `<picture>` names both.
- [ ] Commit: `"brand: the Prompt Deck icon, logo, and README banners (D05 T02 §1)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/drive.ps1 -Scenario icon` launches Spellbook, captures the title bar and the taskbar button at the machine's native scale, and extracts the exe's icon frames with `System.Drawing.Icon` to assert the 16 to 32 px frames are the small drawing (pixel-equal to `generate-icon.py`'s renders) and 40 px and up the full one.

## 2. The Inno Setup 7 Installer with Three Modes

**Job:** a user installs Spellbook the way they want: for themselves, for everyone, or portable.
**Treatment:** a branded Inno Setup 7 wizard that follows the system's light or dark mode. Its first page, "How do you want to install Spellbook?", offers Install for me (recommended, no admin), Install for all users (needs admin), and Portable (any folder or USB stick: no registry, no uninstaller, no shortcuts). Then the folder page, the tasks (desktop shortcut, Start with Windows: both unticked; hidden for portable), and Install. Cheaper substitute that fails the checkpoint: two installers, or Inno's own privileges dialog with portable missing.
**Chrome:** consume the brand artwork of §7, `assets/spellbook.ico`, `THIRD-PARTY-NOTICES.txt`, the AppUserModelID `Rizonesoft.Spellbook`, and the app's `--background` start. Do not hand-write a second branding.

- [ ] `installer/spellbook.iss`: `AppId` fixed (a GUID recorded in this section when first written), `AppName=Spellbook`, `AppPublisher=Rizonesoft`, version from `/DAppVersion`, `ArchitecturesAllowed=x64compatible`, `ArchitecturesInstallIn64BitMode=x64compatible`, `MinVersion=10.0.17763`, `PrivilegesRequired=lowest`, `PrivilegesRequiredOverridesAllowed=commandline`, the wizard style that follows the system theme (`modern dynamic` as Isotone, or the 7.1 `windows11` style if it reads better; record the choice here), `Compression=lzma2/max`, `SolidCompression=yes`, `CloseApplications=yes`, `AppMutex=Rizonesoft.Spellbook.Running`, `SetupIconFile` and `UninstallDisplayIcon` from the icon, the self-contained app folder, `LICENSE`, and `THIRD-PARTY-NOTICES.txt`. Done when: `ISCC.exe` compiles it with no warning.
- [ ] The mode page (`CreateInputOptionPage`, first page): Install for all users, when not elevated, relaunches `{srcexe}` elevated with `/ALLUSERS` plus the original switches and ends this setup; `/CURRENTUSER`, `/ALLUSERS`, and `/PORTABLE` preselect a mode and skip the page. Portable sets `Uninstallable` and `CreateUninstallRegKey` false through check functions, defaults the folder to `{%USERPROFILE}\Spellbook Portable`, writes `Spellbook.portable` beside the exe, and skips every `[Icons]`, `[Registry]`, and `[Tasks]` entry. Done when: each mode installs from the wizard and silently.
- [ ] Non-portable installs: a Start menu shortcut with `AppUserModelID: "Rizonesoft.Spellbook"`; the `.spell` type under `HKA\Software\Classes` (ProgID `Rizonesoft.Spellbook.spell`, the icon, `"{app}\Spellbook.exe" "%1"`) with `ChangesAssociations=yes`; the optional Start with Windows task writing `HKA\Software\Microsoft\Windows\CurrentVersion\Run` with `"{app}\Spellbook.exe" --background`. Done when: the install test (§8) reads each back.
- [ ] Uninstall: a custom page with "Also remove my spells from this PC" (unticked) that deletes the current user's `%LOCALAPPDATA%\Spellbook` when ticked (and says other users' data stays, for all-users installs); `/REMOVEDATA` does the same silently. Done when: both paths are covered by §8.
- [ ] The app creates the mutex `Rizonesoft.Spellbook.Running` at start so setup can close it. Done when: an upgrade with Spellbook running closes it and restarts nothing unasked.
- [ ] Pin Inno Setup 7.1.0 in `toolchain.json` (installer URL and SHA-256) and teach `scripts/setup.ps1` a leg that installs it portably into `.tools/innosetup/` (`/VERYSILENT /PORTABLE=1 /DIR=...`); the machine-wide copy is never used. Done when: `setup.ps1 -Verify` reports `innosetup 7.1.0`.
- [ ] `scripts/package.ps1 -Installer` builds `Spellbook-<version>-win-x64-Setup.exe` and adds it to `SHA256SUMS`. Done when: a local run produces the file.
- [ ] Commit: `"installer: the Inno Setup 7 installer with three modes (D05 T02 §2)"`

**Test checkpoint:** Builds clean plus driven run with evidence: `pwsh scripts/package.ps1 -Installer` exits 0; `Spellbook-<version>-win-x64-Setup.exe /VERYSILENT /SUPPRESSMSGBOXES /PORTABLE /DIR=build\install-test\portable` creates `Spellbook.portable` and no uninstall key, and the installed `Spellbook.exe --smoke` creates `Data\spellbook.db`; the same installer with `/CURRENTUSER /DIR=build\install-test\user` creates the `HKCU` uninstall key and the Start menu shortcut, and its silent uninstall removes both and keeps `%LOCALAPPDATA%\Spellbook` (every command and result quoted). The mode page is captured in light and dark at the native scale under `docs/captures/installer/`, driven through `tests/ui/SpellbookUia.psm1`.

## 3. A Draft Run of the Release Pipeline

- [ ] `release.yml`: builds Release, runs `check-all`, packages the installer and the ZIP, generates the channel manifests (§9), and attaches the installer, the ZIP, `SHA256SUMS`, `THIRD-PARTY-NOTICES.txt`, and the manifests; a `workflow_dispatch` draft mode (tag input, `--draft`), as Isotone's release workflow has. Done when: actionlint is clean.
- [ ] Dispatch a draft for `v0.1.0-rc.1`, download the assets, check the hashes, run `scripts/test-installer.ps1 -Installer <downloaded setup> -Mode User,Portable`, delete the draft. Done when: the run is green, the hashes match, and the test passes.
- [ ] Commit: `"ci: the release pipeline with installer, ZIP, notices, and manifests (D05 T02 §3)"`

**Test checkpoint:** Driven run with evidence: the draft run id, `Get-FileHash` of the downloaded assets matching `SHA256SUMS`, and the installer test's summary.

## 4. The Complete User Guide

- [ ] `docs/user/` covers getting started, installing (each mode, silent switches, portable), the library, import, sharing, find and cast, capture, runes, revisions, AI, settings and privacy, backups and recovery, export and restore, and troubleshooting (where the log and crash reports are). Done when: every surface shipped by M1 to M7 has a page and the README's Contents, Features, and Roadmap match.
- [ ] Commit: `"docs: the complete user guide for v0.1.0 (D05 T02 §4)"`

**Test checkpoint:** Static evidence: `python scripts/check-docs.py` prints `0 findings`; a script lists every `tests/ui/scenarios/*.ps1` and asserts each surface it drives is named in `docs/user/`.

## 5. Release v0.1.0

The tag is the one step an unattended run never takes on its own: it waits for `D99 T01 §7`, the operator's written approval after the by-hand clean-machine check (`D99 T01 §6`).

- [ ] Run the checklist in `standards/release.md`, quoting each line's evidence here. Done when: every line holds.
- [ ] `pwsh scripts/release.ps1 -Version 0.1.0`, then push `main` and the tag. Done when: the `release` workflow is green and the release page lists the installer, the ZIP, `SHA256SUMS`, the notices, and the manifests.
- [ ] Commit: `"release: v0.1.0"` (made by `scripts/release.ps1`)

**Test checkpoint:** Driven run with evidence: the published installer and ZIP, downloaded with `gh release download v0.1.0`, pass `scripts/test-installer.ps1 -Installer <file> -Mode User,Portable` on this PC, and `pwsh scripts/drive.ps1 -Scenario first-run` passes against the installed copy.

## 6. Portable Mode in the App

A portable copy must never write outside its folder, so the data-folder choice is one tested rule in core, and every writer (database, settings, logs, backups, crash dumps, AI sessions) goes through it.

- [ ] `src/core/include/spellbook/core/data_dir.hpp`: `resolve_data_dir(cli_override, exe_dir, marker_exists, local_app_data) -> DataDir{path, portable}` with precedence `--data-dir`, then `Spellbook.portable` beside the exe (`<exe dir>\Data`), then `%LOCALAPPDATA%\Spellbook`. Done when: core tests cover each and a read-only portable folder (reported, never silently redirected).
- [ ] `src/app/app_paths.cpp` uses it; a portable copy hides "Start with Windows" in Settings, never registers file types or the Run key, and About shows "Portable". Done when: a driven run of a portable copy leaves no new key under `HKCU\Software` (compared before and after).
- [ ] `scripts/package.ps1` puts `Spellbook.portable` in the ZIP, so the ZIP is portable by design. Done when: the ZIP extracted to a temp folder runs `--smoke` and creates `Data\spellbook.db` beside the exe.
- [ ] `tests/ui/scenarios/portable.ps1`. Done when: it exits 0.
- [ ] Commit: `"core, app: portable mode (D05 T02 §6)"`

**Test checkpoint:** Unit test plus driven run with evidence: `pwsh scripts/drive.ps1 -Scenario portable` exits 0 with the registry diff quoted (empty).

## 7. Installer Artwork from the Brand Masters

- [ ] `scripts/generate-installer-images.py` renders the wizard images (the large side image and the small header image) from `assets/brand/` at every size Inno Setup 7.1 lists for high DPI, in light and dark variants where 7.1 supports them, into `installer/images/` (PNG); the sizes and the directive names are quoted from the 7.1 documentation in the script's docstring. Done when: `ISCC.exe` accepts them with no scaling warning.
- [ ] Commit: `"installer: wizard artwork from the brand masters (D05 T02 §7)"`

**Test checkpoint:** Static evidence: the script's output list and a capture of the wizard's first page in light and dark under `docs/captures/installer/` (from §2's `-Capture` run once §2 exists; until then the images themselves are listed with their pixel sizes).

## 8. Install Tests on This PC and in CI

Operator decision 2026-10-04: install tests run on the development PC into temporary folders, and on the CI runner, which is elevated and so covers all-users installs.

- [ ] `scripts/test-installer.ps1 [-Installer <path>] [-Mode User,Portable,AllUsers] [-Capture]`: for each mode, a silent install to `build\install-test\<mode>` (`/VERYSILENT /SUPPRESSMSGBOXES /NORESTART` plus `/CURRENTUSER`, `/ALLUSERS`, or `/PORTABLE`), then asserts the files, the uninstall key (present for user and all users, absent for portable), the Start menu shortcut and its AppUserModelID (read through the shell property store), the `.spell` association, and the absence of any key for portable; runs `Spellbook.exe --smoke` (portable: asserts `Data\spellbook.db`); installs the same build again (upgrade: still one uninstall entry); uninstalls silently and asserts the files and keys are gone and the data folder kept; repeats with `/REMOVEDATA` and asserts the data folder is gone. `AllUsers` is skipped with a printed reason when not elevated. Done when: User and Portable pass on this PC and leave nothing behind (the script diffs `HKCU\Software`, the Start menu, and `build\install-test` before and after).
- [ ] CI job `installer` in `ci.yml` on `windows-latest` running all three modes. Done when: the job is green.
- [ ] Commit: `"ci: unattended install, upgrade, and uninstall tests (D05 T02 §8)"`

**Test checkpoint:** Driven run with evidence: `pwsh scripts/test-installer.ps1 -Mode User,Portable` exits 0 locally (its summary quoted) and the CI `installer` job is green on the pushed commit (run id quoted).

## 9. Channel Manifests: winget, Scoop, Chocolatey

- [ ] `scripts/channels.ps1 -Version <v> -Assets <folder>` writes, from the release assets and their hashes: winget manifests under `packaging/winget/` (singleton-free 1.x schema: version, defaultLocale with the tagline and license, installer with `InstallerType: inno`, `Scope: user` and `Scope: machine` entries with their switches, `ProductCode` `<AppId>_is1`, `FileExtensions: [spell]`, `UpgradeBehavior: install`); `packaging/scoop/spellbook.json` (the portable ZIP, `bin`, `shortcuts`, `persist: "Data"`, `checkver` and `autoupdate` from GitHub releases); and `packaging/chocolatey/` (`spellbook.nuspec`, `tools/chocolateyInstall.ps1` with `Install-ChocolateyPackage`, the URL, `checksum64`, `checksumType sha256`, and `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS`; `tools/chocolateyUninstall.ps1`). Done when: generated for a local build.
- [ ] Validation: `winget validate --manifest packaging/winget/...` where winget exists (Windows 11), a JSON check of the Scoop manifest's required keys, and `choco pack` in CI (preinstalled on GitHub's Windows runners). Done when: all three pass locally or in CI.
- [ ] Commit: `"packaging: winget, Scoop, and Chocolatey manifests (D05 T02 §9)"`

**Test checkpoint:** Static evidence plus CI: `winget validate` output quoted and the CI `choco pack` step green.

## 10. Publish to winget, Scoop, and Chocolatey

Publishing reaches outside the repository, so it runs only after the release and only with the accounts and secrets the operator set up in `D99 T01 §8`.

- [ ] A `channels` job in `release.yml`, after the release job and only for non-draft tags: opens the winget-pkgs pull request with `wingetcreate submit` using the `WINGET_TOKEN` secret, pushes the Scoop manifest to `rizonesoft/scoop-bucket` with the `SCOOP_BUCKET_TOKEN` secret, and pushes the Chocolatey package with the `CHOCOLATEY_API_KEY` secret. Done when: actionlint is clean and each step is skipped with a notice when its secret is missing.
- [ ] For v0.1.0, run the job (it runs on the tag) and record each channel's result here. Done when: the winget pull request URL, the bucket commit, and the Chocolatey package page (in moderation is fine) are quoted.
- [ ] Commit: `"ci: publish to winget, Scoop, and Chocolatey (D05 T02 §10)"`

**Test checkpoint:** Driven run with evidence: `gh pr list --repo microsoft/winget-pkgs --search "Rizonesoft.Spellbook 0.1.0"` lists the pull request; `gh api repos/rizonesoft/scoop-bucket/contents/bucket/spellbook.json` returns the manifest; the Chocolatey package URL answers 200.

## 11. Code Signing and the Microsoft Store

The Store requires the installer and every PE file in it to be Authenticode-signed with a certificate chaining to the Microsoft Trusted Root Program; it does not re-sign EXE installers. This section adds signing once the operator has it (`D99 T01 §9`) and prepares the Store listing.

- [ ] `scripts/package.ps1 -Sign`: signs every `.exe` and `.dll` in the app folder, then the installer (Inno `SignTool` directive), through the signing service or certificate the operator configured, with the credentials supplied from outside the repository (environment or repository secrets, never files); `release.yml` signs on tags when the secrets exist. Done when: `Get-AuthenticodeSignature` reports `Valid` on the installer and on `Spellbook.exe` from a signed local build.
- [ ] The Store listing package under `packaging/store/`: description, feature list, keywords, privacy statement link, screenshots from `docs/captures/` at the Store's required sizes, and the versioned HTTPS installer URL and silent switches the EXE submission needs. Done when: it covers every required field of the Partner Center EXE app submission.
- [ ] Commit: `"release: code signing and the Microsoft Store listing (D05 T02 §11)"`

**Test checkpoint:** Driven run with evidence: `Get-AuthenticodeSignature` output for a signed build; the listing checked field by field against the Partner Center EXE submission requirements (the list quoted). The submission itself is `D99 T01 §12`.

## Verification

- [ ] `pwsh scripts/check-all.ps1` exits 0 at the tagged commit
- [ ] `pwsh scripts/test-installer.ps1 -Mode User,Portable` exits 0 against the published installer
- [ ] `python scripts/todo-graph.py validate` clean
